// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import "../compound/CTokenInterfaces.sol";

import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";
import { MockERC4626 } from "../midas/strategies/MockERC4626.sol";
import { MockERC4626Dynamic } from "../midas/strategies/MockERC4626Dynamic.sol";
import { CTokenFirstExtension, DiamondExtension } from "../compound/CTokenFirstExtension.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";

contract DeployMarketsTest is Test {
  MockERC20 underlyingToken;
  MockERC20 rewardToken;

  WhitePaperInterestRateModel interestModel;
  Comptroller comptroller;

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
    underlyingToken.mint(address(this), 100e18);

    MockPriceOracle priceOracle = new MockPriceOracle(10);
    emptyAddresses.push(address(0));
    Comptroller tempComptroller = new Comptroller(payable(address(fuseAdmin)));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
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
    comptroller = Comptroller(payable(comptrollerAddress));
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
        ComptrollerInterface(address(comptroller)),
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    CErc20Delegate cToken = CErc20Delegate(address(allMarkets[allMarkets.length - 1]));
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
        ComptrollerInterface(address(comptroller)),
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

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
    MidasFlywheelCore flywheel = new MidasFlywheelCore();
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
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
        ComptrollerInterface(address(comptroller)),
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
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
    CTokenExtensionInterface(address(cToken)).accrueInterest();

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
        ComptrollerInterface(address(comptroller)),
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

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
        ComptrollerInterface(address(comptroller)),
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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(pluginA), "!plugin == erc4626");

    address pluginImplBefore = address(cToken.plugin());
    address implBefore = cToken.implementation();

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
    CTokenExtensionInterface(address(cToken)).accrueInterest();

    address pluginImplAfter = address(cToken.plugin());
    address implAfter = cToken.implementation();

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
}
