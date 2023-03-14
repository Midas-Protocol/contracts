// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./MidasERC4626.sol";
import "../../external/compound/ICToken.sol";

import "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import "../../external/angle/IGenericLender.sol";
import "../vault/MultiStrategyVault.sol";
import "../../external/compound/IPriceOracle.sol";

// TODO reentrancy guard?
contract CompoundMarketERC4626 is MidasERC4626, IGenericLender {
  ICToken public market;
  MultiStrategyVault public vault;
  uint256 public blocksPerYear;
  string public lenderName;
  IPriceOracle public oracle;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    ERC20Upgradeable _asset,
    ICToken _market,
    MultiStrategyVault _vault,
    IPriceOracle _oracle,
    uint256 _blocksPerYear
  ) public initializer {
    __MidasER4626_init(_asset);
    lenderName = string(bytes.concat("Midas Optimized ", bytes(_asset.name())));
    market = _market;
    vault = _vault;
    oracle = _oracle;
    blocksPerYear = _blocksPerYear;
  }

  function totalAssets() public view override returns (uint256) {
    // TODO consider making the ctoken balanceOfUnderlying fn a view fn
    return (market.balanceOf(address(this)) * market.exchangeRateHypothetical()) / 1e18;
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    require(market.mint(amount) == 0, "deposit to market failed");
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    require(market.redeem(shares) == 0, "redeem from market failed");
  }

  function aprAfterDeposit(uint256 amount) public view returns (uint256) {
    return market.supplyRatePerBlockAfterDeposit(amount) * blocksPerYear;
  }

  /*------------------------------------------------------------
                        IGenericLender FNs
    ------------------------------------------------------------*/

  /// @notice Helper function to get the current total of assets managed by the lender.
  function nav() external view returns (uint256) {
    return (market.getCash() * oracle.getUnderlyingPrice(market)) / 1e18;
  }

  /// @notice Reference to the `Strategy` contract the lender interacts with
  function strategy() public view returns (address) {
    // TODO remove if we don't want to have a 1:1 relationship
    // between the vault and the market erc4626s?
    return address(vault);
  }

  /// @notice Returns an estimation of the current Annual Percentage Rate on the lender
  function apr() public view override returns (uint256) {
    return market.supplyRatePerBlock() * blocksPerYear;
  }

  /// @notice Returns an estimation of the current Annual Percentage Rate weighted by the assets under
  /// management of the lender
  function weightedApr() external view returns (uint256) {
    return aprAfterDeposit(1e36 / oracle.getUnderlyingPrice(market));
  }

  /// @notice Withdraws a given amount from lender
  /// @param amount The amount the caller wants to withdraw
  /// @return Amount actually withdrawn
  function withdraw(uint256 amount) public override returns (uint256) {
    withdraw(amount, msg.sender, msg.sender);
    return amount;
  }

  /// @notice Withdraws as much as possible in case of emergency and sends it to the `PoolManager`
  /// @param amount Amount to withdraw
  /// @dev Does not check if any error occurs or if the amount withdrawn is correct
  function emergencyWithdraw(uint256 amount) external {
    // TODO
  }

  /// @notice Deposits the current balance of the contract to the lending platform
  function deposit() public override {
    // TODO what do we need this fn for?
    deposit(IERC20Upgradeable(asset()).balanceOf(address(this)), address(this));
  }

  /// @notice Withdraws as much as possible from the lending platform
  /// @return Whether everything was withdrawn or not
  function withdrawAll() public override returns(bool) {
    return withdraw(maxWithdraw(msg.sender), msg.sender, msg.sender) > 0;
  }

  /// @notice Check if assets are currently managed by the lender
  /// @dev We're considering that the strategy has no assets if it has less than 10 of the
  /// underlying asset in total to avoid the case where there is dust remaining on the lending market
  /// and we cannot withdraw everything
  function hasAssets() public view returns (bool) {
    return market.balanceOf(address(this)) > 10;
  }

  /// @notice Returns an estimation of the current Annual Percentage Rate after a new deposit
  /// of `amount`
  /// @param amount Amount to add to the lending platform, and that we want to take into account
  /// in the apr computation
  function aprAfterDeposit(int256 amount) public view override returns (uint256) {
    return aprAfterDeposit(uint256(amount));
  }

  /// @notice
  /// Removes tokens from this Strategy that are not the type of tokens
  /// managed by this Strategy. This may be used in case of accidentally
  /// sending the wrong kind of token to this Strategy.
  ///
  /// This will fail if an attempt is made to sweep `want`, or any tokens
  /// that are protected by this Strategy.
  ///
  /// @param _token The token to transfer out of this poolManager.
  /// @param to Address to send the tokens to.
  function sweep(address _token, address to) public onlyOwner {
    require(_token != asset(), "!asset");

    IERC20Upgradeable token = IERC20Upgradeable(_token);
    token.transfer(to, token.balanceOf(address(this)));
  }

  /// @notice Returns the current balance invested on the lender and related staking contracts
  function underlyingBalanceStored() external view returns (uint256) {
    return totalAssets();
  }
}