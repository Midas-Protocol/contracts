// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./MidasERC4626.sol";
import "../../external/compound/ICToken.sol";

import "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";

// TODO reentrancy guard?
contract CompoundMarketERC4626 is MidasERC4626 {
  ICToken public market;
  uint256 public blocksPerYear;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    ERC20Upgradeable _asset,
    ICToken _market,
    uint256 _blocksPerYear
  ) public initializer {
    __MidasER4626_init(_asset);
    market = _market;
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

  // TODO twapped APR?
  function apr() public view returns (uint256) {
    return market.supplyRatePerBlock() * blocksPerYear;
  }

  function aprAfterDeposit(uint256 amount) public view returns (uint256) {
    return market.supplyRatePerBlockAfterDeposit(amount) * blocksPerYear;
  }
}
