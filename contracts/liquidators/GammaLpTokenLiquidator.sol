// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import { IHypervisor } from "../external/gamma/IHypervisor.sol";
import { IUniProxy } from "../external/gamma/IUniProxy.sol";
import { ISwapRouter } from "../external/algebra/ISwapRouter.sol";
import { IAlgebraPool } from "../external/algebra/IAlgebraPool.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title GammaLpTokenLiquidator
 * @notice Exchanges seized Gamma LP token collateral for underlying tokens via an Algebra pool for use as a step in a liquidation.
 * @author Veliko Minkov <veliko@midascapital.xyz> (https://github.com/vminkov)
 */
contract GammaLpTokenLiquidator is IRedemptionStrategy {
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
    // Get Gamma pool and underlying tokens
    IHypervisor vault = IHypervisor(address(inputToken));

    // First withdraw the underlying tokens
    uint256[4] memory minAmounts;
    vault.withdraw(inputAmount, address(this), address(this), minAmounts);

    // then swap one of the underlying for the other
    IERC20Upgradeable token0 = IERC20Upgradeable(vault.token0());
    IERC20Upgradeable token1 = IERC20Upgradeable(vault.token1());

    (address _outputToken, ISwapRouter swapRouter) = abi.decode(strategyData, (address, ISwapRouter));

    uint256 swapAmount;
    IERC20Upgradeable tokenToSwap;
    if (_outputToken == address(token1)) {
      swapAmount = token0.balanceOf(address(this));
      tokenToSwap = token0;
    } else {
      swapAmount = token1.balanceOf(address(this));
      tokenToSwap = token1;
    }

    tokenToSwap.approve(address(swapRouter), swapAmount);

    swapRouter.exactInputSingle(
      ISwapRouter.ExactInputSingleParams(
        address(tokenToSwap),
        _outputToken,
        address(this),
        block.timestamp,
        swapAmount,
        0, // amountOutMinimum
        0 // limitSqrtPrice
      )
    );

    outputToken = IERC20Upgradeable(_outputToken);
    outputAmount = outputToken.balanceOf(address(this));
  }

  function name() public pure returns (string memory) {
    return "GammaLpTokenLiquidator";
  }
}

contract GammaLpTokenWrapper is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (ISwapRouter swapRouter, IUniProxy proxy, IHypervisor vault) = abi.decode(
      strategyData,
      (ISwapRouter, IUniProxy, IHypervisor)
    );

    address token0 = vault.token0();
    address token1 = vault.token1();
    {
      uint256 swapAmount;
      {
        uint256 ratio;
        uint256 price;
        {
          uint256 token0Decimals = 10**ERC20Upgradeable(token0).decimals();
          uint256 token1Decimals = 10**ERC20Upgradeable(token1).decimals();
          {
            uint256 decimalsDiff = (1e18 * token0Decimals) / token1Decimals;
            uint256 decimalsDenominator = decimalsDiff > 1e12 ? 1e6 : 1;
            (uint256 sqrtPriceX96, , , , , , ) = IAlgebraPool(vault.pool()).globalState();
            price = ((sqrtPriceX96**2 * (decimalsDiff / decimalsDenominator)) / (2**192)) * decimalsDenominator;
          }
          (uint256 amountStart, uint256 amountEnd) = proxy.getDepositAmount(address(vault), token0, token0Decimals);
          uint256 amount1 = (((amountStart + amountEnd) / 2) * 1e18) / token1Decimals;
          ratio = (amount1 * 1e18) / price;
        }

        uint256 swap0 = (inputAmount * 1e18) / (ratio + 1e18);
        swapAmount = address(inputToken) == token0 ? inputAmount - swap0 : swap0;
      }

      inputToken.approve(address(swapRouter), inputAmount);
      swapRouter.exactInputSingle(
        ISwapRouter.ExactInputSingleParams(
          address(inputToken),
          address(inputToken) == token0 ? token1 : token0,
          address(this),
          block.timestamp,
          swapAmount,
          0, // amount out min
          0 // limitSqrtPrice
        )
      );
    }

    uint256 deposit0;
    uint256 deposit1;
    {
      deposit0 = IERC20Upgradeable(token0).balanceOf(address(this));
      deposit1 = IERC20Upgradeable(token1).balanceOf(address(this));
      IERC20Upgradeable(token0).approve(address(vault), deposit0);
      IERC20Upgradeable(token1).approve(address(vault), deposit1);
    }

    uint256[4] memory minIn;
    outputAmount = proxy.deposit(
      deposit0,
      deposit1,
      address(this), // to
      address(vault),
      minIn
    );

    outputToken = IERC20Upgradeable(address(vault));
  }

  function name() public pure returns (string memory) {
    return "GammaLpTokenWrapper";
  }
}
