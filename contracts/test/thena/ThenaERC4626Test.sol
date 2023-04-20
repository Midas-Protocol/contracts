// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ThenaLpERC4626 } from "../../midas/strategies/ThenaLpERC4626.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { MidasFlywheel } from "../../midas/strategies/flywheel/MidasFlywheel.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { ERC20 as SolERC20 } from "solmate/tokens/ERC20.sol";
import { ERC20Upgradeable as ERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ThenaERC4626Test is AbstractERC4626Test {
  ERC20 public thenaToken = ERC20(0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11);

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("Thena-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));
    testPreFix = _testPreFix;

    MidasFlywheel flywheel;
    ThenaLpERC4626 thenaErc4626;

    (address _asset, address _lpTokenWhale) = abi.decode(data, (address, address));

    address dpa = address(929292);
    address marketAddress = address(123);
    deal(_asset, address(this), 100e18);
//    vm.prank(lpTokenWhale);
//    lpHayBusdToken.transfer(address(this), 1e22);

    {
      ThenaLpERC4626 impl = new ThenaLpERC4626();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), dpa, "");
      thenaErc4626 = ThenaLpERC4626(address(proxy));
    }

    {
      MidasFlywheel impl = new MidasFlywheel();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), dpa, "");
      flywheel = MidasFlywheel(address(proxy));
    }
    flywheel.initialize(
      SolERC20(address(thenaToken)),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this)
    );

    FuseFlywheelDynamicRewards rewardsContract = new FuseFlywheelDynamicRewards(
      FlywheelCore(address(flywheel)),
      1 days
    );
    flywheel.setFlywheelRewards(rewardsContract);

    thenaErc4626.initialize(ERC20(_asset), marketAddress, flywheel);
    plugin = thenaErc4626;
  }

  function getDepositShares() public view override returns (uint256) {
    return plugin.totalAssets(); //ThenaLpERC4626(address(plugin)).gauge().balanceOf(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return ThenaLpERC4626(address(plugin)).gauge().balanceOf(address(plugin));
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }
}