// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "./IFuseFeeDistributor.sol";
import "./ComptrollerStorage.sol";
import "./ComptrollerInterface.sol";
import "./InterestRateModel.sol";

contract CTokenAdminStorage {
    /*
     * Administrator for Fuse
     */
    IFuseFeeDistributor internal constant fuseAdmin = IFuseFeeDistributor(0x530b8A1c84594a730B8FbebD9C3a4696dDDe97Ff);

    /**
     * @dev LEGACY USE ONLY: Administrator for this contract
     */
    address payable internal __admin;

    /**
     * @dev LEGACY USE ONLY: Whether or not the Fuse admin has admin rights
     */
    bool internal __fuseAdminHasRights;

    /**
     * @dev LEGACY USE ONLY: Whether or not the admin has admin rights
     */
    bool internal __adminHasRights;
}

contract CTokenStorage is CTokenAdminStorage {
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
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    /*
     * Maximum fraction of interest that can be set aside for reserves + fees
     */
    uint internal constant reserveFactorPlusFeesMaxMantissa = 1e18;

    /*
     * LEGACY USE ONLY: Pending administrator for this contract
     */
    address payable private __pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Model which tells what the current interest rate should be
     */
    InterestRateModel public interestRateModel;

    /*
     * Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
     */
    uint internal initialExchangeRateMantissa;

    /**
     * @notice Fraction of interest currently set aside for admin fees
     */
    uint public adminFeeMantissa;

    /**
     * @notice Fraction of interest currently set aside for Fuse fees
     */
    uint public fuseFeeMantissa;

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint public reserveFactorMantissa;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockNumber;

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    uint public borrowIndex;

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    uint public totalBorrows;

    /**
     * @notice Total amount of reserves of the underlying held in this market
     */
    uint public totalReserves;

    /**
     * @notice Total amount of admin fees of the underlying held in this market
     */
    uint public totalAdminFees;

    /**
     * @notice Total amount of Fuse fees of the underlying held in this market
     */
    uint public totalFuseFees;

    /**
     * @notice Total number of tokens in circulation
     */
    uint public totalSupply;

    /*
     * Official record of token balances for each account
     */
    mapping (address => uint) internal accountTokens;

    /*
     * Approved token transfer amounts on behalf of others
     */
    mapping (address => mapping (address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    /*
     * Mapping of account addresses to outstanding borrow balances
     */
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /*
     * Share of seized collateral that is added to reserves
     */
    uint public constant protocolSeizeShareMantissa = 2.8e16; //2.8%
}

abstract contract CTokenInterface is CTokenStorage {
    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    function isCToken() external virtual returns (bool) {
        return true;
    }

    /**
     * @notice Indicator that this is or is not a CEther contract (for inspection)
     */
    function isCEther() external virtual returns (bool) {
        return false;
    }

    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint mintAmount, uint mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);


    /*** Admin Events ***/

    /**
     * @notice Event emitted when comptroller is changed
     */
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);

    /**
     * @notice Event emitted when interestRateModel is changed
     */
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /**
     * @notice Event emitted when the reserves are added
     */
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);

    /**
     * @notice Event emitted when the admin fee is changed
     */
    event NewAdminFee(uint oldAdminFeeMantissa, uint newAdminFeeMantissa);

    /**
     * @notice Event emitted when the Fuse fee is changed
     */
    event NewFuseFee(uint oldFuseFeeMantissa, uint newFuseFeeMantissa);

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);


    /*** User Interface ***/

    function transfer(address dst, uint amount) virtual external returns (bool);
    function transferFrom(address src, address dst, uint amount) virtual external returns (bool);
    function approve(address spender, uint amount) virtual external returns (bool);
    function allowance(address owner, address spender) external virtual view returns (uint);
    function balanceOf(address owner) external virtual view returns (uint);
    function balanceOfUnderlying(address owner) virtual external returns (uint);
    function getAccountSnapshot(address account) virtual external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external virtual view returns (uint);
    function supplyRatePerBlock() external virtual view returns (uint);
    function totalBorrowsCurrent() virtual external returns (uint);
    function borrowBalanceCurrent(address account) virtual external returns (uint);
    function borrowBalanceStored(address account) public virtual view returns (uint);
    function exchangeRateCurrent() virtual public returns (uint);
    function exchangeRateStored() public virtual view returns (uint);
    function getCash() external virtual view returns (uint);
    function accrueInterest() virtual public returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) virtual external returns (uint);


    /*** Admin Functions ***/

    function _setReserveFactor(uint newReserveFactorMantissa) virtual external returns (uint);
    function _reduceReserves(uint reduceAmount) virtual external returns (uint);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) virtual public returns (uint);
}

contract CErc20Storage {
    /**
     * @notice Underlying asset for this CToken
     */
    address public underlying;
}

abstract contract CErc20Interface is CErc20Storage {

    /*** User Interface ***/

    function mint(uint mintAmount) virtual external returns (uint);
    function redeem(uint redeemTokens) virtual external returns (uint);
    function redeemUnderlying(uint redeemAmount) virtual external returns (uint);
    function borrow(uint borrowAmount) virtual external returns (uint);
    function repayBorrow(uint repayAmount) virtual external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) virtual external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) virtual external returns (uint);

}

contract CEtherInterface is CErc20Storage {}
