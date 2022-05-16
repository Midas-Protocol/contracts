// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import "../external/jarvis/ISynthereumLiquidityPool.sol";

contract JarvisSynthereumLiquidator is IRedemptionStrategy {
    ISynthereumLiquidityPool public immutable pool;
    uint64 public immutable txExpirationPeriod;

    constructor(ISynthereumLiquidityPool _pool, uint64 _txExpirationPeriod) {
        pool = _pool;

        // check added per the audit comments
        require(
            _txExpirationPeriod >= 60 * 10,
            "at least 10 mins expiration period required"
        );
        // time limit to include the tx in a block as anti-slippage measure
        txExpirationPeriod = _txExpirationPeriod;
    }

    /**
     * @dev Redeems `inputToken` for `outputToken`
     * @param inputToken Address of the token
     * @param inputAmount Sets `UniswapV2Factory`
     * @param strategyData TODO unused?
     */
    function redeem(
        IERC20Upgradeable inputToken,
        uint256 inputAmount,
        bytes memory strategyData
    )
        external
        override
        returns (IERC20Upgradeable outputToken, uint256 outputAmount)
    {
        // approve so the pool can pull out the input tokens
        inputToken.approve(address(pool), inputAmount);

        if (pool.emergencyShutdownPrice() > 0) {
            // emergency shutdowns cannot be reverted, so this corner case must be covered
            (, uint256 collateralSettled) = pool.settleEmergencyShutdown();
            outputAmount = collateralSettled;
            outputToken = IERC20Upgradeable(address(pool.collateralToken()));
        } else {
            // redeem the underlying BUSD
            // fetch the estimated redeemable collateral in BUSD, less the fee paid
            (uint256 redeemableCollateralAmount, ) = pool.getRedeemTradeInfo(
                inputAmount
            );

            // Expiration time of the transaction
            uint256 expirationTime = block.timestamp + txExpirationPeriod;

            (uint256 collateralAmountReceived, uint256 feePaid) = pool.redeem(
                ISynthereumLiquidityPool.RedeemParams(
                    inputAmount,
                    redeemableCollateralAmount,
                    expirationTime,
                    address(this)
                )
            );

            outputAmount = collateralAmountReceived;
            outputToken = IERC20Upgradeable(address(pool.collateralToken()));
        }
    }
}
