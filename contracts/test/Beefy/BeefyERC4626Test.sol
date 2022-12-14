// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BeefyERC4626, IBeefyVault, IBeefyStrategy } from "../../midas/strategies/BeefyERC4626.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract BeefyERC4626Test is AbstractERC4626Test {
  uint256 withdrawalFee = 10;

  IBeefyVault beefyVault; // ERC4626 => underlyingToken => beefyStrategy
  address lpChef; // beefyStrategy => underlyingToken => .

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    testPreFix = _testPreFix;

    (address _beefyVault, uint256 _withdrawalFee, address _lpChef) = abi.decode(data, (address, uint256, address));

    lpChef = _lpChef;
    beefyVault = IBeefyVault(_beefyVault);

    IBeefyStrategy strategy = IBeefyStrategy(beefyVault.strategy());
    vm.prank(strategy.keeper());
    strategy.setHarvestOnDeposit(false);
    underlyingToken = ERC20Upgradeable(address(beefyVault.want()));
    BeefyERC4626 beefyERC4626 = new BeefyERC4626();
    beefyERC4626.initialize(underlyingToken, beefyVault, _withdrawalFee);
    plugin = beefyERC4626;

    initialStrategyBalance = beefyVault.balance();
    initialStrategySupply = beefyVault.totalSupply();

    sendUnderlyingToken(depositAmount, address(this));
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(beefyVault), 1000e18);
    beefyVault.earn();
  }

  function decreaseAssetsInVault() public override {
    vm.prank(lpChef);
    underlyingToken.transfer(address(1), 200e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return beefyVault.balanceOf(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return beefyVault.balance();
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return (depositAmount * beefyVault.totalSupply()) / beefyVault.balance();
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(
      address(BeefyERC4626(address(plugin)).beefyVault()),
      address(beefyVault),
      string(abi.encodePacked("!beefyVault ", testPreFix))
    );
  }
}
