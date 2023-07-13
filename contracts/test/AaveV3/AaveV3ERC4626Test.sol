// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { AaveV3ERC4626, IAaveV3Pool } from "../../ionic/strategies/AaveV3ERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { IonicFlywheelCore } from "../../ionic/strategies/flywheel/IonicFlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract AaveV3ERC4626Test is AbstractERC4626Test {
  IAaveV3Pool pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
  address marketAddress;
  ERC20 marketKey;

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("AaveV3-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    address _asset = abi.decode(data, (address));

    AaveV3ERC4626 poolERC4626 = new AaveV3ERC4626();
    poolERC4626.initialize(underlyingToken, pool);
    plugin = poolERC4626;

    initialStrategyBalance = getStrategyBalance();
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(pool), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(pool));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return plugin.totalAssets();
  }

  function getStrategyBalance() public view override returns (uint256) {
    address aTokenAddress = pool.getReserveData(address(underlyingToken)).aTokenAddress;
    return underlyingToken.balanceOf(aTokenAddress);
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(
      address(AaveV3ERC4626(address(plugin)).pool()),
      address(pool),
      string(abi.encodePacked("!pool ", testPreFix))
    );
  }
}
