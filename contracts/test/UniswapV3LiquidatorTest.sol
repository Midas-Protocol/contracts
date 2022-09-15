// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./config/BaseTest.t.sol";
import "../external/uniswap/ISwapRouter.sol";

contract UniswapV3LiquidatorTest is BaseTest {

  function testExactInputSingle() public shouldRun(forChains(ARBITRUM_ONE)) {
    address univ3RouterAddress = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address wethWhale = 0x905dfCD5649217c42684f23958568e533C711Aa3;
    address usdcAddress = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address usdcWhale = 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b;

    ISwapRouter swapRouter = ISwapRouter(univ3RouterAddress);

//    IERC20Upgradeable usdc = IERC20Upgradeable(usdcAddress);
//    vm.prank(usdcWhale);
//    usdc.transfer(address(this), 1e18);

//    IERC20Upgradeable weth = IERC20Upgradeable(wethAddress);
//    vm.prank(wethWhale);
//    weth.transfer(address(this), 1e18);

//    swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams(
//      usdcAddress,
//      wethAddress,
//      1,
//      address(this),
////      block.timestamp,
//      1e18,
//      1e8,
//      0
//    ));

//    {
//      vm.rollFork(24646173);
//      vm.prank(0x2B9E2F8E8EffbEf24772443aee13C2610398a5f5);
//      swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams(
//          0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
//          0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8,
//          500,
//          0x2B9E2F8E8EffbEf24772443aee13C2610398a5f5,
//        //      block.timestamp,
//          4799635426512674361,
//          7595244899,
//          0
//        ));
//    }


//    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams(
//      "",
//      address(this),
//  //    block.timestamp,
//      1e18,
//      1
//      );
//    swapRouter.exactInput(params);
//
//    address factory = swapRouter.factory();
//    emit log_address(factory);

    // https://arbiscan.io//tx/0xb0662614c764446408d95c523a72c8cd08a0c914eb92d65daeeb79f1c966f25e
      {
        vm.rollFork(24717561);
        vm.prank(0x1026Df41A10BB5057D4F08261d907893f2D5F78B);
        swapRouter.exactInput(ISwapRouter.ExactInputParams(
          hex"82af49447d8a07e3bd95bd0d56f35241523fbab10001f4ff970a61a04b1ca14834a43f5de4533ebddb5cc8",
          0x1026Df41A10BB5057D4F08261d907893f2D5F78B,
//          1663243551091,
          549473985016579686,
          895450280
         ));
      }

  }
}
