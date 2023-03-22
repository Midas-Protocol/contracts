// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./MidasERC4626.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import "../../external/angle/IGenericLender.sol";

// TODO reentrancy guard?
contract CompoundMarketERC4626 is MidasERC4626, IGenericLender {
  ICErc20 public market;
  uint256 public blocksPerYear;

  constructor() {
    _disableInitializers();
  }

  function initialize(ICErc20 market_, uint256 blocksPerYear_) public initializer {
    __MidasER4626_init(ERC20Upgradeable(market_.underlying()));
    market = market_;
    blocksPerYear = blocksPerYear_;
  }

  function lenderName() public view returns (string memory) {
    return string(bytes.concat("Midas Optimized ", bytes(name())));
  }

  function totalAssets() public view override returns (uint256) {
    // TODO consider making the ctoken balanceOfUnderlying fn a view fn
    return (market.balanceOf(address(this)) * market.exchangeRateHypothetical()) / 1e18;
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  // TODO claim rewards from a flywheel
  function afterDeposit(uint256 amount, uint256) internal override {
    ERC20Upgradeable(asset()).approve(address(market), amount);
    require(market.mint(amount) == 0, "deposit to market failed");
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    require(market.redeemUnderlying(amount) == 0, "redeem from market failed");
  }

  function aprAfterDeposit(uint256 amount) public view returns (uint256) {
    return market.supplyRatePerBlockAfterDeposit(amount) * blocksPerYear;
  }

  function aprAfterWithdraw(uint256 amount) public view override returns (uint256) {
    return market.supplyRatePerBlockAfterWithdraw(amount) * blocksPerYear;
  }

  function emergencyWithdrawAndPause() external override(IGenericLender, MidasERC4626) {
    require(
      msg.sender == owner(), /*|| msg.sender == vault*/
      "not owner or vault"
    );
    require(market.redeem(market.balanceOf(address(this))) == 0, "redeem all failed");
    _pause();
  }

  function unpause() external override onlyOwner {
    deposit();
    _unpause();
  }

  /*------------------------------------------------------------
                        IGenericLender FNs
    ------------------------------------------------------------*/

  /// @notice Helper function to get the current total of assets managed by the lender.
  function nav() public view returns (uint256) {
    return (market.balanceOf(address(this)) * market.exchangeRateHypothetical()) / 1e18;
  }

  /// @notice Returns an estimation of the current Annual Percentage Rate on the lender
  function apr() public view override returns (uint256) {
    return market.supplyRatePerBlock() * blocksPerYear;
  }

  /// @notice Returns an estimation of the current Annual Percentage Rate weighted by the assets under
  /// management of the lender
  function weightedApr() external view returns (uint256) {
    return (apr() * nav()) / 1e18;
  }

  function weightedAprAfterDeposit(uint256 amount) public view returns (uint256) {
    return (aprAfterDeposit(amount) * (nav() + amount)) / 1e18;
  }

  /// @notice Withdraws a given amount from lender
  /// @param amount The amount the caller wants to withdraw
  /// @return Amount actually withdrawn
  function withdraw(uint256 amount) public override returns (uint256) {
    withdraw(amount, msg.sender, msg.sender);
    return amount;
  }

  // TODO remove this fn?
  /// @notice Deposits the current balance of the contract to the lending platform
  function deposit() public override onlyOwner {
    // TODO what do we need this fn for?
    deposit(IERC20Upgradeable(asset()).balanceOf(address(this)), address(this));
  }

  function deposit(uint256 amount) public {
    deposit(amount, address(this));
  }

  /// @notice Withdraws as much as possible from the lending platform
  /// @return Whether everything was withdrawn or not
  function withdrawAll() public override returns (bool) {
    return withdraw(maxWithdraw(msg.sender), msg.sender, msg.sender) > 0;
  }

  /// @notice Check if assets are currently managed by the lender
  /// @dev We're considering that the strategy has no assets if it has less than 10 of the
  /// underlying asset in total to avoid the case where there is dust remaining on the lending market
  /// and we cannot withdraw everything
  function hasAssets() public view returns (bool) {
    return market.balanceOf(address(this)) > 10;
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
