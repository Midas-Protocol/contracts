// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../external/solidly/IRouter.sol";
import "../external/solidly/IPair.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title SolidlyLpTokenLiquidator
 * @notice Exchanges seized Solidly LP token collateral for underlying tokens for use as a step in a liquidation.
 */
contract SolidlyLpTokenLiquidator is IRedemptionStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
   */
  function safeApprove(
    IERC20Upgradeable token,
    address to,
    uint256 minAmount
  ) internal {
    uint256 allowance = token.allowance(address(this), to);

    if (allowance < minAmount) {
      if (allowance > 0) token.safeApprove(to, 0);
      token.safeApprove(to, type(uint256).max);
    }
  }

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
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    // Exit Uniswap pool
    IPair pair = IPair(address(inputToken));
    bool stable = pair.stable();

    address token0 = pair.token0();
    address token1 = pair.token1();
    pair.transfer(address(pair), inputAmount);
    (uint256 amount0, uint256 amount1) = pair.burn(address(this));

    // Swap underlying tokens
    (IRouter solidlyRouter, address tokenTo) = abi.decode(strategyData, (IRouter, address));

    if (tokenTo != token0) {
      safeApprove(IERC20Upgradeable(token0), address(solidlyRouter), amount0);
      solidlyRouter.swapExactTokensForTokensSimple(amount0, 0, token0, tokenTo, stable, address(this), block.timestamp);
    } else {
      safeApprove(IERC20Upgradeable(token1), address(solidlyRouter), amount1);
      solidlyRouter.swapExactTokensForTokensSimple(amount1, 0, token1, tokenTo, stable, address(this), block.timestamp);
    }
    // Get new collateral
    outputToken = IERC20Upgradeable(tokenTo);
    outputAmount = outputToken.balanceOf(address(this));
  }

  function name() public pure returns (string memory) {
    return "SolidlyLpTokenLiquidator";
  }
}

contract SolidlyLpTokenWrapper is IRedemptionStrategy {
  struct WrapSolidlyLpTokenVars {
    uint256 amountFor0;
    uint256 amountFor1;
    IRouter solidlyRouter;
    address token0;
    address token1;
    bool stable;
    IPair pair;
    IRouter.route[] swapPath0;
    IRouter.route[] swapPath1;
  }

  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    WrapSolidlyLpTokenVars memory vars;

    vars.amountFor0 = inputAmount / 2;
    vars.amountFor1 = inputAmount - vars.amountFor0;

    (vars.solidlyRouter, vars.pair, vars.swapPath0, vars.swapPath1) = abi.decode(
      strategyData,
      (IRouter, IPair, IRouter.route[], IRouter.route[])
    );
    vars.token0 = vars.pair.token0();
    vars.token1 = vars.pair.token1();

    vars.stable = vars.pair.stable();
    if (vars.stable) {
      uint256 token0Decimals = 10**ERC20Upgradeable(vars.token0).decimals();
      uint256 token1Decimals = 10**ERC20Upgradeable(vars.token1).decimals();
      uint256 out0 = (vars.solidlyRouter.getAmountsOut(vars.amountFor0, vars.swapPath0)[vars.swapPath0.length] * 1e18) /
        token0Decimals;
      uint256 out1 = (vars.solidlyRouter.getAmountsOut(vars.amountFor1, vars.swapPath1)[vars.swapPath1.length] * 1e18) /
        token1Decimals;

      (uint256 amountA, uint256 amountB, ) = vars.solidlyRouter.quoteAddLiquidity(
        vars.token0,
        vars.token1,
        vars.stable,
        out0,
        out1
      );

      amountA = (amountA * 1e18) / token0Decimals;
      amountB = (amountB * 1e18) / token1Decimals;
      uint256 ratio = (((out0 * 1e18) / out1) * amountB) / amountA;
      vars.amountFor0 = (inputAmount * 1e18) / (ratio + 1e18);
      vars.amountFor1 = inputAmount - vars.amountFor0;
    }

    if (vars.token0 == address(inputToken)) {
      inputToken.approve(address(vars.solidlyRouter), vars.amountFor0);
      vars.solidlyRouter.swapExactTokensForTokens(vars.amountFor0, 0, vars.swapPath0, address(this), block.timestamp);
    }
    if (vars.token1 == address(inputToken)) {
      inputToken.approve(address(vars.solidlyRouter), vars.amountFor1);
      vars.solidlyRouter.swapExactTokensForTokens(vars.amountFor1, 0, vars.swapPath1, address(this), block.timestamp);
    }

    uint256 lp0Bal = IERC20Upgradeable(vars.token0).balanceOf(address(this));
    uint256 lp1Bal = IERC20Upgradeable(vars.token1).balanceOf(address(this));
    IERC20Upgradeable(vars.token0).approve(address(vars.solidlyRouter), lp0Bal);
    IERC20Upgradeable(vars.token1).approve(address(vars.solidlyRouter), lp1Bal);
    vars.solidlyRouter.addLiquidity(
      vars.token0,
      vars.token1,
      vars.stable,
      lp0Bal,
      lp1Bal,
      1,
      1,
      address(this),
      block.timestamp
    );

    outputToken = IERC20Upgradeable(address(vars.pair));
    outputAmount = outputToken.balanceOf(address(this));
  }

  function name() public pure returns (string memory) {
    return "SolidlyLpTokenWrapper";
  }
}
