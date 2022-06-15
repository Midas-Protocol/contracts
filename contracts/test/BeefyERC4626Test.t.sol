// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { BeefyERC4626, IBeefyVault } from "../compound/strategies/BeefyERC4626.sol";
import { MockStrategy } from "./mocks/beefy/MockStrategy.sol";
import { MockVault } from "./mocks/beefy/MockVault.sol";
import { IStrategy } from "./mocks/beefy/IStrategy.sol";

contract BeefyERC4626Test is WithPool, BaseTest {
  BeefyERC4626 beefyERC4626;

  MockERC20 testToken;
  MockStrategy mockStrategy;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

  constructor()
    WithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      MockERC20(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6)
    )
  {}

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    vm.startPrank(0x1083926054069AaD75d7238E9B809b0eF9d94e5B);
    underlyingToken.transfer(address(this), 100e18);
    underlyingToken.transfer(address(1), 100e18);
    vm.stopPrank();
    setUpPool("beefy-test", false, 0.1e18, 1.1e18);
  }

  function testDeployCErc20PluginDelegate() public shouldRun(forChains(BSC_MAINNET)) {
    emit log_uint(underlyingToken.balanceOf(address(this)));
    mockStrategy = new MockStrategy(address(underlyingToken));
    mockVault = new MockVault(address(mockStrategy), "MockVault", "MV");
    beefyERC4626 = new BeefyERC4626(underlyingToken, IBeefyVault(address(mockVault)));

    deployCErc20PluginDelegate(ERC4626(address(underlyingToken)), 0.9e18);
    CToken[] memory allmarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allmarkets[allmarkets.length - 1]));

    cToken._setImplementationSafe(address(cErc20PluginDelegate), false, abi.encode(address(beefyERC4626)));
    assertEq(address(cToken.plugin()), address(beefyERC4626));

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    uint256 balanceOfVault = underlyingToken.balanceOf(address(mockVault));
    uint256 cTokenBalance = cToken.balanceOf(address(this));

    cToken.mint(1000);
    cTokenBalance = cToken.balanceOf(address(this));
    assertEq(cToken.totalSupply(), 1000 * 5);
    uint256 erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 1000);
    assertEq(cTokenBalance, 1000 * 5);
    uint256 underlyingBalance = underlyingToken.balanceOf(address(this));

    vm.startPrank(address(1));

    underlyingToken.approve(address(cToken), 1e36);
    cToken.mint(1000);
    balanceOfVault = underlyingToken.balanceOf(address(mockVault));
    cTokenBalance = cToken.balanceOf(address(1));
    assertEq(cTokenBalance, 1000 * 5);
    erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 2000);
    assertEq(cToken.totalSupply(), 1000 * 5 + cTokenBalance);
    underlyingBalance = underlyingToken.balanceOf(address(1));

    vm.stopPrank();

    cToken.redeemUnderlying(1000);
    cTokenBalance = cToken.balanceOf(address(this));
    erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 1000);
    underlyingBalance = underlyingToken.balanceOf(address(this));
    assertEq(underlyingBalance, 100e18);
  }
}
