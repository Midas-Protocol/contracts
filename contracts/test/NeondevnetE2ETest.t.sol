// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";
import "forge-std/Test.sol";
import "../compound/CTokenInterfaces.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import { UniswapLpTokenLiquidator } from "../liquidators/UniswapLpTokenLiquidator.sol";
import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";

contract MockWNeon is MockERC20 {
  constructor() MockERC20("test", "test", 18) {}

  function deposit() external payable {}
}

contract NeondevnetE2ETest is WithPool, BaseTest {
  address mpo = 0xFC43A2A797f731dad53D6BC4Fe9300d68F480203;
  address moraToken = 0x6Ab1F83c0429A1322D7ECDFdDf54CE6D179d911f;
  address wtoken = 0xf1041596da0499c3438e3B1Eb7b95354C6Aed1f5;

  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(mpo), // MasterPriceOracle
      ERC20Upgradeable(moraToken) // MORA
    );
  }

  struct LiquidationData {
    address[] cTokens;
    uint256 oraclePrice;
    FusePoolLens.FusePoolAsset[] assetsData;
    FusePoolLens.FusePoolAsset[] assetsDataAfter;
    IRedemptionStrategy[] strategies;
    UniswapLpTokenLiquidator lpLiquidator;
    address[] swapToken0Path;
    address[] swapToken1Path;
    bytes[] abis;
    CTokenInterface[] allMarkets;
    FuseSafeLiquidator liquidator;
    MockERC20 erc20;
    MockWNeon asset;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] data;
    uint256 price2;
  }

  function setUp() public shouldRun(forChains(NEON_DEVNET)) {
    deal(address(underlyingToken), address(this), 10e18);
    setUpPool("neondevnet-test", false, 0.1e18, 1.1e18);
  }

  function testNeonDeployCErc20Delegate() public shouldRun(forChains(NEON_DEVNET)) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);

    CTokenInterface[] memory allMarkets = comptroller.getAllMarkets();
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

  function testNeonGetPoolAssetsData() public shouldRun(forChains(NEON_DEVNET)) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);

    CTokenInterface[] memory allMarkets = comptroller.getAllMarkets();
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

  function testNeonCErc20Liquidation() public shouldRun(forChains(NEON_DEVNET)) {
    LiquidationData memory vars;
    vm.roll(1);
    vars.erc20 = MockERC20(moraToken); // MORA
    vars.asset = MockWNeon(wtoken); // WNEON

    deployCErc20Delegate(address(vars.erc20), "MORA", "MoraSwap", 0.9e18);
    deployCErc20Delegate(address(vars.asset), "WNEON", "Wrapped Neon", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[0]));
    CErc20Delegate cWNeonToken = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);

    // setting up liquidator
    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      wtoken, // wneon
      0x696d73D7262223724d60B2ce9d6e20fc31DfC56B, // moraswap router
      0x7ff459CE3092e8A866aA06DA88D291E2E31230C1, // USDC
      0x6fbF8F06Ebce724272813327255937e7D1E72298, // wWBTC
      "0x1f475d88284b09799561ca05d87dc757c1ff4a9f48983cdb84d1dd6e209d3ae2",
      30
    );

    address accountOne = address(1);
    address accountTwo = address(2);

    FusePoolLensSecondary secondary = new FusePoolLensSecondary();
    secondary.initialize(fusePoolDirectory);

    // Accounts pre supply
    deal(address(underlyingToken), accountTwo, 10000e18);
    deal(address(vars.asset), accountOne, 10000e18);

    // Account One Supply
    vm.startPrank(accountOne);
    vars.asset.approve(address(cWNeonToken), 1e36);
    cWNeonToken.mint(1e17);
    vars.cTokens[0] = address(cWNeonToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    // Account Two Supply
    vm.startPrank(accountTwo);
    underlyingToken.approve(address(cToken), 1e36);
    cToken.mint(10e18);
    vars.cTokens[0] = address(cToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    assertEq(cToken.totalSupply(), 10e18 * 5);
    assertEq(cWNeonToken.totalSupply(), 1e17 * 5);

    // Account One Borrow
    vm.startPrank(accountOne);
    underlyingToken.approve(address(cToken), 1e36);
    cToken.borrow(1e16);
    vm.stopPrank();
    assertEq(cToken.totalBorrows(), 1e16);

    vars.price2 = priceOracle.getUnderlyingPrice(ICToken(address(cWNeonToken)));
    vm.mockCall(
      mpo, // MPO
      abi.encodeWithSelector(priceOracle.getUnderlyingPrice.selector, ICToken(address(cWNeonToken))),
      abi.encode(vars.price2 / 1000)
    );

    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);
    vars.fundingStrategies = new IFundsConversionStrategy[](0);
    vars.data = new bytes[](0);

    vm.startPrank(accountOne);
    FusePoolLens.FusePoolAsset[] memory assetsData = poolLens.getPoolAssetsWithData(IComptroller(address(comptroller)));
    uint256 neonBalance = cWNeonToken.balanceOf(accountOne);

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x696d73D7262223724d60B2ce9d6e20fc31DfC56B);
    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(
      address(underlyingToken),
      0xf1041596da0499c3438e3B1Eb7b95354C6Aed1f5
    );
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        9e14,
        ICErc20(address(cToken)),
        ICErc20(address(cWNeonToken)),
        flashSwapPair,
        0,
        address(0),
        uniswapRouter,
        uniswapRouter,
        vars.strategies,
        vars.abis,
        0,
        vars.fundingStrategies,
        vars.data
      )
    );

    FusePoolLens.FusePoolAsset[] memory assetsDataAfter = poolLens.getPoolAssetsWithData(
      IComptroller(address(comptroller))
    );

    uint256 neonBalanceAfter = cWNeonToken.balanceOf(accountOne);

    assertGt(neonBalance, neonBalanceAfter);
    assertGt(assetsData[1].supplyBalance, assetsDataAfter[1].supplyBalance);

    vm.stopPrank();
  }
}
