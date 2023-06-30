// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { LiquidatorsRegistry } from "../liquidators/registry/LiquidatorsRegistry.sol";
import { LiquidatorsRegistryExtension } from "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { ILiquidatorsRegistry } from "../liquidators/registry/ILiquidatorsRegistry.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract LiquidatorsRegistryTest is BaseTest {
  ILiquidatorsRegistry registry;

  // all-chains
  IERC20Upgradeable stable;
  IERC20Upgradeable wtoken;
  MasterPriceOracle mpo;

  // chapel
  IERC20Upgradeable chapelBomb = IERC20Upgradeable(0xe45589fBad3A1FB90F5b2A8A3E8958a8BAB5f768);
  IERC20Upgradeable chapelTUsd = IERC20Upgradeable(0x4f1885D25eF219D3D4Fa064809D6D4985FAb9A0b);
  IERC20Upgradeable chapelTDai = IERC20Upgradeable(0x8870f7102F1DcB1c35b01af10f1baF1B00aD6805);

  // bsc
  IERC20Upgradeable wbnbBusdLpToken = IERC20Upgradeable(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);
  IERC20Upgradeable usdcBusdCakeLpToken = IERC20Upgradeable(0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1);

  IERC20Upgradeable ankrAnkrBnbGammaLpToken = IERC20Upgradeable(0x3f8f3caefF393B1994a9968E835Fd38eCba6C1be);

  function afterForkSetUp() internal override {
    registry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
    stable = IERC20Upgradeable(ap.getAddress("stableToken"));
    wtoken = IERC20Upgradeable(ap.getAddress("wtoken"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function testRedemptionPathChapel() public debuggingOnly fork(BSC_CHAPEL) {
    emit log("bomb tusd");
    emit log(registry.redemptionStrategiesByTokens(chapelBomb, chapelTDai).name());
    emit log("tusd bomb");
    emit log(registry.redemptionStrategiesByTokens(chapelTDai, chapelBomb).name());

    (IRedemptionStrategy strategy, bytes memory strategyData) = registry.getRedemptionStrategy(chapelBomb, chapelTDai);
  }

  function testInputTokensChapel() public debuggingOnly fork(BSC_CHAPEL) {
    address[] memory inputTokens = registry.getInputTokensByOutputToken(chapelBomb);

    emit log_named_array("inputs", inputTokens);
  }

  function testInputTokensBsc() public debuggingOnly fork(BSC_MAINNET) {
    address[] memory inputTokens = registry.getInputTokensByOutputToken(stable);

    emit log_named_array("inputs", inputTokens);
  }

  function testSwappingUniLpBsc() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0x14B2e8329b8e06BCD524eb114E23fAbD21910109;

    IERC20Upgradeable inputToken = usdcBusdCakeLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = stable;

    vm.startPrank(lpTokenWhale);
    inputToken.approve(address(registry), inputAmount);
    uint256 swappedAmountOut = registry.swap(inputToken, inputAmount, outputToken);
    vm.stopPrank();

    emit log_named_uint("received", swappedAmountOut);
  }

  function testSwappingGammaLpBsc() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0xd44ad81474d075c3Bf0307830977A5804BfC0bc7; // thena gauge

    IERC20Upgradeable inputToken = ankrAnkrBnbGammaLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = wtoken;

    uint256 inputAmountValue = (mpo.price(address(inputToken)) * inputAmount) / 1e18;
    vm.startPrank(lpTokenWhale);
    inputToken.approve(address(registry), inputAmount);
    uint256 swappedAmountOut = registry.swap(inputToken, inputAmount, outputToken);
    vm.stopPrank();
    uint256 outputAmountValue = (mpo.price(address(outputToken)) * swappedAmountOut) / 1e18;

    assertApproxEqRel(inputAmountValue, outputAmountValue, 1e16); // 1%
    emit log_named_uint("received", swappedAmountOut);
  }
}
