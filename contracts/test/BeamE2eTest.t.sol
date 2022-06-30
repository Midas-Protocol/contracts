// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";
import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import { UniswapLpTokenLiquidator } from "../liquidators/UniswapLpTokenLiquidator.sol";

contract MockBeam is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract BeamE2eTest is WithPool, BaseTest {
  using stdStorage for StdStorage;
  StdStorage internal stdstore;
  
  address wToken = 0xAcc15dC74880C9944775448304B263D191c6077F;
  address uniswapRouter = 0x96b244391D98B62D19aE89b1A4dCcf0fc56970C7;

  constructor()
    WithPool(
      MasterPriceOracle(0x14C15B9ec83ED79f23BF71D51741f58b69ff1494),
      MockERC20(0x99588867e817023162F4d4829995299054a5fC57)
    )
  {}

  function setUp() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    underlyingToken.transfer(address(this), 100e18);
    setUpPool("beam-test", false, 0.1e18, 1.1e18);
  }

  function testDeployCErc20Delegate() public shouldRun(forChains(MOONBEAM_MAINNET)) {
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
    assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10e18 + 1000);
  }

  function testGetPoolAssetsData() public shouldRun(forChains(MOONBEAM_MAINNET)) {
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

    FusePoolLens.FusePoolAsset[] memory assets = poolLens.getPoolAssetsWithData(IComptroller(address(comptroller)));

    assertEq(assets[0].supplyBalance, 10e18);
  }

  function testBeamCErc20Liquidation() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    // vm.roll(1);
    MockERC4626 erc4626 = new MockERC4626(ERC20(address(underlyingToken)));
    MockBeam beam = MockBeam(wToken);

    deployCErc20PluginDelegate(erc4626, 0.9e18);
    deployCErc20Delegate(address(beam), "BNB", "bnb", 0.9e18);

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[0]));

    cToken._setImplementationSafe(address(cErc20PluginDelegate), false, abi.encode(address(erc4626)));

    CErc20Delegate cBeamToken = CErc20Delegate(address(allMarkets[1]));

    address[] memory cTokens = new address[](2);
    cTokens[0] = address(cToken);
    cTokens[1] = address(cBeamToken);
    comptroller.enterMarkets(cTokens);

    // setting up liquidator
    liquidator = new FuseSafeLiquidator();
    liquidator.initialize(
      0xAcc15dC74880C9944775448304B263D191c6077F,
      uniswapRouter,
      0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b,
      0xcd3B51D98478D53F4515A306bE565c6EebeF1D58,
      "0xe31da4209ffcce713230a74b5287fa8ec84797c9e77e1f7cfeccea015cdc97ea"
    );
    address accountOne = address(1);
    address accountTwo = address(2);

    FusePoolLensSecondary secondary = new FusePoolLensSecondary();
    secondary.initialize(fusePoolDirectory);

    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    underlyingToken.transfer(accountTwo, 1000e18);
    // Account One Supply
    vm.deal(accountOne, 1000000000000e18);
    vm.startPrank(accountOne);
    beam.deposit{ value: 1000000000000e18 }();
    vm.stopPrank();

    // Account One Supply
    vm.startPrank(accountOne);
    beam.approve(address(cBeamToken), 1e36);
    cBeamToken.mint(1000e18);
    vm.stopPrank();

    // Account Two Supply
    vm.startPrank(accountTwo);
    underlyingToken.approve(address(cToken), 1e36);
    cToken.mint(1000e18);
    vm.stopPrank();
    assertEq(cToken.totalSupply(), 1000e18 * 5);
    assertEq(cBeamToken.totalSupply(), 1000e18 * 5);

    // Account One Borrow
    vm.startPrank(accountOne);
    underlyingToken.approve(address(cToken), 1e36);
    cToken.borrow(10);
    vm.stopPrank();
    assertEq(cToken.totalBorrows(), 10);
    {
      uint256 price1 = priceOracle.getUnderlyingPrice(ICToken(address(cToken)));

      vm.mockCall(
        0x14C15B9ec83ED79f23BF71D51741f58b69ff1494,
        abi.encodeWithSelector(priceOracle.getUnderlyingPrice.selector, ICToken(address(cToken))),
        abi.encode(price1 * 10)
      );
    }

    {
      IRedemptionStrategy[] memory strategies = new IRedemptionStrategy[](1);
      UniswapLpTokenLiquidator lpLiquidator = new UniswapLpTokenLiquidator();
      strategies[0] = lpLiquidator;
      address[] memory swapToken0Path = new address[](2);
      swapToken0Path[0] = IUniswapV2Pair(address(underlyingToken)).token0();
      swapToken0Path[1] = IUniswapV2Pair(address(underlyingToken)).token1();
      address[] memory swapToken1Path = new address[](2);
      swapToken0Path[1] = IUniswapV2Pair(address(underlyingToken)).token0();
      swapToken0Path[0] = IUniswapV2Pair(address(underlyingToken)).token1();
      
      bytes[] memory abis = new bytes[](1);
      abis[0] = abi.encode(
        IUniswapV2Router02(uniswapRouter),
        swapToken0Path,
        swapToken1Path
      );

      vm.startPrank(accountOne);
      // FusePoolLens.FusePoolAsset[] memory assetsData = poolLens.getPoolAssetsWithData(IComptroller(address(comptroller)));
      // uint256 beamBalance = cBeamToken.balanceOf(accountOne);

      // emit log_uint(beamBalance);
      
      underlyingToken.approve(address(cToken), 1);
      liquidator.safeLiquidateToTokensWithFlashLoan(
        accountOne,
        1,
        ICErc20(address(cToken)),
        ICErc20(address(cBeamToken)),
        0,
        address(0),
        IUniswapV2Router02(uniswapRouter),
        IUniswapV2Router02(uniswapRouter),
        strategies,
        abis,
        0
      );
    }

    // FusePoolLens.FusePoolAsset[] memory assetsDataAfter = poolLens.getPoolAssetsWithData(
    //   IComptroller(address(comptroller))
    // );

    // uint256 beamBalanceAfter = cBeamToken.balanceOf(accountOne);

    // assertGt(beamBalance, beamBalanceAfter);
    // assertGt(assetsData[1].supplyBalance, assetsDataAfter[1].supplyBalance);

    // vm.stopPrank();
  }

  function testBeamDeployCErc20PluginDelegate() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    MockERC4626 erc4626 = new MockERC4626(ERC20(address(underlyingToken)));

    vm.roll(1);
    deployCErc20PluginDelegate(erc4626, 0.9e18);

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allMarkets[allMarkets.length - 1]));

    cToken._setImplementationSafe(address(cErc20PluginDelegate), false, abi.encode(address(erc4626)));
    assertEq(address(cToken.plugin()), address(erc4626));

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);
    vm.roll(1);

    cToken.mint(10e18);
    assertEq(cToken.totalSupply(), 10e18 * 5);
    uint256 balance = erc4626.balanceOf(address(cToken));
    assertEq(balance, 10e18);
    vm.roll(1);

    cToken.borrow(1000);
    assertEq(cToken.totalBorrows(), 1000);
    balance = erc4626.balanceOf(address(cToken));
    assertEq(balance, 10e18 - 1000);
    assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10e18 + 1000);
  }

  // function testBeamDeployCErc20PluginRewardsDelegate() public shouldRun(forChains(MOONBEAM_MAINNET)) {
  //   MockERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
  //   FuseFlywheelDynamicRewards rewards;
  //   FuseFlywheelCore flywheel = new FuseFlywheelCore(
  //     underlyingToken,
  //     IFlywheelRewards(address(0)),
  //     IFlywheelBooster(address(0)),
  //     address(this),
  //     Authority(address(0))
  //   );
  //   rewards = new FuseFlywheelDynamicRewards(flywheel, 1);
  //   flywheel.setFlywheelRewards(rewards);

  //   MockERC4626Dynamic mockERC4626Dynamic = new MockERC4626Dynamic(
  //     ERC20(address(underlyingToken)),
  //     FlywheelCore(address(flywheel))
  //   );

  //   ERC20 marketKey = ERC20(address(mockERC4626Dynamic));
  //   flywheel.addStrategyForRewards(marketKey);

  //   vm.roll(1);
  //   deployCErc20PluginRewardsDelegate(mockERC4626Dynamic, flywheel, 0.9e18);

  //   CToken[] memory allMarkets = comptroller.getAllMarkets();
  //   CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(address(allMarkets[allMarkets.length - 1]));

  //   cToken._setImplementationSafe(
  //     address(cErc20PluginRewardsDelegate),
  //     false,
  //     abi.encode(address(mockERC4626Dynamic), address(flywheel), address(underlyingToken))
  //   );
  //   assertEq(address(cToken.plugin()), address(mockERC4626Dynamic));
  //   assertEq(underlyingToken.allowance(address(cToken), address(mockERC4626Dynamic)), type(uint256).max);
  //   assertEq(underlyingToken.allowance(address(cToken), address(flywheel)), 0);

  //   cToken.approve(address(rewardToken), address(flywheel));
  //   assertEq(rewardToken.allowance(address(cToken), address(flywheel)), type(uint256).max);

  //   underlyingToken.approve(address(cToken), 1e36);
  //   address[] memory cTokens = new address[](1);
  //   cTokens[0] = address(cToken);
  //   comptroller.enterMarkets(cTokens);
  //   vm.roll(1);

  //   cToken.mint(10000000);
  //   assertEq(cToken.totalSupply(), 10000000 * 5);
  //   assertEq(mockERC4626Dynamic.balanceOf(address(cToken)), 10000000);
  //   assertEq(underlyingToken.balanceOf(address(mockERC4626Dynamic)), 10000000);
  //   vm.roll(1);

  //   cToken.borrow(1000);
  //   assertEq(cToken.totalBorrows(), 1000);
  //   assertEq(underlyingToken.balanceOf(address(mockERC4626Dynamic)), 10000000 - 1000);
  //   assertEq(mockERC4626Dynamic.balanceOf(address(cToken)), 10000000 - 1000);
  //   assertEq(underlyingToken.balanceOf(address(this)), 100e18 - 10000000 + 1000);
  // }
}