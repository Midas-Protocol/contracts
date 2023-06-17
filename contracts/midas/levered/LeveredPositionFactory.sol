// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { IFuseFeeDistributor } from "../../compound/IFuseFeeDistributor.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";
import { IComptroller } from "../../compound/ComptrollerInterface.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { LeveredPositionFactoryStorage } from "./LeveredPositionFactoryStorage.sol";
import { DiamondBase, DiamondExtension, LibDiamond } from "../../midas/DiamondExtension.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactory is LeveredPositionFactoryStorage, DiamondBase {
  using EnumerableSet for EnumerableSet.AddressSet;

  /*----------------------------------------------------------------
                            Constructor
  ----------------------------------------------------------------*/

  constructor(
    IFuseFeeDistributor _fuseFeeDistributor,
    ILiquidatorsRegistry _registry,
    uint256 _blocksPerYear
  ) {
    fuseFeeDistributor = _fuseFeeDistributor;
    liquidatorsRegistry = _registry;
    blocksPerYear = _blocksPerYear;
  }

  /*----------------------------------------------------------------
                            Admin Functions
  ----------------------------------------------------------------*/

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) external onlyOwner {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets not of the same pool");

    if (_whitelisted) {
      collateralMarkets.add(address(_collateralMarket));
      borrowableMarketsByCollateral[_collateralMarket].add(address(_stableMarket));
    } else {
      borrowableMarketsByCollateral[_collateralMarket].remove(address(_stableMarket));
      if (borrowableMarketsByCollateral[_collateralMarket].length() == 0)
        collateralMarkets.remove(address(_collateralMarket));
    }
  }

  function _setLiquidatorsRegistry(ILiquidatorsRegistry _liquidatorsRegistry) external onlyOwner {
    liquidatorsRegistry = _liquidatorsRegistry;
  }

  function _setSlippages(
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens,
    uint256[] calldata slippages
  ) external onlyOwner {
    require(slippages.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < slippages.length; i++) {
      conversionSlippage[inputTokens[i]][outputTokens[i]] = slippages[i];
    }
  }

  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace)
    public
    override
    onlyOwner
  {
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }
}
