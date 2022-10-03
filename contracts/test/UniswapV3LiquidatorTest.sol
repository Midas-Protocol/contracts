// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./config/BaseTest.t.sol";
import "../external/uniswap/ISwapRouter.sol";
import "../liquidators/UniswapV3Liquidator.sol";

contract UniswapV3LiquidatorTest is BaseTest {
  IERC20Upgradeable usdc;
  IERC20Upgradeable weth;
  ISwapRouter swapRouter;

  address univ3RouterAddress;
  address usdcAddress;
  address wethAddress;
  address usdcWhale;
  address wethWhale;

  function setUp() public {
    if (block.chainid == ARBITRUM_ONE) {
      wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
      usdcAddress = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
      univ3RouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      usdcWhale = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;
      wethWhale = 0x905dfCD5649217c42684f23958568e533C711Aa3;

      usdc = IERC20Upgradeable(usdcAddress);
      weth = IERC20Upgradeable(wethAddress);
      swapRouter = ISwapRouter(univ3RouterAddress);
    } else if (block.chainid == POLYGON_MAINNET) {
      univ3RouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      usdcAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
      wethAddress = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
      usdcWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
      wethWhale = 0x80A9ae39310abf666A87C743d6ebBD0E8C42158E;

      usdc = IERC20Upgradeable(usdcAddress);
      weth = IERC20Upgradeable(wethAddress);
      swapRouter = ISwapRouter(univ3RouterAddress);
    }
  }

  function testUniV3LiquidatorPolygon() public shouldRun(forChains(POLYGON_MAINNET)) {
    vm.rollFork(33132779);

    UniswapV3Liquidator liquidator = new UniswapV3Liquidator();
    uint256 fee = 500;

    dealUSDC(1e8, address(liquidator)); // 6 decimals

    bytes memory strategyData = abi.encode(swapRouter, weth, fee);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(usdc, 1e8, strategyData);

    assertEq(address(outputToken), address(weth), "the output token does not match");

    uint256 expectedOutputAmount = 62720847622000374; // price is around $1600 per ETH at the time
    assertEq(outputAmount, expectedOutputAmount, "the output amount does not match");
  }

  function testUniV3LiquidatorArbitrum() public shouldRun(forChains(ARBITRUM_ONE)) {
    vm.rollFork(24726528);

    UniswapV3Liquidator liquidator = new UniswapV3Liquidator();
    uint256 fee = 500;

    dealUSDC(1e8, address(liquidator)); // 6 decimals

    bytes memory strategyData = abi.encode(swapRouter, weth, fee);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(usdc, 1e8, strategyData);

    assertEq(address(outputToken), address(weth), "the output token does not match");

    uint256 expectedOutputAmount = 62880235405687447; // price is around $1600 per ETH at the time
    assertEq(outputAmount, expectedOutputAmount, "the output amount does not match");
  }

  function dealUSDC(uint256 amount, address to) internal {
    vm.prank(usdcWhale);
    usdc.transfer(to, amount);
  }

  function dealWETH(uint256 amount, address to) internal {
    vm.prank(wethWhale);
    weth.transfer(to, amount);
  }
}
