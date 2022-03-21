// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import "../external/jarvis/ISynthereumLiquidityPool.sol";

contract JarvisSynthereumLiquidator is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    ISynthereumLiquidityPool pool = ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49);

    (uint256 collateralRedeemed, uint256 feePaid) = pool.getRedeemTradeInfo(inputAmount);

    pool.redeem(
      ISynthereumLiquidityPool.RedeemParams(
        inputAmount,
        collateralRedeemed,
        block.timestamp + 60*40, // 40 mins forward
        address(this)
      )
    );
  }
}
