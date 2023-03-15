// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";
import "../midas/vault/MultiStrategyVault.sol";
import "../midas/strategies/CompoundMarketERC4626.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC4626Upgradeable as IERC4626, IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";

contract OptimizedAPRVaultTest is BaseTest {
  function testVaultOptimization() public debuggingOnly fork(BSC_MAINNET) {
    address wnativeAddress = ap.getAddress("wtoken");
    address ankrWbnbMarketAddress = 0x57a64a77f8E4cFbFDcd22D5551F52D675cc5A956;
    address ahWbnbMarketAddress = 0x059c595f19d6FA9f8203F3731DF54455cD248c44;
    ICErc20 ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
    ICErc20 ahWbnbMarket = ICErc20(ahWbnbMarketAddress);

    MultiStrategyVault vault = new MultiStrategyVault();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(vault),
        address(dpa),
        ""
      );
      vault = MultiStrategyVault(address(proxy));
    }

    CompoundMarketERC4626 ankrMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(ankrMarketAdapter),
        address(dpa),
        ""
      );
      ankrMarketAdapter = CompoundMarketERC4626(address(proxy));
    }
    ankrMarketAdapter.initialize(
      ankrWbnbMarket,
      vault,
      20 * 24 * 365 * 60 //blocks per year
    );
    CompoundMarketERC4626 ahMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(ahMarketAdapter),
        address(dpa),
        ""
      );
      ahMarketAdapter = CompoundMarketERC4626(address(proxy));
    }
    ahMarketAdapter.initialize(
      ahWbnbMarket,
      vault,
      20 * 24 * 365 * 60 //blocks per year
    );

    AdapterConfig[10] memory adapters;
    adapters[0].adapter = ankrMarketAdapter;
    adapters[0].allocation = 3e17;
    adapters[1].adapter = ahMarketAdapter;
    adapters[1].allocation = 7e17;

    vault.initialize(
      IERC20(wnativeAddress),
      adapters,
      2, // adapters count
      VaultFees(0, 0, 0, 0),
      address(this),
      type(uint256).max
    );


  }
}