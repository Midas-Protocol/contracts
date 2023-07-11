// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ICErc20, ICErc20Plugin } from "../compound/CTokenInterfaces.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { CTokenFirstExtension, DiamondExtension } from "../compound/CTokenFirstExtension.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { AuthoritiesRegistry } from "../midas/AuthoritiesRegistry.sol";
import { PoolRolesAuthority } from "../midas/PoolRolesAuthority.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";

import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";
import { MockERC4626 } from "../midas/strategies/MockERC4626.sol";
import { MockERC4626Dynamic } from "../midas/strategies/MockERC4626Dynamic.sol";

contract DeployMarketsTest is Test {
  MockERC20 underlyingToken;
  MockERC20 rewardToken;

  WhitePaperInterestRateModel interestModel;
  IComptroller comptroller;

  CErc20Delegate cErc20Delegate;
  CErc20PluginDelegate cErc20PluginDelegate;
  CErc20PluginRewardsDelegate cErc20PluginRewardsDelegate;

  MockERC4626 mockERC4626;
  MockERC4626Dynamic mockERC4626Dynamic;

  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  FuseFlywheelDynamicRewardsPlugin rewards;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  address[] newImplementation;
  bool[] t;
  bool[] f;
  address[] oldCErC20Implementations;
  address[] newCErc20Implementations;
  MidasFlywheelCore[] flywheelsToClaim;

  function setUpBaseContracts() public {
    underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    rewardToken = new MockERC20("RewardToken", "RT", 18);
    interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1e16);
    fusePoolDirectory = new FusePoolDirectory();
    fusePoolDirectory.initialize(false, emptyAddresses);
  }

  function setUpWhiteList() public {
    cErc20Delegate = new CErc20Delegate();
    cErc20PluginDelegate = new CErc20PluginDelegate();
    cErc20PluginRewardsDelegate = new CErc20PluginRewardsDelegate();

    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = new CTokenFirstExtension();
    fuseAdmin._setCErc20DelegateExtensions(address(cErc20Delegate), cErc20DelegateExtensions);
    fuseAdmin._setCErc20DelegateExtensions(address(cErc20PluginDelegate), cErc20DelegateExtensions);
    fuseAdmin._setCErc20DelegateExtensions(address(cErc20PluginRewardsDelegate), cErc20DelegateExtensions);

    for (uint256 i = 0; i < 7; i++) {
      t.push(true);
      f.push(false);
    }

    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(cErc20Delegate));
    oldCErC20Implementations.push(address(cErc20Delegate));
    oldCErC20Implementations.push(address(cErc20PluginDelegate));
    oldCErC20Implementations.push(address(cErc20PluginRewardsDelegate));

    newCErc20Implementations.push(address(cErc20Delegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));

    fuseAdmin._editCErc20DelegateWhitelist(oldCErC20Implementations, newCErc20Implementations, f, t);
  }

  function setUpPool() public {
    underlyingToken.mint(address(this), 100e36);

    MockPriceOracle priceOracle = new MockPriceOracle(10);
    emptyAddresses.push(address(0));
    Comptroller tempComptroller = new Comptroller(payable(address(fuseAdmin)));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    DiamondExtension[] memory extensions = new DiamondExtension[](1);
    extensions[0] = new ComptrollerFirstExtension();
    fuseAdmin._setComptrollerExtensions(address(tempComptroller), extensions);
    (, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      abi.encode(payable(address(fuseAdmin))),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = IComptroller(comptrollerAddress);

    AuthoritiesRegistry impl = new AuthoritiesRegistry();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(1), "");
    AuthoritiesRegistry newAr = AuthoritiesRegistry(address(proxy));
    newAr.initialize(address(321));
    fuseAdmin.reinitialize(newAr);
    PoolRolesAuthority poolAuth = newAr.createPoolAuthority(comptrollerAddress);
    poolAuth.setUserRole(address(this), poolAuth.BORROWER_ROLE(), true);
  }

  function setUp() public {
    setUpBaseContracts();
    setUpPool();
    setUpWhiteList();
    vm.roll(1);
  }

  function testDeployCErc20Delegate() public {
    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20 cToken = allMarkets[allMarkets.length - 1];
    assertEq(cToken.name(), "cUnderlyingToken");
    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);
    cToken.mint(10e18);
    assertEq(cToken.totalSupply(), 10e18 * 5);
    assertEq(underlyingToken.balanceOf(address(cToken)), 10e18);
  }

  function testDeployCErc20PluginDelegate() public {
    mockERC4626 = new MockERC4626(ERC20(address(underlyingToken)));

    whitelistPlugin(address(mockERC4626), address(mockERC4626));

    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginDelegate),
        abi.encode(address(mockERC4626)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20Plugin cToken = ICErc20Plugin(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(mockERC4626), "!plugin == erc4626");

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    cToken.mint(10e18);
    assertEq(cToken.totalSupply(), 10e18 * 5);
    assertEq(mockERC4626.balanceOf(address(cToken)), 10e18);
    assertEq(underlyingToken.balanceOf(address(mockERC4626)), 10e18);
  }

  function testDeployCErc20PluginRewardsDelegate() public {
    MidasFlywheelCore impl = new MidasFlywheelCore();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(1), "");
    MidasFlywheelCore flywheel = MidasFlywheelCore(address(proxy));
    flywheel.initialize(underlyingToken, IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), address(this));
    FlywheelCore asFlywheelCore = FlywheelCore(address(flywheel));
    rewards = new FuseFlywheelDynamicRewardsPlugin(asFlywheelCore, 1);
    flywheel.setFlywheelRewards(rewards);

    mockERC4626Dynamic = new MockERC4626Dynamic(ERC20(address(underlyingToken)), asFlywheelCore);

    whitelistPlugin(address(mockERC4626Dynamic), address(mockERC4626Dynamic));

    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginRewardsDelegate),
        abi.encode(address(mockERC4626Dynamic), address(flywheel), address(underlyingToken)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(address(allMarkets[allMarkets.length - 1]));

    flywheel.addStrategyForRewards(ERC20(address(cToken)));

    assertEq(address(cToken.plugin()), address(mockERC4626Dynamic), "!plugin == erc4626");
    assertEq(underlyingToken.allowance(address(cToken), address(mockERC4626Dynamic)), type(uint256).max);
    assertEq(underlyingToken.allowance(address(cToken), address(flywheel)), 0);

    cToken.approve(address(rewardToken), address(flywheel));
    assertEq(rewardToken.allowance(address(cToken), address(flywheel)), type(uint256).max);

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    cToken.mint(10000000);
    assertEq(cToken.totalSupply(), 10000000 * 5);
    assertEq(mockERC4626Dynamic.balanceOf(address(cToken)), 10000000);
    assertEq(underlyingToken.balanceOf(address(mockERC4626Dynamic)), 10000000);
  }

  function testAutImplementationCErc20Delegate() public {
    mockERC4626 = new MockERC4626(ERC20(address(underlyingToken)));

    whitelistPlugin(address(mockERC4626), address(mockERC4626));

    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginDelegate),
        abi.encode(address(mockERC4626)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(mockERC4626), "!plugin == erc4626");

    address implBefore = cToken.implementation();
    // just testing to replace the plugin delegate with the plugin rewards delegate
    whitelistCErc20Delegate(address(cErc20PluginDelegate), address(cErc20PluginRewardsDelegate));
    fuseAdmin._setLatestCErc20Delegate(
      address(cErc20PluginDelegate),
      address(cErc20PluginRewardsDelegate),
      false,
      abi.encode(address(0)) // should trigger use of latest implementation
    );

    // trigger the auto implementations
    vm.prank(address(7));
    ICErc20(address(cToken)).accrueInterest();

    address implAfter = cToken.implementation();

    assertEq(implBefore, address(cErc20PluginDelegate), "the old impl should be the plugin delegate");
    assertEq(implAfter, address(cErc20PluginRewardsDelegate), "the new impl should be the plugin rewards delegate");
  }

  function testAutImplementationPlugin() public {
    MockERC4626 pluginA = new MockERC4626(ERC20(address(underlyingToken)));
    MockERC4626 pluginB = new MockERC4626(ERC20(address(underlyingToken)));

    whitelistPlugin(address(pluginA), address(pluginA));

    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginDelegate),
        abi.encode(address(pluginA)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20Plugin cToken = ICErc20Plugin(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(pluginA), "!plugin == erc4626");

    address pluginImplBefore = address(cToken.plugin());
    whitelistPlugin(address(pluginA), address(pluginB));
    fuseAdmin._setLatestPluginImplementation(address(pluginA), address(pluginB));
    fuseAdmin._upgradePluginToLatestImplementation(address(cToken));
    address pluginImplAfter = address(cToken.plugin());

    assertEq(pluginImplBefore, address(pluginA), "the old impl should be the A plugin");
    assertEq(pluginImplAfter, address(pluginB), "the new impl should be the B plugin");
  }

  function testAutImplementationCErc20PluginDelegate() public {
    MockERC4626 pluginA = new MockERC4626(ERC20(address(underlyingToken)));
    MockERC4626 pluginB = new MockERC4626(ERC20(address(underlyingToken)));

    whitelistPlugin(address(pluginA), address(pluginA));

    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginDelegate),
        abi.encode(address(pluginA)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20Plugin cToken = ICErc20Plugin(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(pluginA), "!plugin == erc4626");

    address pluginImplBefore = address(cToken.plugin());
    address implBefore = CErc20PluginDelegate(address(cToken)).implementation();

    // just testing to replace the plugin delegate with the plugin rewards delegate
    whitelistCErc20Delegate(address(cErc20PluginDelegate), address(cErc20PluginRewardsDelegate));
    fuseAdmin._setLatestCErc20Delegate(
      address(cErc20PluginDelegate),
      address(cErc20PluginRewardsDelegate),
      false,
      abi.encode(address(0)) // should trigger use of latest implementation
    );
    whitelistPlugin(address(pluginA), address(pluginB));
    fuseAdmin._setLatestPluginImplementation(address(pluginA), address(pluginB));

    // trigger the auto implementations from a non-admin address
    vm.prank(address(7));
    cToken.accrueInterest();

    address pluginImplAfter = address(cToken.plugin());
    address implAfter = CErc20PluginDelegate(address(cToken)).implementation();

    assertEq(pluginImplBefore, address(pluginA), "the old impl should be the A plugin");
    assertEq(pluginImplAfter, address(pluginB), "the new impl should be the B plugin");
    assertEq(implBefore, address(cErc20PluginDelegate), "the old impl should be the plugin delegate");
    assertEq(implAfter, address(cErc20PluginRewardsDelegate), "the new impl should be the plugin rewards delegate");
  }

  // TODO refactor DeployMarketsTest to extend WithPool
  function whitelistPlugin(address oldImpl, address newImpl) public {
    address[] memory _oldCErC20Implementations = new address[](1);
    address[] memory _newCErc20Implementations = new address[](1);
    bool[] memory arrayOfTrue = new bool[](1);

    _oldCErC20Implementations[0] = address(oldImpl);
    _newCErc20Implementations[0] = address(newImpl);
    arrayOfTrue[0] = true;

    fuseAdmin._editPluginImplementationWhitelist(_oldCErC20Implementations, _newCErc20Implementations, arrayOfTrue);
  }

  function whitelistCErc20Delegate(address oldImpl, address newImpl) public {
    bool[] memory arrayOfTrue = new bool[](1);
    bool[] memory arrayOfFalse = new bool[](1);
    address[] memory _oldCErC20Implementations = new address[](1);
    address[] memory _newCErc20Implementations = new address[](1);

    arrayOfTrue[0] = true;
    arrayOfFalse[0] = false;
    _oldCErC20Implementations[0] = address(oldImpl);
    _newCErc20Implementations[0] = address(newImpl);

    fuseAdmin._editCErc20DelegateWhitelist(
      _oldCErC20Implementations,
      _newCErc20Implementations,
      arrayOfFalse,
      arrayOfTrue
    );
  }

  function testInflateExchangeRate() public {
    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20 cToken = allMarkets[allMarkets.length - 1];
    assertEq(cToken.name(), "cUnderlyingToken");
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    // mint just 2 wei
    underlyingToken.approve(address(cToken), 1e36);
    cToken.mint(2);
    assertEq(cToken.totalSupply(), 10);
    assertEq(underlyingToken.balanceOf(address(cToken)), 2, "!total supply 2");

    uint256 exchRateBefore = cToken.exchangeRateCurrent();
    emit log_named_uint("exch rate", exchRateBefore);
    assertEq(exchRateBefore, 2e17, "!default exch rate");

    // donate
    underlyingToken.transfer(address(cToken), 1e36);

    uint256 exchRateAfter = cToken.exchangeRateCurrent();
    emit log_named_uint("exch rate after", exchRateAfter);
    assertGt(exchRateAfter, 1e30, "!inflated exch rate");

    // the market should own 1e36 + 2 underlying assets
    assertEq(underlyingToken.balanceOf(address(cToken)), 1e36 + 2, "!total underlying");

    // 50% + 1
    uint256 errCode = cToken.redeemUnderlying(0.5e36 + 2);
    assertEq(errCode, 0, "!redeem underlying");

    assertEq(cToken.totalSupply(), 0, "!should have redeemed all ctokens for 50% + 1 of the underlying");
  }

  function testSupplyCapInflatedExchangeRate() public {
    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        comptroller,
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20 cToken = allMarkets[allMarkets.length - 1];
    assertEq(cToken.name(), "cUnderlyingToken");
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    // mint 1e18
    underlyingToken.approve(address(cToken), 1e18);
    cToken.mint(1e18);
    assertEq(cToken.totalSupply(), 5 * 1e18, "!total supply 5");
    assertEq(underlyingToken.balanceOf(address(cToken)), 1e18, "!market underlying balance 1");

    (, uint256 liqBefore, uint256 sfBefore) = comptroller.getAccountLiquidity(address(this));

    uint256[] memory caps = new uint256[](1);
    caps[0] = 25e18;
    ICErc20[] memory marketArray = new ICErc20[](1);
    marketArray[0] = cToken;
    vm.prank(comptroller.admin());
    comptroller._setMarketSupplyCaps(marketArray, caps);

    // donate 100e18
    underlyingToken.transfer(address(cToken), 100e18);
    assertEq(underlyingToken.balanceOf(address(cToken)), 101e18, "!market balance 101");
    assertEq(cToken.balanceOfUnderlying(address(this)), 101e18, "!user balance 101");

    (, uint256 liqAfter, uint256 sfAfter) = comptroller.getAccountLiquidity(address(this));
    emit log_named_uint("liqBefore", liqBefore);
    emit log_named_uint("liqAfter", liqAfter);

    assertEq(liqAfter / liqBefore, 25, "liquidity should increase only 25x");
  }
}
