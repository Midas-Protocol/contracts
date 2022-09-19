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

contract MockAsset is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract MaxWithdrawTest is WithPool, BaseTest {
  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      ERC20Upgradeable(0x522348779DCb2911539e76A1042aA922F9C47Ee3)
    );
  }

  struct LiquidationData {
    address[] cTokens;
    CToken[] allMarkets;
    MockAsset asset;
    MockAsset usdc;
  }

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(0xcd6cD62F11F9417FBD44dc0a44F891fd3E869234);
    MockERC20(address(underlyingToken)).mint(address(this), 100e18);
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

    vm.prank(0xcd6cD62F11F9417FBD44dc0a44F891fd3E869234);
    MockERC20(address(underlyingToken)).mint(accountTwo, 1000000000000e18);
    // Account One Supply
    vm.deal(accountOne, 1000000000000e18);
    vm.startPrank(accountOne);
    vars.asset.deposit{ value: 5000000000e18 }();
    vm.stopPrank();
    vm.deal(accountThree, 1000000000000e18);
    vm.startPrank(accountThree);
    vars.asset.deposit{ value: 5000000000e18 }();
    vm.stopPrank();

    vm.startPrank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
    MockERC20(address(vars.usdc)).transfer(accountTwo, 10000e18);
    vm.stopPrank();

    // Account One Supply
    vm.startPrank(accountOne);
    vars.asset.approve(address(cBnbToken), 1e36);
    cBnbToken.mint(1e18);
    vars.cTokens[0] = address(cBnbToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    // Account Three Supply
    vm.startPrank(accountThree);
    vars.asset.approve(address(cBnbToken), 1e36);
    cBnbToken.mint(1e18);
    vars.cTokens[0] = address(cBnbToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    // Account Two Supply
    vm.startPrank(accountTwo);
    vars.usdc.approve(address(cToken), 1e36);
    cToken.mint(1000e18);
    vars.cTokens[0] = address(cToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();
    assertEq(cToken.totalSupply(), 1000e18 * 5);
    assertEq(cBnbToken.totalSupply(), 1e18 * 5 * 2);

    vm.startPrank(accountTwo);
    vars.usdc.approve(address(cBnbToken), 1e36);
    cBnbToken.borrow(0.5e16);
    vm.stopPrank();

    // Account One Borrow
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
