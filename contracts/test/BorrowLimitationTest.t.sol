// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "./config/BaseTest.t.sol";
import "./helpers/WithPool.sol";

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract BorrowLimitationTest is BaseTest, WithPool {
  address minter = 0x68863dDE14303BcED249cA8ec6AF85d4694dea6A;

  IMockERC20 gmxToken = IMockERC20(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);
  IMockERC20 usdcToken = IMockERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1),
      ERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
    );
  }

  function setUp() public shouldRun(forChains(ARBITRUM_ONE)) {
    setUpPool("gmx-test", false, 0.1e18, 1.1e18);
  }

  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
  }

  function testBorrowLimitation() public shouldRun(forChains(ARBITRUM_ONE)) {
    LiquidationData memory vars;

    deployCErc20Delegate(address(usdcToken), "USDC", "usdcToken", 0.9e18);
    deployCErc20Delegate(address(gmxToken), "GMX", "gmx", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cTokenUSDC = CErc20Delegate(address(vars.allMarkets[0]));
    CErc20Delegate cTokenGMX = CErc20Delegate(address(vars.allMarkets[1]));

    uint256 borrowAmount = 1e19;
    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply GMX
    dealGMX(accountTwo, 10e21);
    // Account One supply usdcToken
    dealUSDC(accountOne, 10e10);

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
    require(cTokenUSDC.mint(5e10) == 0, "USDC mint failed");
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenUSDC);
      comptroller.enterMarkets(vars.cTokens);
    }
    gmxToken.approve(address(cTokenGMX), 1e36);
    require(cTokenGMX.mint(5e21) == 0, "GMX mint failed");
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(address(this));
    comptroller._setBorrowPaused(CTokenInterface(address(cTokenGMX)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cTokenGMX.borrow(borrowAmount) == 0, "borrow failed");
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
