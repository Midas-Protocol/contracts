// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IComptroller } from "./ComptrollerInterface.sol";
import { InterestRateModel } from "./InterestRateModel.sol";

abstract contract CTokenAdminStorage {
  /*
   * Administrator for Ionic
   */
  address payable public ionicAdmin;

  /**
   * @dev LEGACY USE ONLY: Administrator for this contract
   */
  address payable internal __admin;

  /**
   * @dev LEGACY USE ONLY: Whether or not the Ionic admin has admin rights
   */
  bool internal __ionicAdminHasRights;

  /**
   * @dev LEGACY USE ONLY: Whether or not the admin has admin rights
   */
  bool internal __adminHasRights;
}

abstract contract CTokenStorage is CTokenAdminStorage {
  /**
   * @dev Guard variable for re-entrancy checks
   */
  bool internal _notEntered;

  /**
   * @notice EIP-20 token name for this token
   */
  string public name;

  /**
   * @notice EIP-20 token symbol for this token
   */
  string public symbol;

  /**
   * @notice EIP-20 token decimals for this token
   */
  uint8 public decimals;

  /*
   * Maximum borrow rate that can ever be applied (.0005% / block)
   */
  uint256 internal constant borrowRateMaxMantissa = 0.0005e16;

  /*
   * Maximum fraction of interest that can be set aside for reserves + fees
   */
  uint256 internal constant reserveFactorPlusFeesMaxMantissa = 1e18;

  /**
   * @notice Contract which oversees inter-cToken operations
   */
  IComptroller public comptroller;

  /**
   * @notice Model which tells what the current interest rate should be
   */
  InterestRateModel public interestRateModel;

  /*
   * Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
   */
  uint256 internal initialExchangeRateMantissa;

  /**
   * @notice Fraction of interest currently set aside for admin fees
   */
  uint256 public adminFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for Ionic fees
   */
  uint256 public ionicFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for reserves
   */
  uint256 public reserveFactorMantissa;

  /**
   * @notice Block number that interest was last accrued at
   */
  uint256 public accrualBlockNumber;

  /**
   * @notice Accumulator of the total earned interest rate since the opening of the market
   */
  uint256 public borrowIndex;

  /**
   * @notice Total amount of outstanding borrows of the underlying in this market
   */
  uint256 public totalBorrows;

  /**
   * @notice Total amount of reserves of the underlying held in this market
   */
  uint256 public totalReserves;

  /**
   * @notice Total amount of admin fees of the underlying held in this market
   */
  uint256 public totalAdminFees;

  /**
   * @notice Total amount of Ionic fees of the underlying held in this market
   */
  uint256 public totalIonicFees;

  /**
   * @notice Total number of tokens in circulation
   */
  uint256 public totalSupply;

  /*
   * Official record of token balances for each account
   */
  mapping(address => uint256) internal accountTokens;

  /*
   * Approved token transfer amounts on behalf of others
   */
  mapping(address => mapping(address => uint256)) internal transferAllowances;

  /**
   * @notice Container for borrow balance information
   * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
   * @member interestIndex Global borrowIndex as of the most recent balance-changing action
   */
  struct BorrowSnapshot {
    uint256 principal;
    uint256 interestIndex;
  }

  /*
   * Mapping of account addresses to outstanding borrow balances
   */
  mapping(address => BorrowSnapshot) internal accountBorrows;

  /*
   * Share of seized collateral that is added to reserves
   */
  uint256 public constant protocolSeizeShareMantissa = 2.8e16; //2.8%

  /*
   * Share of seized collateral taken as fees
   */
  uint256 public constant feeSeizeShareMantissa = 1e17; //10%
}

// TODO merge with CTokenStorage
abstract contract CErc20Storage is CTokenStorage {
  /**
   * @notice Underlying asset for this CToken
   */
  address public underlying;
}

abstract contract CTokenBaseEvents {
  /* ERC20 */

  /**
   * @notice EIP20 Transfer event
   */
  event Transfer(address indexed from, address indexed to, uint256 amount);

  /*** Admin Events ***/

  /**
   * @notice Event emitted when interestRateModel is changed
   */
  event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

  /**
   * @notice Event emitted when the reserve factor is changed
   */
  event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);

  /**
   * @notice Event emitted when the admin fee is changed
   */
  event NewAdminFee(uint256 oldAdminFeeMantissa, uint256 newAdminFeeMantissa);

  /**
   * @notice Event emitted when the Ionic fee is changed
   */
  event NewFuseFee(uint256 oldFuseFeeMantissa, uint256 newFuseFeeMantissa);

  /**
   * @notice EIP20 Approval event
   */
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /**
   * @notice Event emitted when interest is accrued
   */
  event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
}

abstract contract CTokenExtensionEvents is CTokenBaseEvents {
  event Flash(address receiver, uint256 amount);
}

abstract contract CTokenEvents is CTokenBaseEvents {
  /*** Market Events ***/

  /**
   * @notice Event emitted when tokens are minted
   */
  event Mint(address minter, uint256 mintAmount, uint256 mintTokens);

  /**
   * @notice Event emitted when tokens are redeemed
   */
  event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);

  /**
   * @notice Event emitted when underlying is borrowed
   */
  event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is repaid
   */
  event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is liquidated
   */
  event LiquidateBorrow(
    address liquidator,
    address borrower,
    uint256 repayAmount,
    address cTokenCollateral,
    uint256 seizeTokens
  );

  /**
   * @notice Event emitted when the reserves are added
   */
  event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);

  /**
   * @notice Event emitted when the reserves are reduced
   */
  event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
}

interface CTokenExtensionInterface {
  /*** User Interface ***/

  function transfer(address dst, uint256 amount) external returns (bool);

  function transferFrom(
    address src,
    address dst,
    uint256 amount
  ) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  /*** Admin Functions ***/

  function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

  function _setAdminFee(uint256 newAdminFeeMantissa) external returns (uint256);

  function _setInterestRateModel(InterestRateModel newInterestRateModel) external returns (uint256);

  function getAccountSnapshot(address account)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  function borrowRatePerBlock() external view returns (uint256);

  function supplyRatePerBlock() external view returns (uint256);

  function exchangeRateCurrent() external view returns (uint256);

  function accrueInterest() external returns (uint256);

  function totalBorrowsCurrent() external view returns (uint256);

  function borrowBalanceCurrent(address account) external view returns (uint256);

  function getTotalUnderlyingSupplied() external view returns (uint256);

  function balanceOfUnderlying(address owner) external view returns (uint256);

  function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

  function flash(uint256 amount, bytes calldata data) external;

  function supplyRatePerBlockAfterDeposit(uint256 mintAmount) external view returns (uint256);

  function supplyRatePerBlockAfterWithdraw(uint256 withdrawAmount) external view returns (uint256);

  function borrowRatePerBlockAfterBorrow(uint256 borrowAmount) external view returns (uint256);
}

interface CTokenInterface {
  function getCash() external view returns (uint256);

  function seize(
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external returns (uint256);

  /*** Admin Functions ***/

  function _withdrawAdminFees(uint256 withdrawAmount) external returns (uint256);

  function _withdrawFuseFees(uint256 withdrawAmount) external returns (uint256);

  function selfTransferOut(address to, uint256 amount) external;

  function selfTransferIn(address from, uint256 amount) external returns (uint256);
}

interface CErc20Interface is CTokenInterface {
  function mint(uint256 mintAmount) external returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

  function borrow(uint256 borrowAmount) external returns (uint256);

  function repayBorrow(uint256 repayAmount) external returns (uint256);

  function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

  function liquidateBorrow(
    address borrower,
    uint256 repayAmount,
    address cTokenCollateral
  ) external returns (uint256);
}

interface CDelegateInterface {
  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(
    address implementation_,
    bool allowResign,
    bytes calldata becomeImplementationData
  ) external;

  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   * @dev Should revert if any issues arise which make it unfit for delegation
   * @param data The encoded bytes data for any initialization
   */
  function _becomeImplementation(bytes calldata data) external;

  /**
   * @notice Function called before all delegator functions
   * @dev Checks comptroller.autoImplementation and upgrades the implementation if necessary
   */
  function _prepare() external payable;

  function delegateType() external pure returns (uint8);

  function contractType() external pure returns (string memory);
}

abstract contract CTokenExtensionBase is CErc20Storage, CTokenExtensionEvents, CTokenExtensionInterface {}

// TODO replace CTokenInterface with CErc20Interface after merging CErc20 with CToken
abstract contract CTokenZeroExtBase is CErc20Storage, CTokenEvents, CTokenInterface, CDelegateInterface {
  /**
 * @notice Emitted when implementation is changed
   */
  event NewImplementation(address oldImplementation, address newImplementation);
}

abstract contract CErc20DelegatorBase is CErc20Storage, CTokenEvents {}

interface CErc20StorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdminHasRights() external view returns (bool);

  function comptroller() external view returns (IComptroller);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function adminFeeMantissa() external view returns (uint256);

  function ionicFeeMantissa() external view returns (uint256);

  function reserveFactorMantissa() external view returns (uint256);

  function protocolSeizeShareMantissa() external view returns (uint256);

  function feeSeizeShareMantissa() external view returns (uint256);

  function totalReserves() external view returns (uint256);

  function totalAdminFees() external view returns (uint256);

  function totalIonicFees() external view returns (uint256);

  function totalBorrows() external view returns (uint256);

  function accrualBlockNumber() external view returns (uint256);

  function underlying() external view returns (address);
}

interface CErc20PluginStorageInterface is CErc20StorageInterface {
  function plugin() external view returns (address);
}

// TODO merge with ICErc20
interface ICToken is CErc20StorageInterface, CErc20Interface, CTokenExtensionInterface {}

interface ICErc20 is ICToken, CDelegateInterface {}

interface ICErc20Plugin is CErc20PluginStorageInterface, ICToken, CDelegateInterface {}
