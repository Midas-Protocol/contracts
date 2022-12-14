// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import "../compound/CTokenInterfaces.sol";

contract MockAsset is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract MaxWithdrawTestPolygon is WithPool, BaseTest {
  address wmaticAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
  address usdcWhale = 0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245;
  address daiWhale = 0x06959153B974D0D5fDfd87D561db6d8d4FA0bb0B;

  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
    MockAsset usdc;
    MockAsset dai;
  }

  function afterForkSetUp() internal override {
    super.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(wmaticAddress));

    vm.prank(0x369582d2010B6eD950B571F4101e3bB9b554876F);
    MockERC20(address(underlyingToken)).transfer(address(this), 100e18);
    setUpPool("polygon-test", false, 0.1e18, 1.1e18);
  }

  function testMaxBorrow() public fork(POLYGON_MAINNET) {
    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fusePoolDirectory);

    LiquidationData memory vars;
    vm.roll(1);
    vars.usdc = MockAsset(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    vars.dai = MockAsset(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

    deployCErc20Delegate(address(vars.usdc), "USDC", "usdc", 0.9e18);
    deployCErc20Delegate(address(vars.dai), "DAI", "dai", 0.9e18);

    vars.allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();

    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[0]));

    CErc20Delegate cDaiToken = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);

    address accountOne = address(1);

    vm.prank(usdcWhale);
    MockERC20(address(vars.usdc)).transfer(accountOne, 10000e6);

    vm.prank(daiWhale);
    MockERC20(address(vars.dai)).transfer(accountOne, 10000e18);

    // Account One Supply
    {
      emit log("Account One Supply");
      vm.startPrank(accountOne);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.mint(1e6);
      vars.cTokens[0] = address(cToken);
      comptroller.enterMarkets(vars.cTokens);

      vars.dai.approve(address(cDaiToken), 1e36);
      cDaiToken.mint(1e18);
      vars.cTokens[0] = address(cDaiToken);
      comptroller.enterMarkets(vars.cTokens);

      vm.stopPrank();
      assertEq(cToken.totalSupply(), 1e6 * 5);
      assertEq(cDaiToken.totalSupply(), 1e18 * 5);

      uint256 maxBorrow = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cToken)));
      uint256 maxDaiBorrow = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cDaiToken)));
      assertApproxEqAbs((maxBorrow * 1e18) / 10**cToken.decimals(), maxDaiBorrow, uint256(1e16), "!max borrow");
    }
  }
}
