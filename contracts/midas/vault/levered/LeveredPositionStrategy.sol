// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ICErc20 } from "../../../external/compound/ICErc20.sol";
import { IComptroller } from "../../../external/compound/IComptroller.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LeveredPositionStrategy {
  using SafeERC20 for IERC20;

  ICErc20 public collateralMarket;
  ICErc20 public stableMarket;
  IComptroller public pool;

  constructor(ICErc20 _collateralMarket, ICErc20 _stableMarket) {
    collateralMarket = _collateralMarket;
    stableMarket = _stableMarket;

    address collateralPool = collateralMarket.comptroller();
    address stablePool = stableMarket.comptroller();
    require(stablePool == collateralPool, "markets pools differ");
    pool = IComptroller(collateralPool);
  }

  function leverUp(uint256 amount, IERC20 collateralAsset) public {
    address caller = msg.sender;

    address underlyingAddress = collateralMarket.underlying();
    IERC20 underlying = IERC20(underlyingAddress);

    SafeERC20.safeTransferFrom(underlying, caller, address(this), amount);

    if (underlyingAddress != address(collateralAsset)) {
      // swap for collateral asset
      _swapForCollateral(underlying);
    }

    _depositCollateral(amount);

    _borrowStable();
    _swapForCollateral(IERC20(stableMarket.underlying()));
  }

  function _depositCollateral(uint256 amount) internal {
    require(collateralMarket.mint(amount) == 0, "deposit collateral failed");
  }

  function _borrowStable() internal {
    // TODO don't use max, use an amount that levers up to the desired ratio
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    require(stableMarket.borrow(maxBorrow) == 0, "borrow stable failed");
  }

  function _swapForCollateral(IERC20 assetToSwap) internal {
    // uniswap swap
  }
}
