// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../external/bomb/IXBomb.sol";
import "../../liquidators/XBombLiquidatorFunder.sol";
import { BaseTest } from "../config/BaseTest.t.sol";

contract XBombLiquidatorTest is BaseTest {
  // the Pancake BOMB/xBOMB pair
  address holder = 0x6aE0Fb5D98911cF5AF6A8CE0AeCE426227d41103;
  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  address bombTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3; // BOMB
  XBombLiquidatorFunder liquidator;

  function afterForkSetUp() internal override {
    liquidator = new XBombLiquidatorFunder();
  }

  function testRedeem() public debuggingOnly fork(BSC_MAINNET) {
    // make sure we're testing with at least some tokens
    uint256 balance = xbombToken.balanceOf(holder);
    assertTrue(balance > 0);

    // impersonate the holder
    vm.prank(holder);

    // fund the liquidator so it can redeem the tokens
    xbombToken.transfer(address(liquidator), balance);

    bytes memory data = abi.encode(address(xbombToken), address(xbombToken), bombTokenAddress);
    // redeem the underlying reward token
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(xbombToken)),
      balance,
      data
    );

    assertEq(address(outputToken), bombTokenAddress);
    assertEq(outputAmount, xbombToken.toREWARD(balance));
  }
}

contract XBombSwap {
  IERC20Upgradeable public testingBomb;
  IERC20Upgradeable public testingStable;

  constructor(IERC20Upgradeable _testingBomb, IERC20Upgradeable _testingStable) {
    testingBomb = _testingBomb;
    testingStable = _testingStable;
  }

  function leave(uint256 _share) external {
    testingBomb.transferFrom(msg.sender, address(this), _share);
    testingStable.transfer(msg.sender, _share);
  }

  function enter(uint256 _amount) external {
    testingStable.transferFrom(msg.sender, address(this), _amount);
    testingBomb.transfer(msg.sender, _amount);
  }

  function getExchangeRate() external view returns (uint256) {
    return 1e18;
  }

  function toREWARD(uint256 stakedAmount) external view returns (uint256) {
    return stakedAmount;
  }

  function toSTAKED(uint256 rewardAmount) external view returns (uint256) {
    return rewardAmount;
  }
}
