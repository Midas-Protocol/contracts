// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import { IHypervisor } from "../external/gamma/IHypervisor.sol";
import { IUniProxy } from "../external/gamma/IUniProxy.sol";
import { ISwapRouter } from "../external/algebra/ISwapRouter.sol";

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

  function name() public view returns (string memory) {
    return "GammaLpTokenLiquidator";
  }
}

contract GammaLpTokenWrapper is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (ISwapRouter swapRouter, IUniProxy proxy, IHypervisor vault) = abi.decode(strategyData, (ISwapRouter, IUniProxy, IHypervisor));
    address otherToken;
    uint256 amountOtherOut;
    {
      require(address(inputToken) == vault.token0() || address(inputToken) == vault.token1(), "input token not pair underlying");
      otherToken = address(inputToken) == vault.token0() ? vault.token1() : vault.token0();
    }

//    {
//      uint256 halfInputAmount = inputAmount / 2;
//      (uint256 depositOtherMin, uint256 depositOtherMax) = proxy.getDepositAmount(address(vault), address(inputToken), inputAmount);
//      uint256 targetAmountOther = (depositOtherMin + depositOtherMax) / 2;
//
//      inputToken.approve(address(swapRouter), halfInputAmount);
//      amountOtherOut = swapRouter.exactInputSingle(
//        ISwapRouter.ExactInputSingleParams(
//          address(inputToken),
//          otherToken,
//          address(this),
//          block.timestamp,
//          halfInputAmount,
//          0, //depositOtherMin, // amountOutMinimum
//          0 // limitSqrtPrice
//        )
//      );
//    }

    uint256 deposit0;
    uint256 deposit1;
    bool zeroForOne = address(inputToken) == vault.token0();
    {
      (uint256 depositInputTokenMin, uint256 depositInputTokenMax) = proxy.getDepositAmount(address(vault), otherToken, amountOtherOut);
      deposit0 = zeroForOne ? (depositInputTokenMin + depositInputTokenMax) / 2 : amountOtherOut;
      deposit1 = !zeroForOne ? (depositInputTokenMin + depositInputTokenMax) / 2 : amountOtherOut;
    }

    uint256[4] memory minIn;
    //    if (vault.directDeposit()) {
    //      // TODO should we estimate minIn or 0 values are ok?
    //      (uint256 depositInputTokenMin, uint256 depositInputTokenMax) = proxy.getDepositAmount(address(vault), otherToken, amountOtherOut);
    //      minIn[0]
    //    }

    outputAmount = proxy.deposit(
      deposit0,
      deposit1,
      address(this), // to
      address(vault),
      minIn
    );

    outputToken = IERC20Upgradeable(address(vault));
  }

  function name() public view returns (string memory) {
    return "GammaLpTokenWrapper";
  }
}