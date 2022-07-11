// SPDX-License-Identifier: UNLICENSED
/* solhint-disable */
pragma solidity >=0.4.23;

import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { FuseFlywheelLensRouter, CToken as ICToken } from "fuse-flywheel/FuseFlywheelLensRouter.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";

import { CErc20 } from "../compound/CErc20.sol";
import { CToken } from "../compound/CToken.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { RewardsDistributorDelegate } from "../compound/RewardsDistributorDelegate.sol";
import { RewardsDistributorDelegator } from "../compound/RewardsDistributorDelegator.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";
import { MockERC4626 } from "../compound/strategies/MockERC4626.sol";
import { MockERC4626Dynamic } from "../compound/strategies/MockERC4626Dynamic.sol";
import "./config/BaseTest.t.sol";

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

  CErc20 cErc20;
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  FuseFlywheelCore flywheel;
  FuseFlywheelDynamicRewardsPlugin rewards;

  ERC20 marketKey;

  address user = address(this);

  uint256 depositAmount = 1 ether;

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
  FuseFlywheelCore[] flywheelsToClaim;

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
    cErc20PluginDelegate = new CErc20PluginDelegate();
    cErc20PluginRewardsDelegate = new CErc20PluginRewardsDelegate();
    cErc20Delegate = new CErc20Delegate();

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
    Comptroller tempComptroller = new Comptroller(payable(fuseAdmin));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    (uint256 index, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      abi.encode(payable(address(fuseAdmin))),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(comptrollerAddress);
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

    CToken[] memory allMarkets = comptroller.getAllMarkets();
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
    vm.roll(1);

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10e18 + 1000);
  }

  function testDeployCErc20PluginDelegate() public {
    mockERC4626 = new MockERC4626(ERC20(address(underlyingToken)));

    address[] memory plugins = new address[](1);
    plugins[0] = address(mockERC4626);
    bool[] memory arrayOfTrue = new bool[](1);
    arrayOfTrue[0] = true;
    fuseAdmin._editPluginImplementationWhitelist(plugins, plugins, arrayOfTrue);

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
        abi.encode(address(mockERC4626)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    CToken[] memory allMarkets = comptroller.getAllMarkets();
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
    vm.roll(1);

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    assertEq(underlyingToken.balanceOf(address(mockERC4626)), 10e18 - 1000);
    assertEq(mockERC4626.balanceOf(address(cToken)), 10e18 - 1000);
    assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10e18 + 1000);
  }

  function testDeployCErc20PluginRewardsDelegate() public {
    flywheel = new FuseFlywheelCore(
      underlyingToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    rewards = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
    flywheel.setFlywheelRewards(rewards);

    mockERC4626Dynamic = new MockERC4626Dynamic(ERC20(address(underlyingToken)), FlywheelCore(address(flywheel)));

    address[] memory plugins = new address[](1);
    plugins[0] = address(mockERC4626Dynamic);
    bool[] memory arrayOfTrue = new bool[](1);
    arrayOfTrue[0] = true;
    fuseAdmin._editPluginImplementationWhitelist(plugins, plugins, arrayOfTrue);

    marketKey = ERC20(address(mockERC4626Dynamic));
    flywheel.addStrategyForRewards(marketKey);

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
        abi.encode(address(mockERC4626Dynamic), address(flywheel), address(underlyingToken)),
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(address(allMarkets[allMarkets.length - 1]));

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
    vm.roll(1);

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    assertEq(underlyingToken.balanceOf(address(mockERC4626Dynamic)), 10000000 - 1000);
    assertEq(mockERC4626Dynamic.balanceOf(address(cToken)), 10000000 - 1000);
    assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10000000 + 1000);
  }
}

contract CErc20DelegateTest is BaseTest {
  Comptroller comptroller;

  CErc20Delegate cErc20Delegate;
  CErc20PluginDelegate cErc20PluginDelegate;
  CErc20PluginRewardsDelegate cErc20PluginRewardsDelegate;

  CErc20 cErc20;
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  address[] implementationsSet;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    // TODO set these in the addresses provider
    fusePoolDirectory = FusePoolDirectory(0x295d7347606F4bd810C8296bb8d75D657001fcf7);
    fuseAdmin = FuseFeeDistributor(payable(0xFc1f56C58286E7215701A773b61bFf2e18A177dE));
  }

  function testMarketImplementations() public shouldRun(forChains(BSC_MAINNET)) {
    FusePoolDirectory.FusePool[] memory pools = fusePoolDirectory.getAllPools();

    for (uint8 i = 0; i < pools.length; i++) {
      Comptroller comptroller = Comptroller(pools[i].comptroller);
      CToken[] memory markets = comptroller.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20Delegate delegate = CErc20Delegate(address(markets[j]));
        address implementation = delegate.implementation();

        //        emit log_address(implementation);
        bool added = false;
        for (uint8 k = 0; k < implementationsSet.length; k++) {
          if (implementationsSet[k] == implementation) {
            added = true;
          }
        }

        if (!added) implementationsSet.push(implementation);
      }
    }

    emit log("listing the set");
    for (uint8 k = 0; k < implementationsSet.length; k++) {
      (address latestCErc20Delegate, bool allowResign, bytes memory becomeImplementationData) = fuseAdmin
        .latestCErc20Delegate(implementationsSet[k]);

      bool whitelisted = fuseAdmin.cErc20DelegateWhitelist(implementationsSet[k], latestCErc20Delegate, allowResign);
      emit log_address(implementationsSet[k]);
      //      if (whitelisted) emit log("whitelisted");

      assertTrue(
        whitelisted || implementationsSet[k] == latestCErc20Delegate,
        "no whitelisted implementation for old implementation"
      );
    }
  }
}
