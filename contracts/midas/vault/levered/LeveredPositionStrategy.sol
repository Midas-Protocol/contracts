// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ICErc20 } from "../../../external/compound/ICErc20.sol";
import { IComptroller } from "../../../external/compound/IComptroller.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LeveredPositionStrategy {
  using SafeERC20 for IERC20;

  address public positionOwner;
  ICErc20 public collateralMarket;
  ICErc20 public stableMarket;
  uint256 public totalAssets;

  constructor(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    address _positionOwner
  ) {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets pools differ");

    positionOwner = _positionOwner;
    collateralMarket = _collateralMarket;
    stableMarket = _stableMarket;
    totalAssets = 0;
  }

  function fundPosition(IERC20 collateralAsset, uint256 amount) public {
    SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), amount);

    _depositCollateral(collateralAsset, collateralAsset.balanceOf(address(this)));

    address underlyingAddress = collateralMarket.underlying();
    IERC20 underlying = IERC20(underlyingAddress);
    totalAssets += underlying.balanceOf(address(this));
  }

  function _depositCollateral(IERC20 collateralAsset, uint256 amount) internal {
    address underlyingAddress = collateralMarket.underlying();
    IERC20 underlying = IERC20(underlyingAddress);

    if (underlyingAddress != address(collateralAsset)) {
      // swap for collateral asset
      _swapForCollateral(underlying);
    }

    underlying.approve(address(collateralMarket), amount);
    require(collateralMarket.mint(amount) == 0, "deposit collateral failed");
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(collateralMarket);
    IComptroller pool = IComptroller(collateralMarket.comptroller());
    pool.enterMarkets(cTokens);
  }

  function getCurrentLeverageRatio() public view returns (uint256) {
    uint256 totalDeposits = collateralMarket.balanceOfUnderlyingHypo(address(this));
    return (totalDeposits * 1e18) / totalAssets;
  }

  function adjustLeverageRatio(uint256 ratioMantissa) public {
    require(msg.sender == positionOwner, "only owner");

    uint256 currentRatio = getCurrentLeverageRatio();
    if (currentRatio < ratioMantissa) _leverUp(ratioMantissa);
    else _leverDown();
  }

  function _leverUp(uint256 ratioMantissa) internal {
    uint256 currentRatio = getCurrentLeverageRatio();

    _borrowStable();
    //_swapForCollateral(IERC20(stableMarket.underlying()));
  }

  function _borrowStable() internal {
    // TODO don't use max, use an amount that levers up to the desired ratio
    IComptroller pool = IComptroller(stableMarket.comptroller());
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    require(stableMarket.borrow(maxBorrow) == 0, "borrow stable failed");
  }

  function _swapForCollateral(IERC20 assetToSwap) internal {
    // uniswap swap
    revert("not impl yet");
  }

  function _leverDown() internal {
    // TODO unwind position
  }
}
