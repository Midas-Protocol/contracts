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
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import { UniswapLpTokenLiquidator } from "../liquidators/UniswapLpTokenLiquidator.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";
import "../compound/CTokenInterfaces.sol";

contract MockAsset is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract MaxWithdrawTest is WithPool, BaseTest {
  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      ERC20Upgradeable(ap.getAddress("wtoken"))
    );
  }

  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
    MockAsset asset;
    MockAsset usdc;
  }

  function setUp() public shouldRun(forChains(BSC_MAINNET, POLYGON_MAINNET)) {
    deal(address(underlyingToken), address(this), 100e18);
    setUpPool("bsc-test", false, 0.1e18, 1.1e18);
  }

  function testMaxWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fusePoolDirectory);

    LiquidationData memory vars;
    vm.roll(1);
    vars.asset = MockAsset(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    vars.usdc = MockAsset(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    deployCErc20Delegate(address(vars.asset), "BNB", "bnb", 0.9e18);
    deployCErc20Delegate(address(vars.usdc), "USDC", "usdc", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();
    CErc20Delegate cBnbToken = CErc20Delegate(address(vars.allMarkets[0]));

    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);

    address accountOne = address(1);
    address accountTwo = address(2);
    address accountThree = address(3);

    FusePoolLensSecondary secondary = new FusePoolLensSecondary();
    secondary.initialize(fusePoolDirectory);

    // Account One Supply
    deal(address(vars.asset), accountOne, 5000000000e18);
    deal(address(vars.asset), accountThree, 5000000000e18);
    deal(address(vars.usdc), accountTwo, 10000e18);

    // Account One Supply
    {
      emit log("Account One Supply");
      vm.startPrank(accountOne);
      vars.asset.approve(address(cBnbToken), 1e36);
      cBnbToken.mint(1e18);
      vars.cTokens[0] = address(cBnbToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
    }

    // Account Three Supply
    {
      emit log("Account Three Supply");
      vm.startPrank(accountThree);
      vars.asset.approve(address(cBnbToken), 1e36);
      cBnbToken.mint(1e18);
      vars.cTokens[0] = address(cBnbToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
    }

    // Account Two Supply
    {
      emit log("Account Two Supply");
      vm.startPrank(accountTwo);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.mint(1000e18);
      vars.cTokens[0] = address(cToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
      assertEq(cToken.totalSupply(), 1000e18 * 5);
      assertEq(cBnbToken.totalSupply(), 1e18 * 5 * 2);
    }

    // Account Two Borrow
    {
      emit log("Account Two Borrow");
      vm.startPrank(accountTwo);
      vars.usdc.approve(address(cBnbToken), 1e36);
      cBnbToken.borrow(0.5e16);
      vm.stopPrank();
    }

    // Account One Borrow
    {
      emit log("Account One Borrow");
      vm.startPrank(accountOne);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.borrow(0.5e18);
      assertEq(cToken.totalBorrows(), 0.5e18);

      uint256 maxWithdraw = poolLensSecondary.getMaxRedeem(accountOne, ICToken(address(cBnbToken)));

      uint256 beforeBnbBalance = vars.asset.balanceOf(accountOne);
      cBnbToken.redeemUnderlying(type(uint256).max);
      uint256 afterBnbBalance = vars.asset.balanceOf(accountOne);

      assertEq(afterBnbBalance - beforeBnbBalance, maxWithdraw);
      vm.stopPrank();
    }
  }

  function testMIIMOMaxWithdraw() public shouldRun(forChains(POLYGON_MAINNET)) {
    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fusePoolDirectory);

    LiquidationData memory vars;
    vm.roll(1);
    vars.asset = MockAsset(0xADAC33f543267c4D59a8c299cF804c303BC3e4aC);
    vars.usdc = MockAsset(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    deployCErc20Delegate(address(vars.asset), "MIMO", "mimo", 0.9e18);
    deployCErc20Delegate(address(vars.usdc), "USDC", "usdc", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();
    CErc20Delegate cMimoToken = CErc20Delegate(address(vars.allMarkets[0]));

    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);

    address accountOne = address(1);
    address accountTwo = address(2);
    address accountThree = address(3);

    FusePoolLensSecondary secondary = new FusePoolLensSecondary();
    secondary.initialize(fusePoolDirectory);

    deal(address(vars.asset), accountOne, 5000000000e18);
    deal(address(vars.asset), accountThree, 5000000000e18);
    deal(address(vars.usdc), accountTwo, 10000e6);

    // Account One Supply
    {
      emit log("Account One Supply");
      vm.startPrank(accountOne);
      vars.asset.approve(address(cMimoToken), 1e36);
      cMimoToken.mint(10000000e18);
      vars.cTokens[0] = address(cMimoToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
    }

    // Account Three Supply
    {
      emit log("Account Three Supply");
      vm.startPrank(accountThree);
      vars.asset.approve(address(cMimoToken), 1e36);
      cMimoToken.mint(10000000e18);
      vars.cTokens[0] = address(cMimoToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
    }

    // Account Two Supply
    {
      emit log("Account Two Supply");
      vm.startPrank(accountTwo);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.mint(1000e6);
      vars.cTokens[0] = address(cToken);
      comptroller.enterMarkets(vars.cTokens);
      vm.stopPrank();
      assertEq(cToken.totalSupply(), 1000e6 * 5);
      assertEq(cMimoToken.totalSupply(), 10000000e18 * 5 * 2);
    }

    // Account Two Borrow
    {
      emit log("Account Two Borrow");
      vm.startPrank(accountTwo);
      vars.asset.approve(address(cMimoToken), 1e36);

      uint256 maxBorrow = poolLensSecondary.getMaxBorrow(accountTwo, ICToken(address(cToken)));
      emit log_uint(maxBorrow);
      cMimoToken.borrow(maxBorrow);
      assertEq(cMimoToken.totalBorrows(), maxBorrow);

      vm.stopPrank();
    }

    // Account One Borrow
    {
      emit log("Account One Borrow");
      vm.startPrank(accountOne);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.borrow(0.5e6);
      assertEq(cToken.totalBorrows(), 0.5e6);

      uint256 maxWithdraw = poolLensSecondary.getMaxRedeem(accountOne, ICToken(address(cMimoToken)));

      uint256 beforeMimoBalance = vars.asset.balanceOf(accountOne);
      cMimoToken.redeemUnderlying(type(uint256).max);
      uint256 afterMimoBalance = vars.asset.balanceOf(accountOne);

      assertEq(afterMimoBalance - beforeMimoBalance, maxWithdraw);
      vm.stopPrank();
    }
  }
}
