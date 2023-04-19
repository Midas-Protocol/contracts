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

  constructor(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    address _positionOwner
  ) {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets pools differ");

    positionOwner = _positionOwner;
    collateralMarket = _collateralMarket;
    stableMarket = _stableMarket;
  }

  function leverUp(uint256 amount, IERC20 collateralAsset) public {
    require(msg.sender == positionOwner, "only owner");

    address underlyingAddress = collateralMarket.underlying();
    IERC20 underlying = IERC20(underlyingAddress);

    SafeERC20.safeTransferFrom(underlying, msg.sender, address(this), amount);

    if (underlyingAddress != address(collateralAsset)) {
      // swap for collateral asset
      _swapForCollateral(underlying);
    }

    //_depositCollateral(amount);
    underlying.approve(address(collateralMarket), amount);
    require(collateralMarket.mint(amount) == 0, "deposit collateral failed");
    IComptroller pool = IComptroller(collateralMarket.comptroller());
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(collateralMarket);
    pool.enterMarkets(cTokens);

    _borrowStable();
    //_swapForCollateral(IERC20(stableMarket.underlying()));
  }

  function _depositCollateral(uint256 amount) internal {}

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

  function delever() public {
    require(msg.sender == positionOwner, "only owner");

    // TODO unwind position
  }
}
