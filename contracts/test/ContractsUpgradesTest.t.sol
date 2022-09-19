// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import "../FuseFeeDistributor.sol";
import "../FusePoolDirectory.sol";
import { CurveLpTokenPriceOracleNoRegistry } from "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// TODO: exclude test from CI
contract ContractsUpgradesTest is BaseTest {
  // taken from ERC1967Upgrade
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function testUpgradeCurveOracle() public shouldRun(forChains(BSC_MAINNET)) {
    address contractToTest = 0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA; // CurveLpTokenPriceOracleNoRegistry proxy
    address twoBrl = 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9;
    address poolOf2Brl = 0xad51e40D8f255dba1Ad08501D6B1a6ACb7C188f3;

    // before upgrade
    CurveLpTokenPriceOracleNoRegistry oldImpl = CurveLpTokenPriceOracleNoRegistry(contractToTest);
    address poolBefore = oldImpl.poolOf(twoBrl);
    emit log_address(poolBefore);

    assertEq(poolBefore, poolOf2Brl);

    // upgrade
    {
      CurveLpTokenPriceOracleNoRegistry newImpl = new CurveLpTokenPriceOracleNoRegistry();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(contractToTest));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      //            emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    CurveLpTokenPriceOracleNoRegistry newImpl = CurveLpTokenPriceOracleNoRegistry(contractToTest);
    address poolAfter = newImpl.poolOf(twoBrl);
    emit log_address(poolAfter);

    assertEq(poolAfter, poolOf2Brl, "2brl pool does not match");
  }

  function testFusePoolDirectoryUpgrade() public shouldRun(forChains(BSC_MAINNET)) {
    address contractToTest = 0x295d7347606F4bd810C8296bb8d75D657001fcf7; // FusePoolDirectory proxy

    // before upgrade
    FusePoolDirectory oldImpl = FusePoolDirectory(contractToTest);
    FusePoolDirectory.FusePool[] memory poolsBefore = oldImpl.getAllPools();
    address ownerBefore = oldImpl.owner();
    emit log_address(ownerBefore);

    uint256 lenBefore = poolsBefore.length;
    emit log_uint(lenBefore);

    // upgrade
    {
      FusePoolDirectory newImpl = new FusePoolDirectory();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(contractToTest));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      //            emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    FusePoolDirectory newImpl = FusePoolDirectory(contractToTest);
    address ownerAfter = newImpl.owner();
    emit log_address(ownerAfter);

    FusePoolDirectory.FusePool[] memory poolsAfter = oldImpl.getAllPools();
    uint256 lenAfter = poolsAfter.length;
    emit log_uint(poolsAfter.length);

    assertEq(lenBefore, lenAfter, "pools count does not match");
    assertEq(ownerBefore, ownerAfter, "owner mismatch");
  }

  function testFuseFeeDistributorUpgrade() public shouldRun(forChains(BSC_MAINNET)) {
    address contractToTest = 0xFc1f56C58286E7215701A773b61bFf2e18A177dE; // FFD proxy
    address oldCercDelegate = 0x94C50805bC16737ead84e25Cd5Aa956bCE04BBDF;

    // before upgrade
    FuseFeeDistributor oldImpl = FuseFeeDistributor(payable(contractToTest));
    uint256 marketsCounterBefore = oldImpl.marketsCounter();
    address ownerBefore = oldImpl.owner();

    (address latestCErc20DelegateBefore, bool allowResign, bytes memory becomeImplementationData) = oldImpl
      .latestCErc20Delegate(oldCercDelegate);
    //    bool whitelistedBefore = oldImpl.cErc20DelegateWhitelist(oldCercDelegate, latestCErc20DelegateBefore, false);

    emit log_uint(marketsCounterBefore);
    emit log_address(ownerBefore);
    //    if (whitelistedBefore) emit log("whitelisted before");
    //    else emit log("should be whitelisted");

    // upgrade
    {
      FuseFeeDistributor newImpl = new FuseFeeDistributor();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(contractToTest));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      // emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    FuseFeeDistributor ffd = FuseFeeDistributor(payable(contractToTest));

    uint256 marketsCounterAfter = ffd.marketsCounter();
    address ownerAfter = ffd.owner();
    (address latestCErc20DelegateAfter, bool allowResignAfter, bytes memory becomeImplementationDataAfter) = ffd
      .latestCErc20Delegate(oldCercDelegate);
    //    bool whitelistedAfter = ffd.cErc20DelegateWhitelist(oldCercDelegate, latestCErc20DelegateAfter, false);

    emit log_uint(marketsCounterAfter);
    emit log_address(ownerAfter);
    //    if (whitelistedAfter) emit log("whitelisted After");
    //    else emit log("should be whitelisted");

    assertEq(latestCErc20DelegateBefore, latestCErc20DelegateAfter, "latest delegates do not match");
    assertEq(marketsCounterBefore, marketsCounterAfter, "markets counter does not match");
    //    assertEq(whitelistedBefore, whitelistedAfter, "whitelisted status does not match");

    assertEq(ownerBefore, ownerAfter, "owner mismatch");
  }

  function testNonAccruingFlywheelsUpgrade() public shouldRun(forChains(BSC_MAINNET)) {
    address oldFw1 = 0xC6431455AeE17a08D6409BdFB18c4bc73a4069E4;
    address oldFw2 = 0x851Cc0037B6923e60dC81Fa79Ac0799cC983492c;

    FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));

    address expectedImplPrior = 0xe1b488B01cA2143A08A800a92FEA38d661fC31D4;
    Comptroller jarvisPool = Comptroller(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);
    address currentImpl = jarvisPool.comptrollerImplementation();
    assertEq(currentImpl, expectedImplPrior, "impl prior does not match, this test can be removed");

    vm.startPrank(ffd.owner());
    // deploy the new comptroller impl
    Comptroller newImpl = new Comptroller(payable(address(ffd)));

    // upgrade the comptroller
    ffd._editComptrollerImplementationWhitelist(
      asArray(currentImpl),
      asArray(address(newImpl)),
      asArray(true)
    );

    Unitroller proxy = Unitroller(payable(address(jarvisPool)));
    proxy._setPendingImplementation(address(newImpl));
    newImpl._become(proxy);

    address[] memory currentFlywheels = jarvisPool.getRewardsDistributors();

    // add the two flywheels to the non-accruing
    {
      bool replaced1 = jarvisPool.addNonAccruingFlywheel(oldFw1);
      assertTrue(replaced1, "didn't replace the first flyhweel");
      bool replaced2 = jarvisPool.addNonAccruingFlywheel(oldFw2);
      assertTrue(replaced2, "didn't replace the second flyhweel");
    }

    address[] memory updatedFlywheels = jarvisPool.getRewardsDistributors();
    assertEq(currentFlywheels.length, updatedFlywheels.length, "flywheels arrays length don't match");

    // attempt to add the two flywheels to the non-accruing, should fail
    {
      vm.expectRevert("flywheel already added to the non-accruing");
      bool replaced1 = jarvisPool.addNonAccruingFlywheel(oldFw1);
      vm.expectRevert("flywheel already added to the non-accruing");
      bool replaced2 = jarvisPool.addNonAccruingFlywheel(oldFw2);
    }

    vm.stopPrank();
  }
}
