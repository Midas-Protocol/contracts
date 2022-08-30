// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { AlpacaERC4626, IAlpacaVault } from "../compound/strategies/AlpacaERC4626.sol";
import { IW_NATIVE } from "../utils/IW_NATIVE.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract BNBE2eTest is WithPool, BaseTest {
  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      ERC20Upgradeable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
    );
  }

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(0xF8aaE8D5dd1d7697a4eC6F561737e68a2ab8539e);
    underlyingToken.transferFrom(0xF8aaE8D5dd1d7697a4eC6F561737e68a2ab8539e, address(this), 10e18);
    uint256 balance = underlyingToken.balanceOf(address(this));
    setUpPool("bsc-test", false, 0.1e18, 1.1e18);
  }

  function testDeployCErc20Delegate() public shouldRun(forChains(BSC_MAINNET)) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);

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

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    assertEq(underlyingToken.balanceOf(address(this)), 1000);
  }

  function testGetPoolAssetsData() public shouldRun(forChains(BSC_MAINNET)) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20Delegate cToken = CErc20Delegate(address(allMarkets[allMarkets.length - 1]));
    assertEq(cToken.name(), "cUnderlyingToken");
    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    cToken.mint(10e18);

    // address comptroller1 = 0x31d76A64Bc8BbEffb601fac5884372DEF910F044;
    // address comptroller2 = 0x11355CF65a9B76e5Ac4C289362fD7c22eE93E762;

    FusePoolLens.FusePoolAsset[] memory assets = poolLens.getPoolAssetsWithData(IComptroller(address(comptroller)));

    // FusePoolLens.FusePoolAsset[] memory assets1 = poolLens
    //     .getPoolAssetsWithData(IComptroller(comptroller1));

    assertEq(assets[0].supplyBalance, 10e18);
  }

  function testDeployCErc20PluginDelegate() public shouldRun(forChains(BSC_MAINNET)) {
    AlpacaERC4626 erc4626 = new AlpacaERC4626();
    erc4626.initialize(
      ERC20Upgradeable(address(underlyingToken)),
      IAlpacaVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063),
      IW_NATIVE(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
    );

    vm.roll(1);
    deployCErc20PluginDelegate(address(erc4626), 0.9e18);

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(erc4626));

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    cToken.mint(1e18);
    assertEq(cToken.totalSupply(), 1e18 * 5);
    uint256 balance = erc4626.balanceOf(address(cToken));
    assertEq(balance, 1e18);
    vm.roll(1);

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    balance = erc4626.balanceOf(address(cToken));
    uint256 maxWithdraw = erc4626.previewWithdraw(1000);
    assertEq(balance, 1e18 - maxWithdraw);
    assertEq(underlyingToken.balanceOf(address(this)), 10e18 - 1e18 + maxWithdraw);
  }

  function testDeployCErc20PluginRewardsDelegate() public shouldRun(forChains(BSC_MAINNET)) {
    MockERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
    FuseFlywheelDynamicRewards rewards;
    FuseFlywheelCore flywheel = new FuseFlywheelCore(
      ERC20(address(underlyingToken)),
      IFlywheelRewards(address(2)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    rewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(rewards);

    AlpacaERC4626 erc4626 = new AlpacaERC4626();
    erc4626.initialize(
      ERC20Upgradeable(address(underlyingToken)),
      IAlpacaVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063),
      IW_NATIVE(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
    );

    ERC20 marketKey = ERC20(address(erc4626));
    flywheel.addStrategyForRewards(marketKey);

    vm.roll(1);
    deployCErc20PluginRewardsDelegate(address(erc4626), 0.9e18);

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(address(allMarkets[allMarkets.length - 1]));

    assertEq(address(cToken.plugin()), address(erc4626));
    assertEq(underlyingToken.allowance(address(cToken), address(erc4626)), type(uint256).max);
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
    assertEq(erc4626.balanceOf(address(cToken)), 10000000);
    vm.roll(1);

    cToken.borrow(1000);
    uint256 maxWithdraw = erc4626.previewWithdraw(1000);
    assertEq(cToken.totalBorrows(), 1000);
    assertEq(erc4626.balanceOf(address(cToken)), 10000000 - maxWithdraw);
    assertEq(underlyingToken.balanceOf(address(this)), 10e18 - 10000000 + maxWithdraw);
  }
}
