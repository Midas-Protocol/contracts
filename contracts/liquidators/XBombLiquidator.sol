pragma solidity >=0.8.0;

import "../external/bomb/IXBomb.sol";
import "./IRedemptionStrategy.sol";

/**
 * @title XBombLiquidator
 * @notice Exchanges seized xBOMB collateral for underlying BOMB tokens for use as a step in a liquidation.
 * @author Veliko <veliko@midascapital.xyz>
 */
contract XBombLiquidator is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    IXBomb xBomb = IXBomb(address(inputToken));
    //    uint256 expectedReward = xBomb.toREWARD(inputAmount);

    xBomb.leave(inputAmount);

    //    outputAmount = xBomb.reward().balanceOf(address(this));
    //    require(outputAmount >= expectedReward);

    outputToken = IERC20Upgradeable(address(xBomb.reward()));
    outputAmount = xBomb.reward().balanceOf(address(this));
  }
}
