// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../contracts/compound/strategies/BombERC4626.sol";
import "../config/BaseTest.t.sol";

contract BombERC4626Test is BaseTest {
  BombERC4626 vault;
  IERC20 bombToken;
  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  uint256 depositAmount = 100e18;
  uint256 depositAmountRoundedDown = depositAmount - 1;
  address whale = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    bombToken = IERC20(address(xbombToken.reward()));
    vault = new BombERC4626(xbombToken, ERC20(address(bombToken)));

    // get some tokens from a whale
    vm.prank(whale);
    bombToken.transfer(address(this), depositAmount);
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(vault.name(), "bomb.money");
    assertEq(vault.symbol(), "BOMB");
    assertEq(address(vault.asset()), address(bombToken));
    assertEq(address(vault.xbomb()), address(xbombToken));
  }

  function deposit() internal {
    bombToken.approve(address(vault), depositAmount);
    vault.deposit(depositAmount, address(this));
  }

  function testDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    deposit();

    //Test that the actual transfers worked
    assertEq(bombToken.balanceOf(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);

    //Test that the balance view calls work
    assertEq(vault.totalAssets(), depositAmountRoundedDown);
    assertEq(vault.balanceOfUnderlying(address(this)), depositAmountRoundedDown);

    //Test that we minted the correct amount of tokens
    assertEq(vault.balanceOf(address(this)), vault.previewDeposit(depositAmount));
  }

  function withdraw() internal {
    deposit();

    uint256 vaultAssets = vault.balanceOfUnderlying(address(this));
    vault.withdraw(vaultAssets, address(this), address(this));
  }

  function testWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    withdraw();

    // test that all vault assets are extracted and transferred to the depositor
    assertEq(vault.balanceOfUnderlying(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);
    assertEq(bombToken.balanceOf(address(this)), depositAmountRoundedDown);
  }

  function redeem() internal {
    deposit();

    uint256 shares = vault.balanceOf(address(this));
    vault.redeem(shares, address(this), address(this));
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    redeem();

    // test that all vault assets are extracted and transferred to the depositor
    assertEq(vault.balanceOfUnderlying(address(this)), 0);
    assertEq(bombToken.balanceOf(address(vault)), 0);
    assertEq(bombToken.balanceOf(address(this)), depositAmountRoundedDown);
  }
}
