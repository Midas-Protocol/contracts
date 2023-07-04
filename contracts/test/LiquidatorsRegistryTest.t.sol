// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { LiquidatorsRegistry } from "../liquidators/registry/LiquidatorsRegistry.sol";
import { LiquidatorsRegistryExtension } from "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { ILiquidatorsRegistry } from "../liquidators/registry/ILiquidatorsRegistry.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";
import "../midas/DiamondExtension.sol";
import { SafeOwnable } from "../midas/SafeOwnable.sol";

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

  // polygon
  IERC20Upgradeable usdr3CrvCurveLpToken = IERC20Upgradeable(0xa138341185a9D0429B0021A11FB717B225e13e1F);
  IERC20Upgradeable maticBbaBalancerStableLpToken = IERC20Upgradeable(0xb20fC01D21A50d2C734C4a1262B4404d41fA7BF0);
  IERC20Upgradeable mimoParBalancerWeightedLpToken = IERC20Upgradeable(0x82d7f08026e21c7713CfAd1071df7C8271B17Eae);

  function afterForkSetUp() internal override {
    registry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
    stable = IERC20Upgradeable(ap.getAddress("stableToken"));
    wtoken = IERC20Upgradeable(ap.getAddress("wtoken"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function upgradeRegistry() internal {
    DiamondBase asBase = DiamondBase(address(registry));
    address[] memory exts = asBase._listExtensions();
    LiquidatorsRegistryExtension newExt = new LiquidatorsRegistryExtension();
    vm.prank(SafeOwnable(address(registry)).owner());
    asBase._registerExtension(newExt, DiamondExtension(exts[0]));
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }

  function testSwapAllowance() public debuggingOnly fork(BSC_CHAPEL) {
    vm.prank(0xdc3d8A4ee43dDe6a4E92F0D7A749C8eBD921239b);
    registry.amountOutAndSlippageOfSwap(chapelBomb, 1e18, chapelTUsd);
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

  function _swap(
    address whale,
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken,
    uint256 tolerance
  ) internal {
    vm.startPrank(whale);
    inputToken.approve(address(registry), inputAmount);
    (uint256 swappedAmountOut, uint256 slippage) = registry.amountOutAndSlippageOfSwap(
      inputToken,
      inputAmount,
      outputToken
    );
    vm.stopPrank();

    emit log_named_uint("received", swappedAmountOut);
    assertLt(slippage, 8e16, "slippage is > 8%");
  }

  function testSwappingUniLpBsc() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0x14B2e8329b8e06BCD524eb114E23fAbD21910109;

    IERC20Upgradeable inputToken = usdcBusdCakeLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = stable;

    _swap(lpTokenWhale, inputToken, inputAmount, outputToken, 1e16);
  }

  function testSwappingGammaLpBsc() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0xd44ad81474d075c3Bf0307830977A5804BfC0bc7; // thena gauge

    IERC20Upgradeable inputToken = ankrAnkrBnbGammaLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = wtoken;

    _swap(lpTokenWhale, inputToken, inputAmount, outputToken, 1e16);
  }

  function testSwappingCurveLpPolygon() public fork(POLYGON_MAINNET) {
    upgradeRegistry();

    address lpTokenWhale = 0x875CE7e0565b4C8852CA2a9608F27B7213A90786; // curve gauge

    IERC20Upgradeable inputToken = usdr3CrvCurveLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = stable;

    _swap(lpTokenWhale, inputToken, inputAmount, outputToken, 1e16);
  }

  function testSwappingBalancerStableLpPolygon() public fork(POLYGON_MAINNET) {
    address lpTokenWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // balancer gauge

    IERC20Upgradeable inputToken = maticBbaBalancerStableLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = wtoken;

    _swap(lpTokenWhale, inputToken, inputAmount, outputToken, 1e16);
  }

  function testSwappingBalancerWeightedLpPolygon() public fork(POLYGON_MAINNET) {
    address lpTokenWhale = 0xbB60ADbe38B4e6ab7fb0f9546C2C1b665B86af11; // mimo staker

    IERC20Upgradeable inputToken = mimoParBalancerWeightedLpToken;
    uint256 inputAmount = 1e18;
    IERC20Upgradeable outputToken = IERC20Upgradeable(0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128); // PAR

    _swap(lpTokenWhale, inputToken, inputAmount, outputToken, 5e16);
  }
}
