// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { StellaLpERC4626, IStellaDistributorV2 } from "../../midas/strategies/StellaLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { Comptroller } from "../../compound/Comptroller.sol";
import { FuseFeeDistributor } from "../../FuseFeeDistributor.sol";
import { DiamondExtension } from "../../midas/DiamondExtension.sol";
import { CTokenFirstExtension } from "../../compound/CTokenFirstExtension.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract StellaERC4626Test is AbstractERC4626Test {
  IStellaDistributorV2 distributor = IStellaDistributorV2(0xF3a5454496E26ac57da879bf3285Fa85DEBF0388); // what you deposit the LP into

  uint256 poolId;
  address marketAddress;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardsToken;

  function _setUp(string memory _testPreFix, bytes calldata testConfig) public override {
    setUpPool("stella-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));
    (address asset, uint256 _poolId, address[] memory _rewardTokens) = abi.decode(
      testConfig,
      (address, uint256, address[])
    );

    testPreFix = _testPreFix;
    poolId = _poolId;

    for (uint256 i = 0; i < _rewardTokens.length; i += 1) {
      rewardsToken.push(ERC20Upgradeable(_rewardTokens[i]));
    }

    StellaLpERC4626 stellaLpERC4626 = new StellaLpERC4626();
    stellaLpERC4626.initialize(
      ERC20Upgradeable(address(underlyingToken)),
      IStellaDistributorV2(address(distributor)),
      poolId,
      address(this),
      rewardsToken
    );

    plugin = stellaLpERC4626;

    // Just set it explicitly to 0. Just wanted to make clear that this is not forgotten but expected to be 0
    initialStrategyBalance = getStrategyBalance();
    initialStrategySupply = 0;

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    marketKey = ERC20(marketAddress);

    StellaLpERC4626(payable(address(plugin))).setRewardDestination(marketAddress);
  }

  function increaseAssetsInVault() public override {
    sendUnderlyingToken(1000e18, address(distributor));
  }

  function decreaseAssetsInVault() public override {
    vm.prank(0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe); //lpStaker
    underlyingToken.transfer(address(1), 200e18); // transfer doesnt work
  }

  // figure out how to get balance of plugin in LP staker contract
  // make sure it is not balance of underlying, rather balance of shares
  function getDepositShares() public view override returns (uint256) {
    (uint256 amount, , , ) = distributor.userInfo(poolId, address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return distributor.poolTotalLp(poolId);
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
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
      address(StellaLpERC4626(payable(address(plugin))).distributor()),
      address(distributor),
      string(abi.encodePacked("!distributor ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    (
      address[] memory addresses,
      string[] memory symbols,
      uint256[] memory decimals,
      uint256[] memory amounts
    ) = distributor.pendingTokens(poolId, address(plugin));

    deposit(address(this), depositAmount / 2);

    for (uint256 i = 0; i < addresses.length; i += 1) {
      uint256 actualAmount = ERC20(addresses[i]).balanceOf(address(plugin));
      assertEq(actualAmount, amounts[i], string(abi.encodePacked("!rewardBal ", symbols[i], testPreFix)));
    }
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    (
      address[] memory addresses,
      string[] memory symbols,
      uint256[] memory decimals,
      uint256[] memory amounts
    ) = distributor.pendingTokens(poolId, address(plugin));

    plugin.withdraw(poolId, address(this), address(this));

    for (uint256 i = 0; i < addresses.length; i += 1) {
      uint256 actualAmount = ERC20(addresses[i]).balanceOf(address(plugin));
      assertEq(actualAmount, amounts[i], string(abi.encodePacked("!rewardBal ", symbols[i], testPreFix)));
    }
  }

  function testStellaWGLMRRewards() public fork(MOONBEAM_MAINNET) {
    CErc20PluginRewardsDelegate market = CErc20PluginRewardsDelegate(0xeB7b975C105f05bFb02757fB9bb3361D77AAe84A);
    address pluginAddress = address(market.plugin());
    StellaLpERC4626 plugin = StellaLpERC4626(payable(pluginAddress));

    bool anyIsWNative = false;
    uint256 i = 0;
    while (true) {
      try plugin.rewardTokens(i++) returns (ERC20Upgradeable rewToken) {
        emit log_address(address(rewToken));
        if (address(rewToken) == ap.getAddress("wtoken")) anyIsWNative = true;
      } catch {
        break;
      }
    }

    assertTrue(anyIsWNative, "native needs to be among the reward tokens");
  }

  function testRedeemXcDotGlmr() public debuggingOnly fork(MOONBEAM_MAINNET) {
    address user = 0x5164BC753b317D234e4D762BF91Fd4a4DDBF557b;
    address marketAddress = 0x32Be4b977BaB44e9146Bb414c18911e652C56568;
    address correctPlugin = 0x7E9D7D2B5818b8a84B796BEaE8Ab059e24b4810c;
    address wtoken = ap.getAddress("wtoken");

    // upgrade the correct plugin to the latest implementation
    {
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(correctPlugin));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      address impl = proxy.implementation();
      emit log_named_address("current plugin impl", impl);
      StellaLpERC4626 latestPluginImpl = new StellaLpERC4626();
      vm.prank(admin);
      proxy.upgradeToAndCall(
        address(latestPluginImpl),
        abi.encodeWithSelector(latestPluginImpl.reinitialize.selector, wtoken)
      );
    }

    // log the market/plugin addresses before
    CErc20PluginRewardsDelegate market = CErc20PluginRewardsDelegate(marketAddress);
    address marketImplBefore = market.implementation();
    emit log_named_address("market impl", marketImplBefore);
    address pluginBefore = address(market.plugin());
    emit log_named_address("pluginBefore", pluginBefore);

    // upgrade the market with the hacked delegate
    {
      CErc20PluginRewardsDelegate newImpl = new CErc20PluginRewardsDelegate();
      FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
      vm.prank(ffd.owner());
      ffd._editCErc20DelegateWhitelist(
        asArray(marketImplBefore),
        asArray(address(newImpl)),
        asArray(false),
        asArray(true)
      );

      DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
      cErc20DelegateExtensions[0] = new CTokenFirstExtension();
      vm.prank(ffd.owner());
      ffd._setCErc20DelegateExtensions(address(newImpl), cErc20DelegateExtensions);

      Comptroller pool = Comptroller(address(market.comptroller()));

      vm.prank(pool.admin());
      market._setImplementationSafe(address(newImpl), false, abi.encode(correctPlugin));
    }

    address pluginAfter = address(market.plugin());
    emit log_named_address("pluginAfter", pluginAfter);
    StellaLpERC4626 plugin = StellaLpERC4626(payable(pluginAfter));
    emit log_named_address("plugin wnative", address(plugin.wNative()));

    vm.prank(user);
    assertEq(market.redeemUnderlying(type(uint256).max), 0, "error on redeem");
  }
}
