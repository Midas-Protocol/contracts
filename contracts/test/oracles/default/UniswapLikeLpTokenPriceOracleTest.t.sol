// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPair, Observation } from "../../../external/solidly/IPair.sol";
import { IRouter } from "../../../external/solidly/IRouter.sol";
import { IUniswapV2Pair } from "../../../external/uniswap/IUniswapV2Pair.sol";
import { UniswapLpTokenPriceOracle } from "../../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { SolidlyLpTokenPriceOracle } from "../../../oracles/default/SolidlyLpTokenPriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "../../../oracles/default/UniswapLikeLpTokenPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract UniswapLikeLpTokenPriceOracleTest is BaseTest {
  UniswapLikeLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function getSolidlyLpTokenPriceOracle() internal returns (UniswapLikeLpTokenPriceOracle) {
    return new SolidlyLpTokenPriceOracle(wtoken);
  }

  function getUniswapLpTokenPriceOracle() internal returns (UniswapLikeLpTokenPriceOracle) {
    return new UniswapLpTokenPriceOracle(wtoken);
  }

  function getLpPrice(address lpToken, UniswapLikeLpTokenPriceOracle oracle) internal returns (uint256) {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      address[] memory underlyings = new address[](1);
      IPriceOracle[] memory oracles = new IPriceOracle[](1);

      underlyings[0] = lpToken;
      oracles[0] = IPriceOracle(oracle);

      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }
    return mpo.price(lpToken);
  }

  function verifyLpPrice(
    address lpToken,
    uint256 price,
    uint256 tolerance
  ) internal {
    uint256 priceToken0 = mpo.price(IPair(lpToken).token0());
    uint256 priceToken1 = mpo.price(IPair(lpToken).token1());
    uint256 token0Decimals = uint256(ERC20Upgradeable(IPair(lpToken).token0()).decimals());
    uint256 token1Decimals = uint256(ERC20Upgradeable(IPair(lpToken).token1()).decimals());

    assertApproxEqRel(
      2 * sqrt(priceToken0 * (10**(18 - token0Decimals))) * sqrt(priceToken1 * (10**(18 - token1Decimals))),
      price,
      tolerance
    );
  }

  function testBusdWbnbUniswap() public fork(BSC_MAINNET) {
    address lpToken = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16; // Lp WBNB-BUSD

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 3e17); // 3% tolerance
  }

  function testBnbXBnbSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x6c83E45fE3Be4A9c12BB28cB5BA4cD210455fb55; // Lp BNBx/WBNB (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17); // 1% tolerance
  }

  function testUsdtUsdcSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x618f9Eb0E1a698409621f4F487B563529f003643; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testBusdWbnbSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x483653bcF3a10d9a1c334CE16a19471a614F4385; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testWbtcWethArbiSolidly() public fork(ARBITRUM_ONE) {
    address lpToken = 0xd9D611c6943585bc0e18E51034AF8fa28778F7Da; // Lp WBTC/WETH (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17); // 1% tolerance
  }

  function testDaitUsdcArbiSolidly() public fork(ARBITRUM_ONE) {
    address lpToken = 0x07d7F291e731A41D3F0EA4F1AE5b6d920ffb3Fe0; // Lp DAI/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testUsdtUsdcArbiSolidly() public fork(ARBITRUM_ONE) {
    address lpToken = 0xC9dF93497B1852552F2200701cE58C236cC0378C; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testWethGmxArbiSolidly() public fork(ARBITRUM_ONE) {
    address lpToken = 0x06A4c4389d5C6cD1Ec63dDFFb7e9b3214254A720; // Lp WETH/GMX (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testGlmrUsdcLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x8CCBbcAF58f5422F6efD4034d8E8a3c9120ADf79; // Lp GLMR-USDC

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
  }

  function testGlmrWbtcpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0xf8f5E8B9Ee84664695B14862212D8092E16331F6; // Lp WBTC-WGLMR

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);

    // This approximation doesn't really work with larger priced tokens
    // verifyLpPrice(lpToken, price, 1e17);
  }

  function testWGlmrWethLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x8577273FB3B72306F3A59E26ab77116f5D428DAa; // Lp WETH-WGLMR

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  // Fixed block number tests
  // https://arbiscan.io/tx/0xff32f8f997d487a3e6f602552f2da9edc1e31f1e023e0e9dcacc77bd177791b1
  // 0.015037668670 LP tokens removed from the pool
  // - 14,546.17 DAI
  // - 15,543.33 USDC
  // =~ $30,119.52  = ~19.307 ETH (ETH price: $1560)
  // Therefor, LP price is 19.307/0.015037668670 = 1283,9
  function testForkedDaiUsdcArbiSolidly() public forkAtBlock(ARBITRUM_ONE, 67509709) {
    address lpToken = 0x07d7F291e731A41D3F0EA4F1AE5b6d920ffb3Fe0; // Lp DAI/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertEq(price, 1271881478415550136267); // 1271881478415550136267/1e18 = 1271,88
  }

  // https://arbiscan.io/tx/0x8e5366d84d278c7dc5fa285c9cb3cf63697763066a77c228b7ae2a2cea9115e7
  // 0.000000011455333328 LP tokens removed from the pool
  // - 11,264.0276 USDT
  // - 11,646.6401 USDC
  // =~ $22,910  = ~14.68 ETH (ETH price: $1560)
  // Therefor, LP price is 14.68/0.000000011455333328 = 1,2815e9
  function testForkedUsdtUsdcArbiSolidly() public forkAtBlock(ARBITRUM_ONE, 67509709) {
    address lpToken = 0xC9dF93497B1852552F2200701cE58C236cC0378C; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertEq(price, 1275460020881969657832030547); // 1275460020881969657832030547/1e18 = 1,275e9
  }

  // https://arbiscan.io/tx/0xcd98ae753ca7cbe93bfb653c3090fa0973ad10ab6b096fe7005216eae3f96a0f
  // 5.111039 LP tokens added from the pool
  // - 1.11740494 WETH
  // - 24.5277511 GMX
  // =~ $3490,5  = ~2,237 ETH (ETH price: $1560)
  // Therefor, LP price is 2,237/5,111 = 0,4377
  function testForkeWethGmxArbiSolidly() public forkAtBlock(ARBITRUM_ONE, 67509709) {
    address lpToken = 0x06A4c4389d5C6cD1Ec63dDFFb7e9b3214254A720; // Lp WETH/GMX (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertEq(price, 439393617368171439); // 439393617368171439/1e18 = 0.439393617368171439
  }

  // https://arbiscan.io/tx/0xb33c8fd30b124070c08eff4c7dd8fbf98c1a8ac8b61e7e9afb5da3c77176c4ff
  // 0.000000084147497167 LP tokens added from the pool
  // - 0.00222613 WBTC
  // - 0.031808  WETH
  // =~ $99,73  = ~0.06393 ETH (ETH price: $1560)
  // Therefor, LP price is 0.06393/0.000000084147497167 = 759.737,391
  function testForkeWethWbtcArbiSolidly() public forkAtBlock(ARBITRUM_ONE, 67509709) {
    address lpToken = 0xd9D611c6943585bc0e18E51034AF8fa28778F7Da; // Lp WETH/WBTC (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertEq(price, 755603649957725481578826); // 755603649957725481578826/1e18 = 755,603.6499
  }

  // https://bscscan.com/tx/0x4f08c603fddf6d4fcc4cfd7e8fa325d5a2ed6d61f097c86204a5ef915acf4948
  // 12,593.45 LP tokens added from the pool
  // - 12,282.086 USDT
  // - 12,904.8221 USDC
  // =~ $25,211  = ~88,46 BNB (ETH price: $285,77)
  // Therefor, LP price is 88,46/12,593.45 = 0,007024286

  function testForkeUsdtUsdcBscSolidly() public forkAtBlock(BSC_MAINNET, 26257339) {
    address lpToken = 0x618f9Eb0E1a698409621f4F487B563529f003643; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertEq(price, 6993216032507730); // 6993216032507730/1e18 = 0.006993216032507730
  }

  function testSolidlyLPTokenPriceManipulationWithSwaps() public debuggingOnly fork(ARBITRUM_ONE) {
    address pairAddress = 0x15b9D20bcaa4f65d9004D2BEBAc4058445FD5285;

    address dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address daiWhale = 0x969f7699fbB9C79d8B61315630CDeED95977Cfb8;
    address usdtWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;

    SolidlyLpTokenPriceOracle lpOracle = new SolidlyLpTokenPriceOracle(ap.getAddress("wtoken"));

    vm.prank(address(mpo));
    uint256 priceBefore = lpOracle.price(pairAddress);
    emit log_named_uint("price before", priceBefore);

    IPair pair = IPair(pairAddress);
    ERC20Upgradeable daiToken = ERC20Upgradeable(pair.token0());
    ERC20Upgradeable usdtToken = ERC20Upgradeable(pair.token1());

    // manipulate
    {
      address hacker = address(666);
      vm.startPrank(daiWhale);
      daiToken.transfer(hacker, daiToken.balanceOf(daiWhale));
      vm.stopPrank();

      vm.startPrank(usdtWhale);
      usdtToken.transfer(hacker, usdtToken.balanceOf(usdtWhale));
      vm.stopPrank();

      vm.startPrank(hacker);
      ERC20Upgradeable tokenToSwap = daiToken;

      // advance > 30 mins so an observations is recorded
      //vm.warp(block.timestamp + 60 * 22);

      uint256 amountOut = pair.getAmountOut(tokenToSwap.balanceOf(hacker), address(tokenToSwap));
      tokenToSwap.transfer(pairAddress, tokenToSwap.balanceOf(hacker));
      pair.swap(amountOut, 0, hacker, "");
      vm.stopPrank();
    }

    for (uint256 i = 0; i < 60; i++) {
      vm.warp(block.timestamp + 15);
      pair.sync();

      emit log_named_uint("i", i);
      vm.prank(address(mpo));
      emit log_named_uint("price after", lpOracle.price(pairAddress));
    }
  }

  function testSolidlyLPTokenPriceManipulationWithMintAndBurn() public fork(ARBITRUM_ONE) {
    address pairAddress = 0x15b9D20bcaa4f65d9004D2BEBAc4058445FD5285;
    address pairWhale = 0x637DCef6f06A120e0cca5BCa079F6cF6Da9264e8;
    IRouter router = IRouter(0xF26515D5482e2C2FD237149bF6A653dA4794b3D0);

    SolidlyLpTokenPriceOracle lpOracle = new SolidlyLpTokenPriceOracle(ap.getAddress("wtoken"));

    vm.prank(address(mpo));
    uint256 priceBefore = lpOracle.price(pairAddress);
    emit log_named_uint("price before", priceBefore);

    uint256 initialPairBalance = ERC20Upgradeable(pairAddress).balanceOf(pairWhale);
    emit log_named_uint("initialPairBalance", initialPairBalance);

    // manipulate
    {
      uint256 burnAmount = (initialPairBalance * 4) / 10;
      vm.startPrank(pairWhale);
      ERC20Upgradeable(pairAddress).approve(address(router), burnAmount);
      (uint256 amountA, uint256 amountB) = router.removeLiquidity(
        0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, // dai
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // usdt
        true,
        burnAmount,
        0,
        0,
        pairWhale,
        block.timestamp + 1
      );
      emit log_named_uint("amountA", amountA);
      emit log_named_uint("amountB", amountB);
      vm.stopPrank();
    }
    vm.prank(address(mpo));
    uint256 priceAfter = lpOracle.price(pairAddress);
    emit log_named_uint("price after", priceAfter);
    emit log_named_uint("% price change", (100 * (priceAfter - priceBefore) * 1e18) / priceBefore / 1e18);
  }
}
