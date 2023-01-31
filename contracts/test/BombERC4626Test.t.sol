// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../midas/strategies/BombERC4626.sol";
import { BaseTest } from "./config/BaseTest.t.sol";

contract BombERC4626Test is BaseTest {
  BombERC4626 vault;
  IERC20Upgradeable bombToken;
  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  uint256 depositAmount = 100e18;
  uint256 depositAmountRoundedDown = depositAmount - 2;
  address whale = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;

  function afterForkSetUp() internal override {
    bombToken = IERC20Upgradeable(address(xbombToken.reward()));
    vault = new BombERC4626();
    vault.initialize(ERC20Upgradeable(address(bombToken)), address(xbombToken));

    // get some tokens from a whale
    vm.prank(whale);
    bombToken.transfer(address(this), depositAmount);
  }

  function testInitializedValues() public fork(BSC_MAINNET) {
    assertEq(vault.name(), "Midas bomb.money Vault");
    assertEq(vault.symbol(), "mvBOMB");
    assertEq(address(vault.asset()), address(bombToken));
    assertEq(address(vault.xbomb()), address(xbombToken));
  }

  function deposit() internal {
    bombToken.approve(address(vault), depositAmount);
    vault.deposit(depositAmount, address(this));
  }

  function testDeposit() public fork(BSC_MAINNET) {
    deposit();

    //Test that the actual transfers worked
    assertEq(bombToken.balanceOf(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);

    //Test that the balance view calls work
    assertTrue(diff(vault.totalAssets(), depositAmountRoundedDown) <= 1);
    assertTrue(diff(vault.balanceOfUnderlying(address(this)), depositAmountRoundedDown) <= 1);

    //Test that we minted the correct amount of tokens
    assertEq(vault.balanceOf(address(this)), vault.previewDeposit(depositAmount));
  }

  function withdraw() internal {
    deposit();

    uint256 vaultAssets = vault.balanceOfUnderlying(address(this));
    vault.withdraw(vaultAssets, address(this), address(this));
  }

  function testWithdraw() public fork(BSC_MAINNET) {
    withdraw();

    // test that all vault assets are extracted and transferred to the depositor
    assertEq(vault.balanceOfUnderlying(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);
    assertTrue(diff(bombToken.balanceOf(address(this)), depositAmountRoundedDown) <= 1);
  }

  function redeem() internal {
    deposit();

    uint256 shares = vault.balanceOf(address(this));
    vault.redeem(shares, address(this), address(this));
  }

  function testRedeem() public fork(BSC_MAINNET) {
    redeem();

    // test that all vault assets are extracted and transferred to the depositor
    assertEq(vault.balanceOfUnderlying(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);
    assertTrue(diff(bombToken.balanceOf(address(this)), depositAmountRoundedDown) <= 1);
  }
}
