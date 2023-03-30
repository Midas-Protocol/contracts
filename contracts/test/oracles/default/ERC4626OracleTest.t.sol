// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "../../config/BaseTest.t.sol";
import { ERC4626Oracle } from "../../../oracles/default/ERC4626Oracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IERC4626 } from "../../../compound/IERC4626.sol";
import { ChainlinkPriceOracleV2 } from "../../../oracles/default/ChainlinkPriceOracleV2.sol";

import { IUniswapV3Factory } from "../../../external/uniswap/IUniswapV3Factory.sol";
import { Quoter } from "../../../external/uniswap/Quoter/Quoter.sol";
import { IUniswapV3Pool } from "../../../external/uniswap/IUniswapV3Pool.sol";
import { ISwapRouter } from "../../../external/uniswap/ISwapRouter.sol";
import { ERC4626Liquidator } from "../../../liquidators/ERC4626Liquidator.sol";

contract ERC4626OracleTest is BaseTest {
  MasterPriceOracle mpo;
  ChainlinkPriceOracleV2 chainlinkOracle;
  ERC4626Oracle erc4626Oracle;

  IERC20Upgradeable WETH;
  IERC20Upgradeable daiToken;
  IERC20Upgradeable usdcToken;
  IERC20Upgradeable usdtToken;

  address nativeUsdPriceFeed;
  address usdcUsdPriceFeed;

  IERC4626 erc4626Vault;
  address[] underlyingTokens;
  ERC4626Liquidator liquidator;

  address usdcMarketAddress;
  address univ3SwapRouter;

  uint256 poolFee;

  Quoter quoter;

  address holder;

  function setUpMpoAndAddresses() public {
    if (block.chainid == ETHEREUM_MAINNET) {
      WETH = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
      usdcToken = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
      daiToken = IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
      usdtToken = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);

      erc4626Vault = IERC4626(0x97e6E0a40a3D02F12d1cEC30ebfbAE04e37C119E);
      nativeUsdPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
      usdcUsdPriceFeed = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;

      address[] memory assets = new address[](0);
      IPriceOracle[] memory oracles = new IPriceOracle[](0);
      mpo = new MasterPriceOracle();
      mpo.initialize(assets, oracles, IPriceOracle(address(0)), address(this), true, address(WETH));
    }
  }

  function setUpAssetOracles() public {
    setUpMpoAndAddresses();
    IPriceOracle[] memory oracles = new IPriceOracle[](2);
    chainlinkOracle = new ChainlinkPriceOracleV2(mpo.admin(), true, address(WETH), nativeUsdPriceFeed);
    vm.prank(chainlinkOracle.admin());
    chainlinkOracle.setPriceFeeds(
      asArray(address(usdcToken)),
      asArray(usdcUsdPriceFeed),
      ChainlinkPriceOracleV2.FeedBaseCurrency.ETH
    );
    oracles[0] = IPriceOracle(address(chainlinkOracle));

    erc4626Oracle = new ERC4626Oracle();
    vm.prank(erc4626Oracle.owner());
    erc4626Oracle.initialize();
    oracles[1] = IPriceOracle(address(erc4626Oracle));

    vm.prank(mpo.admin());
    mpo.add(asArray(address(usdcToken), address(erc4626Vault)), oracles);
  }

  function setupRedemptionStrategy() public {
    if (block.chainid == ETHEREUM_MAINNET) {
      underlyingTokens = asArray(address(usdcToken), address(daiToken), address(usdtToken)); // USDC, 6 decimals
      poolFee = 10;
      quoter = new Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
      univ3SwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      holder = 0x3541Fda19b09769A938EB2A5f5154b01aE5b0869;
    }
    liquidator = new ERC4626Liquidator();
  }

  function testErc4626aPriceOracle() public fork(ETHEREUM_MAINNET) {
    setUpAssetOracles();
    uint256 priceRealYieldUsdc = mpo.price(address(erc4626Vault));
    uint256 priceUsdc = mpo.price(address(usdcToken));

    emit log_named_uint("priceRy", priceRealYieldUsdc);
    emit log_named_uint("priceUSdc", priceUsdc);

    // Approximate only -- these should not match.
    assertApproxEqRel(priceRealYieldUsdc, priceUsdc, 1e17, "!diff > 10%");
  }

  function testErc4626RedemptionStrategy() public fork(ETHEREUM_MAINNET) {
    setUpAssetOracles();
    setupRedemptionStrategy();
    // make sure we're testing with at least some tokens
    uint256 balance = erc4626Vault.balanceOf(holder);
    assertTrue(balance > 0);

    // impersonate the holder
    vm.prank(holder);

    // fund the liquidator so it can redeem the tokens
    erc4626Vault.transfer(address(liquidator), balance);

    bytes memory data = abi.encode(address(usdcToken), poolFee, univ3SwapRouter, underlyingTokens, quoter);
    // redeem the underlying reward token
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(erc4626Vault)),
      balance,
      data
    );

    uint256 usdcBalance = usdcToken.balanceOf(address(liquidator));

    assertEq(address(outputToken), address(usdcToken));
    assertEq(outputAmount, usdcBalance);

    uint256 redeemValue = (mpo.price(address(erc4626Vault)) * balance) / 1e18;
    uint256 redeemUsdcValue = (mpo.price(address(usdcToken)) * usdcBalance) / 1e6;

    assertApproxEqRel(redeemValue, redeemUsdcValue, 1e15, "!diff > 0.1%");
  }
}
