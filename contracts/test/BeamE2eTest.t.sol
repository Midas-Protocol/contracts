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

contract MockBeamERC20 is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract BeamE2eTest is WithPool, BaseTest {
  using stdStorage for StdStorage;
  StdStorage internal stdstore;
  
  address wToken = 0xAcc15dC74880C9944775448304B263D191c6077F;
  address mPriceOracle = 0x14C15B9ec83ED79f23BF71D51741f58b69ff1494;
  address uniswapRouter = 0x96b244391D98B62D19aE89b1A4dCcf0fc56970C7;
  address USDC = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;
  address accountOne = address(1);
  address accountTwo = address(2);
  address joy = 0x33Ad49856da25b8E2E2D762c411AEda0D1727918;
  address bob = 0x739ca6D71365a08f584c8FC4e1029045Fa8ABC4B;

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
    CToken[] allMarkets;
    FuseSafeLiquidator liquidator;
    MockERC4626 erc4626;
    MockBeamERC20 asset;
  }


  constructor()
    WithPool(
      MasterPriceOracle(mPriceOracle),
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
    LiquidationData memory vars;
    vars.erc4626 = new MockERC4626(ERC20(address(underlyingToken)));
    vars.asset = MockBeamERC20(USDC);

    deployCErc20PluginDelegate(vars.erc4626, 0.9e18);
    deployCErc20Delegate(address(vars.asset), "BNB", "bnb", 0.1e18);

    vars.allMarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cTokenLP = CErc20PluginDelegate(address(vars.allMarkets[0]));
    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[1]));

    cTokenLP._setImplementationSafe(address(cErc20PluginDelegate), false, abi.encode(address(vars.erc4626)));

    // setting up liquidator
    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      wToken,
      uniswapRouter,
      USDC,
      0xcd3B51D98478D53F4515A306bE565c6EebeF1D58,
      "0xe31da4209ffcce713230a74b5287fa8ec84797c9e77e1f7cfeccea015cdc97ea"
    );

    // Tokens supply
    vm.prank(joy);
    underlyingToken.transfer(accountTwo, 1000e18);

    vm.prank(bob);
    vars.asset.transfer(accountOne, 10000000);

    /* 
     * CToken Supply
     */

    // Account One Supply
    vm.startPrank(accountOne);
    vars.asset.approve(address(cToken), 1e36);
    cToken.mint(10000000);
    vm.stopPrank();

    // Account Two Supply
    vm.startPrank(accountTwo);
    underlyingToken.approve(address(cTokenLP), 1e36);
    cTokenLP.mint(10e18);
    vm.stopPrank();

    assertEq(cTokenLP.totalSupply(), 10e18 * 5);
    assertEq(cToken.totalSupply(), 10000000 * 5);

    /**
     * Adding ctokens to collateral.
     */

    vars.cTokens = new address[](1);

    vm.startPrank(accountTwo);
    vars.cTokens[0] = address(cTokenLP);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    vm.startPrank(accountOne);
    vars.cTokens[0] = address(cToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();
  
    
    /**
     * Borrowing
     */

    vm.prank(accountTwo);
    cToken.borrow(100000);

    assertEq(cToken.totalBorrows(), 100000);

    /**
     * Updating oracle price
     */
    {
      vars.oraclePrice = priceOracle.getUnderlyingPrice(ICToken(address(cToken)));
      vm.mockCall(
        mPriceOracle,
        abi.encodeWithSelector(priceOracle.getUnderlyingPrice.selector, ICToken(address(cToken))),
        abi.encode(vars.oraclePrice * 40)
      );
    }

    {
      vars.strategies = new IRedemptionStrategy[](1);
      vars.lpLiquidator = new UniswapLpTokenLiquidator();

      /**
       * Whitelisting lp token redemption strategy
       */
      vars.liquidator._whitelistRedemptionStrategy(vars.lpLiquidator, true);

      vars.strategies[0] = vars.lpLiquidator;
      vars.swapToken0Path = new address[](2);
      vars.swapToken1Path = new address[](0);
      vars.abis = new bytes[](1);
      vars.swapToken0Path[0] = IUniswapV2Pair(address(underlyingToken)).token0();
      vars.swapToken0Path[1] = IUniswapV2Pair(address(underlyingToken)).token1();
      vars.abis[0] = abi.encode(
        IUniswapV2Router02(uniswapRouter),
        vars.swapToken0Path,
        vars.swapToken1Path
      );

      vm.startPrank(accountTwo);
      vars.assetsData = poolLens.getPoolAssetsWithData(IComptroller(address(comptroller)));
      uint256 beamBalance = cTokenLP.balanceOf(accountTwo);

      /**
       * Liquidation
       */
      vars.liquidator.safeLiquidateToTokensWithFlashLoan(
        accountTwo,
        400,
        ICErc20(address(cToken)),
        ICErc20(address(cTokenLP)),
        0,
        address(0),
        IUniswapV2Router02(uniswapRouter),
        IUniswapV2Router02(uniswapRouter),
        vars.strategies,
        vars.abis,
        0
      );
      vars.assetsDataAfter = poolLens.getPoolAssetsWithData(
        IComptroller(address(comptroller))
      );

      uint256 beamBalanceAfter = cTokenLP.balanceOf(accountTwo);

      assertGt(beamBalance, beamBalanceAfter);
      assertGt(vars.assetsData[0].supplyBalance, vars.assetsDataAfter[0].supplyBalance);
    }
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
}