// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import "../external/algebra/ISwapRouter.sol";

/**
 * @title AlgebraSwapLiquidator
 * @notice Exchanges seized token collateral for underlying tokens via a Algebra router for use as a step in a liquidation.
 * @author Veliko Minkov <veliko@midascapital.xyz> (https://github.com/vminkov)
 */
contract AlgebraSwapLiquidator is IRedemptionStrategy {
  /**
   * @notice Redeems custom collateral `token` for an underlying token.
   * @param inputToken The input wrapped token to be redeemed for an underlying token.
   * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
   * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
   * @return outputToken The underlying ERC20 token outputted.
   * @return outputAmount The quantity of underlying tokens outputted.
   */
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (address _outputToken, ISwapRouter swapRouter) = abi.decode(strategyData, (address, ISwapRouter));
    outputToken = IERC20Upgradeable(_outputToken);

    inputToken.approve(address(swapRouter), inputAmount);

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
      address(inputToken),
      _outputToken,
      address(this),
      block.timestamp,
      inputAmount,
      0, // amountOutMinimum
      0 // limitSqrtPrice
    );

    outputAmount = swapRouter.exactInputSingle(params);
  }

  function name() public pure returns (string memory) {
    return "AlgebraSwapLiquidator";
  }
}

contract ReverseAlgebraSwapLiquidator is IRedemptionStrategy {
  IERC20Upgradeable public lpHayBusdToken = IERC20Upgradeable(0x93B32a8dfE10e9196403dd111974E325219aec24);

  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (address _outputToken, ISwapRouter swapRouter) = abi.decode(strategyData, (address, ISwapRouter));

    /*
    function beefIn (address beefyVault, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external {
        require(tokenInAmount >= minimumAmount, 'Beefy: Insignificant input amount');
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, 'Beefy: Input token is not approved');

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

        _swapAndStake(beefyVault, tokenAmountOutMin, tokenIn);
    }

    function _getVaultPair (address beefyVault) private pure returns (IBeefyVaultV6 vault, IUniswapV2Pair pair) {
        vault = IBeefyVaultV6(beefyVault);
        pair = IUniswapV2Pair(vault.want());
    }

    function _swapAndStake(address beefyVault, uint256 tokenAmountOutMin, address tokenIn) private {
        (IBeefyVaultV6 vault, IUniswapV2Pair pair) = _getVaultPair(beefyVault);

        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, 'Beefy: Liquidity pair reserves too low');

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, 'Beefy: Input token not present in liqudity pair');

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = isInputA ? pair.token1() : pair.token0();

        uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
        uint256 swapAmountIn;
        if (isInputA) {
            swapAmountIn = _getSwapAmount(pair, fullInvestment, reserveA, reserveB, path[0], path[1]);
        } else {
            swapAmountIn = _getSwapAmount(pair, fullInvestment, reserveB, reserveA, path[0], path[1]);
        }

        _approveTokenIfNeeded(path[0], address(router));
        uint256[] memory swapedAmounts = router
            .swapExactTokensForTokensSimple(swapAmountIn, tokenAmountOutMin, path[0], path[1], pair.stable(), address(this), block.timestamp);

        _approveTokenIfNeeded(path[1], address(router));
        (,, uint256 amountLiquidity) = router
            .addLiquidity(path[0], path[1], pair.stable(), fullInvestment.sub(swapedAmounts[0]), swapedAmounts[1], 1, 1, address(this), block.timestamp);

        _approveTokenIfNeeded(address(pair), address(vault));
        vault.deposit(amountLiquidity);

        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));
        _returnAssets(path);
    }

    function _returnAssets(address[] memory tokens) private {
        uint256 balance;
        for (uint256 i; i < tokens.length; i++) {
            balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                if (tokens[i] == WETH) {
                    IWETH(WETH).withdraw(balance);
                    (bool success,) = msg.sender.call{value: balance}(new bytes(0));
                    require(success, 'Beefy: ETH transfer failed');
                } else {
                    IERC20(tokens[i]).safeTransfer(msg.sender, balance);
                }
            }
        }
    }

    function _getSwapAmount(IUniswapV2Pair pair, uint256 investmentA, uint256 reserveA, uint256 reserveB, address tokenA, address tokenB) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;

        if (pair.stable()) {
            swapAmount = _getStableSwap(pair, investmentA, halfInvestment, tokenA, tokenB);
        } else {
            uint256 nominator = pair.getAmountOut(halfInvestment, tokenA);
            uint256 denominator = halfInvestment * reserveB.sub(nominator) / reserveA.add(halfInvestment);
            swapAmount = investmentA.sub(Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
        }
    }

    function _getStableSwap(IUniswapV2Pair pair, uint256 investmentA, uint256 halfInvestment, address tokenA, address tokenB) private view returns (uint256 swapAmount) {
        uint out = pair.getAmountOut(halfInvestment, tokenA);
        (uint amountA, uint amountB,) = router.quoteAddLiquidity(tokenA, tokenB, pair.stable(), halfInvestment, out);

        amountA = amountA * 1e18 / 10**IERC20Extended(tokenA).decimals();
        amountB = amountB * 1e18 / 10**IERC20Extended(tokenB).decimals();
        out = out * 1e18 / 10**IERC20Extended(tokenB).decimals();
        halfInvestment = halfInvestment * 1e18 / 10**IERC20Extended(tokenA).decimals();

        uint ratio = out * 1e18 / halfInvestment * amountA / amountB;

        return investmentA * 1e18 / (ratio + 1e18);
    }

    function estimateSwap(address beefyVault, address tokenIn, uint256 fullInvestmentIn) public view returns(uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut) {
        checkWETH();
        (, IUniswapV2Pair pair) = _getVaultPair(beefyVault);

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, 'Beefy: Input token not present in liqudity pair');

        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        (reserveA, reserveB) = isInputA ? (reserveA, reserveB) : (reserveB, reserveA);

        swapTokenOut = isInputA ? pair.token1() : pair.token0();
        swapAmountIn = _getSwapAmount(pair, fullInvestmentIn, reserveA, reserveB, tokenIn, swapTokenOut);
        swapAmountOut = pair.getAmountOut(swapAmountIn, tokenIn);
    }

*/
  }

  function name() public pure returns (string memory) {
    return "ReverseAlgebraSwapLiquidator";
  }
}
