// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { IonicERC4626 } from "./IonicERC4626.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IAaveV3Pool {
  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62-63: reserved
    //bit 64-79: reserve factor
    //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
    //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
    //bit 152-167 liquidation protocol fee
    //bit 168-175 eMode category
    //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
    //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
    //bit 252-255 unused
    uint256 data;
  }

  struct ReserveData {
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //aToken address
    address aTokenAddress;
    //stableDebtToken address
    address stableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the current treasury balance, scaled
    uint128 accruedToTreasury;
    //the outstanding unbacked aTokens minted through the bridging feature
    uint128 unbacked;
    //the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
  }

  /**
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   * wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   * is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   * 0 if the action is executed directly by the user, without any middle-man
   *
   */
  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   * - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to The address that will receive the underlying, same as msg.sender if the user
   * wants to receive it on his own wallet, or a different address if the beneficiary is a
   * different wallet
   * @return The final amount withdrawn
   *
   */
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @notice Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state and configuration data of the reserve
   *
   */
  function getReserveData(address asset) external view returns (ReserveData memory);

  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );
}

contract AaveV3ERC4626 is IonicERC4626 {
  using FixedPointMathLib for uint256;
  IAaveV3Pool public pool;

  function initialize(ERC20Upgradeable _asset, IAaveV3Pool _pool) public initializer {
    __MidasER4626_init(_asset);

    pool = _pool;

    _asset.approve(address(pool), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    address aTokenAddress = pool.getReserveData(address(_asset())).aTokenAddress;

    return ERC20Upgradeable(aTokenAddress).balanceOf(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 assets, uint256 shares) internal override {
    pool.supply(address(_asset()), assets, address(this), 0);
  }

  function beforeWithdraw(uint256 assets, uint256) internal override {
    pool.withdraw(address(_asset()), assets, address(this));
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    pool.withdraw(address(_asset()), type(uint256).max, address(this));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    pool.supply(address(_asset()), _asset().balanceOf(address(this)), address(this), 0);
  }
}
