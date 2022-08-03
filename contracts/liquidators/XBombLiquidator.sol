// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../external/bomb/IXBomb.sol";
import "./IRedemptionStrategy.sol";

/**
 * @title XBombLiquidator
 * @notice Exchanges seized xBOMB collateral for underlying BOMB tokens for use as a step in a liquidation.
 * @author Veliko Minkov <veliko@midascapital.xyz>
 */
contract XBombLiquidator is IRedemptionStrategy {
  address xbomb = 0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b;
  IERC20Upgradeable bomb = IERC20Upgradeable(0x522348779DCb2911539e76A1042aA922F9C47Ee3);

  /**
   * @notice Redeems xBOMB for the underlying BOMB reward tokens.
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
    if (address(inputToken) == xbomb) {
      // burns the xBOMB and returns the underlying BOMB to the liquidator
      IXBomb(xbomb).leave(inputAmount);

      outputToken = bomb;
      outputAmount = outputToken.balanceOf(address(this));
    } else if (inputToken == bomb) {
      // mints xBOMB
      IXBomb(xbomb).enter(inputAmount);

      outputToken = IERC20Upgradeable(xbomb);
      outputAmount = outputToken.balanceOf(address(this));
    } else {
      revert("unknown input token");
    }
  }
}
