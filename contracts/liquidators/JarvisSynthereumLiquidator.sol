// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./IRedemptionStrategy.sol";
import "../external/jarvis/ISynthereumLiquidityPool.sol";

contract JarvisSynthereumLiquidator is OwnableUpgradeable, IRedemptionStrategy {
  struct JarvisLiquidator {
    ISynthereumLiquidityPool pool;
    uint256 txExpirationPeriod;
  }

  mapping(address => JarvisLiquidator) public pools;

  /**
   * @dev Initializes a deployer whitelist if desired.
   * @param _pools Jarvis pools used for redeeming the collatoral
   * @param _txExpirationPeriods Expiration periods for the redeeming
   */
  function initialize(ISynthereumLiquidityPool[] memory _pools, uint256[] memory _txExpirationPeriods)
    public
    initializer
  {
    __Ownable_init();
    require(_pools.length == _txExpirationPeriods.length, "length of input arrays must be equal");

    for (uint256 i = 0; i < _pools.length; i++) {
      require(_txExpirationPeriods[i] >= 60 * 10, "at least 10 mins expiration period required");
      IERC20Upgradeable inputToken = ISynthereumLiquidityPool(_pools[i]).syntheticToken();
      pools[address(inputToken)] = JarvisLiquidator({ pool: _pools[i], txExpirationPeriod: _txExpirationPeriods[i] });
    }
  }

  /**
   * @dev Redeems `inputToken` for `outputToken` where `inputAmount` < `outputAmount`
   * @param inputToken Address of the token
   * @param inputAmount Sets `UniswapV2Factory`
   * @param strategyData unused in this contract
   */
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    // approve so the pool can pull out the input tokens
    ISynthereumLiquidityPool pool = pools[address(inputToken)].pool;
    uint256 txExpirationPeriod = pools[address(inputToken)].txExpirationPeriod;

    inputToken.approve(address(pool), inputAmount);

    if (pool.emergencyShutdownPrice() > 0) {
      // emergency shutdowns cannot be reverted, so this corner case must be covered
      (, uint256 collateralSettled) = pool.settleEmergencyShutdown();
      outputAmount = collateralSettled;
      outputToken = IERC20Upgradeable(address(pool.collateralToken()));
    } else {
      // redeem the underlying BUSD
      // fetch the estimated redeemable collateral in BUSD, less the fee paid
      (uint256 redeemableCollateralAmount, ) = pool.getRedeemTradeInfo(inputAmount);

      // Expiration time of the transaction
      uint256 expirationTime = block.timestamp + txExpirationPeriod;

      (uint256 collateralAmountReceived, uint256 feePaid) = pool.redeem(
        ISynthereumLiquidityPool.RedeemParams(inputAmount, redeemableCollateralAmount, expirationTime, address(this))
      );

      outputAmount = collateralAmountReceived;
      outputToken = IERC20Upgradeable(address(pool.collateralToken()));
    }
  }
}
