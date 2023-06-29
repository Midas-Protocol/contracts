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
  IERC20Upgradeable chapelBomb = IERC20Upgradeable(0xe45589fBad3A1FB90F5b2A8A3E8958a8BAB5f768);
  IERC20Upgradeable chapelTUsd = IERC20Upgradeable(0x4f1885D25eF219D3D4Fa064809D6D4985FAb9A0b);
  IERC20Upgradeable chapelTDai = IERC20Upgradeable(0x8870f7102F1DcB1c35b01af10f1baF1B00aD6805);
  IERC20Upgradeable busd = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

  function afterForkSetUp() internal override {
    registry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
  }

  function testRedemptionPath() public debuggingOnly fork(BSC_CHAPEL) {
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
    address[] memory inputTokens = registry.getInputTokensByOutputToken(busd);

    emit log_named_array("inputs", inputTokens);
  }

  function testSwappingBsc() public debuggingOnly fork(BSC_MAINNET) {
    address lpTokenWhale = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652; // pcs main staking contract
    address WBNB_BUSD_Uniswap = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;

    IERC20Upgradeable inputToken = IERC20Upgradeable(WBNB_BUSD_Uniswap);
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = busd;

    vm.startPrank(lpTokenWhale);
    inputToken.approve(address(registry), inputAmount);
    uint256 swappedAmountOut = registry.swap(inputToken, inputAmount, outputToken);
    vm.stopPrank();

    emit log_named_uint("received", swappedAmountOut);
  }
}
