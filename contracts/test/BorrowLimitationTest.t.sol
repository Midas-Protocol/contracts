// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { BasePriceOracle } from "../oracles/BasePriceOracle.sol";
import { ChainlinkPriceOracleV2 } from "../oracles/default/ChainlinkPriceOracleV2.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "./config/BaseTest.t.sol";
import "./helpers/WithPool.sol";
import "../external/compound/ICToken.sol";

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract BorrowLimitationTest is BaseTest, WithPool {
  address minter = 0x68863dDE14303BcED249cA8ec6AF85d4694dea6A;

  IMockERC20 gmxToken = IMockERC20(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a); // 18 decimals
  IMockERC20 usdcToken = IMockERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // 6 decimals

  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      ERC20Upgradeable(address(0)) // wtoken
    );
  }

  function setUp() public shouldRun(forChains(ARBITRUM_ONE)) {
    vm.rollFork(28492082);

    setUpPool("gmx-test", false, 0.1e18, 1.1e18);

    deployCErc20Delegate(address(usdcToken), "USDC", "usdcToken", 0.9e18);
    deployCErc20Delegate(address(gmxToken), "GMX", "gmx", 0.9e18);
  }

  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
  }

  function testOracleSclaing() public shouldRun(forChains(ARBITRUM_ONE)) {
    CTokenInterface[] memory allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cTokenUSDC = CErc20Delegate(address(allMarkets[0]));
    CErc20Delegate cTokenGMX = CErc20Delegate(address(allMarkets[1]));

    ChainlinkPriceOracleV2 currentCLOracle = ChainlinkPriceOracleV2(0x983e0d0E02CF14C086E1cbde89F7d79D4A4deefb);
    {
      //      uint256 priceGMX = comptroller.oracle().getUnderlyingPrice(cTokenGMX);
      //      uint256 priceUSDC = comptroller.oracle().getUnderlyingPrice(cTokenUSDC);
      uint256 priceUSDC = currentCLOracle.getUnderlyingPrice(ICToken(address(cTokenUSDC)));

      //      emit log("under price gmx");
      //      emit log_uint(priceGMX);
      emit log("old price usdc");
      emit log_uint(priceUSDC);
    }

    {
      ChainlinkPriceOracleV2 clOracle = new ChainlinkPriceOracleV2(
        address(this),
        true,
        currentCLOracle.wtoken(),
        address(currentCLOracle.NATIVE_TOKEN_USD_PRICE_FEED())
      );
      clOracle.setPriceFeeds(
        asArray(cTokenUSDC.underlying()),
        asArray(address(currentCLOracle.priceFeeds(cTokenUSDC.underlying()))),
        ChainlinkPriceOracleV2.FeedBaseCurrency.USD
      );

      uint256 priceUSDC = clOracle.getUnderlyingPrice(ICToken(address(cTokenUSDC)));
      emit log("new price usdc");
      emit log_uint(priceUSDC);
      emit log("under price usdc");
      uint256 underPriceUSDC = clOracle.price(cTokenUSDC.underlying());
      emit log_uint(underPriceUSDC);
    }
  }

  function testBorrowLimitation() public shouldRun(forChains(ARBITRUM_ONE)) {
    LiquidationData memory vars;

    //    deployCErc20Delegate(address(usdcToken), "USDC", "usdcToken", 0.9e18);
    //    deployCErc20Delegate(address(gmxToken), "GMX", "gmx", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cTokenUSDC = CErc20Delegate(address(vars.allMarkets[0]));
    CErc20Delegate cTokenGMX = CErc20Delegate(address(vars.allMarkets[1]));

    uint256 borrowAmount = 10e18;
    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply GMX
    dealGMX(accountTwo, 10_000e18); // = 10_000 * 1e18
    // Account One supply usdcToken
    dealUSDC(accountOne, 100_000e6); // = 100_000 * 1e6

    emit log_uint(usdcToken.balanceOf(accountOne));

    // Account One deposit usdcToken
    vm.startPrank(accountOne);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenUSDC);
      comptroller.enterMarkets(vars.cTokens);
    }
    usdcToken.approve(address(cTokenUSDC), 1e36);
    require(cTokenUSDC.mint(50_000e6) == 0, "USDC mint failed"); // supply $50_000
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenUSDC);
      comptroller.enterMarkets(vars.cTokens);
    }
    gmxToken.approve(address(cTokenGMX), 1e36);
    require(cTokenGMX.mint(5_000e18) == 0, "GMX mint failed"); // supply 5000 GMX
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(address(this));
    comptroller._setBorrowPaused(CTokenInterface(address(cTokenGMX)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cTokenGMX.borrow(borrowAmount) == 0, "borrow failed"); // borrow 10 gmx
    vm.stopPrank();

    uint256 borrows = cTokenGMX.totalBorrowsCurrent();
    assertEq(borrows, borrowAmount, "!Borrow Amount");
  }

  function dealUSDC(address to, uint256 amount) internal {
    vm.prank(0x489ee077994B6658eAfA855C308275EAd8097C4A); // whale
    usdcToken.transfer(to, amount);
  }

  function dealGMX(address to, uint256 amount) internal {
    vm.prank(minter); // whale
    gmxToken.mint(to, amount);
  }
}
