// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../liquidators/JarvisSynthereumLiquidator.sol";

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract JarvisSynthereumLiquidatorTest is BaseTest {
  JarvisSynthereumLiquidator private jarvisLiquidator;

  // TODO in the addresses provider?
  ISynthereumLiquidityPool synthereumLiquiditiyPool =
    ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49);

  address minter = 0x0fD8170Dc284CD558325029f6AEc1538c7d99f49;
  IMockERC20 jBRLToken = IMockERC20(0x316622977073BBC3dF32E7d2A9B3c77596a0a603);

  IERC20Upgradeable bUSD;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    uint64 expirationPeriod = 60 * 40; // 40 mins
    bUSD = IERC20Upgradeable(ap.getAddress("bUSD"));

    ISynthereumLiquidityPool[] memory pools = new ISynthereumLiquidityPool[](1);
    pools[0] = synthereumLiquiditiyPool;
    uint256[] memory times = new uint256[](1);
    times[0] = expirationPeriod;

    jarvisLiquidator = new JarvisSynthereumLiquidator();
    jarvisLiquidator.initialize(pools, times);
  }

  function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(minter);
    jBRLToken.mint(address(jarvisLiquidator), 10e18);

    (uint256 redeemableAmount, ) = jarvisLiquidator.getPool(address(jBRLToken)).getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = jarvisLiquidator.redeem(jBRLToken, 10e18, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount);
  }

  function testEmergencyRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    ISynthereumLiquidityPool pool = jarvisLiquidator.getPool(address(jBRLToken));
    address manager = pool.synthereumFinder().getImplementationAddress("Manager");
    vm.prank(manager);
    pool.emergencyShutdown();

    vm.prank(minter);
    jBRLToken.mint(address(jarvisLiquidator), 10e18);

    (uint256 redeemableAmount, uint256 fee) = jarvisLiquidator.getPool(address(jBRLToken)).getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = jarvisLiquidator.redeem(jBRLToken, 10e18, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount + fee);
  }
}
