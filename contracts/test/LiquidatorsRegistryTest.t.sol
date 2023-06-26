// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { LiquidatorsRegistry } from "../liquidators/registry/LiquidatorsRegistry.sol";
import { LiquidatorsRegistryExtension } from "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { ILiquidatorsRegistry } from "../liquidators/registry/ILiquidatorsRegistry.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract LiquidatorsRegistryTest is BaseTest {
  ILiquidatorsRegistry registry;

  function afterForkSetUp() internal override {
    registry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
  }

  function testRedemptionPath() public fork(BSC_CHAPEL) {
    IERC20Upgradeable chapelBomb = IERC20Upgradeable(0xe45589fBad3A1FB90F5b2A8A3E8958a8BAB5f768);
    IERC20Upgradeable chapelTUsd = IERC20Upgradeable(0x4f1885D25eF219D3D4Fa064809D6D4985FAb9A0b);
    IERC20Upgradeable chapelTDai = IERC20Upgradeable(0x8870f7102F1DcB1c35b01af10f1baF1B00aD6805);

    emit log("bomb tusd");
    emit log(registry.redemptionStrategiesByTokens(chapelBomb, chapelTDai).name());
    emit log("tusd bomb");
    emit log(registry.redemptionStrategiesByTokens(chapelTDai, chapelBomb).name());

    (IRedemptionStrategy strategy, bytes memory strategyData) = registry.getRedemptionStrategy(chapelBomb, chapelTDai);
  }
}
