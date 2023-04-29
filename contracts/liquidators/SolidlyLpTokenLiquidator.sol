// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
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
}
