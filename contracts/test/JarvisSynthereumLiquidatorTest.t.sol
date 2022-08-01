// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../liquidators/JarvisSynthereumLiquidator.sol";
import { CurveLpTokenLiquidatorNoRegistry } from "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import "../FuseSafeLiquidator.sol";

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract JarvisSynthereumLiquidatorTest is BaseTest {
  JarvisSynthereumLiquidator private liquidator;

  // TODO in the addresses provider?
  ISynthereumLiquidityPool synthereumLiquiditiyPool =
    ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49);

  address minter = 0x0fD8170Dc284CD558325029f6AEc1538c7d99f49;
  IMockERC20 jBRLToken = IMockERC20(0x316622977073BBC3dF32E7d2A9B3c77596a0a603);

  IERC20Upgradeable bUSD;

  function setUp() public {
    uint64 expirationPeriod = 60 * 40; // 40 mins
    bUSD = IERC20Upgradeable(ap.getAddress("bUSD"));
    liquidator = new JarvisSynthereumLiquidator(synthereumLiquiditiyPool, expirationPeriod);
  }

  function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(minter);
    jBRLToken.mint(address(liquidator), 10e18);

    (uint256 redeemableAmount, ) = liquidator.pool().getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, 10e18, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount);
  }

  function testEmergencyRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    ISynthereumLiquidityPool pool = liquidator.pool();
    address manager = pool.synthereumFinder().getImplementationAddress("Manager");
    vm.prank(manager);
    pool.emergencyShutdown();

    vm.prank(minter);
    jBRLToken.mint(address(liquidator), 10e18);

    (uint256 redeemableAmount, uint256 fee) = liquidator.pool().getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, 10e18, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount + fee);
  }

   /**
  * @dev This test simulates what would have happened with the liquidation if our bots could
  * liquidate 2brl collateral at the time the liquidation failed for this borrower/position.
  */
  // should be run at block 19806478
  function testLiquidate2brl() public shouldRun(forChains(BSC_MAINNET)) {
    if (block.number != 19806478) return;

    address oldFslAddress = 0xc9C3D317E89f4390A564D56180bBB1842CF3c99C;
//    address twobrl = 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9;
    address deployer = 0x304aE8f9300e09c8B33bb1a8AE1c14A6253a5F4D;

    address borrower = 0xD6b2095e913695DD10C071cC2F20247e921EFb8E;
    uint256 repayAmount = 103636250967557372900;
    ICErc20 cErc20 = ICErc20(0xa7213deB44f570646Ea955771Cc7f39B58841363); // cBUSD
    ICErc20 cTokenCollateral = ICErc20(0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba); // c2brl
//    uint256 minProfitAmount = 0;
    address exchangeProfitTo = address(cTokenCollateral);
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUniswapV2Router02 uniswapV2RouterForBorrow = uniswapRouter;
    IUniswapV2Router02 uniswapV2RouterForCollateral = uniswapRouter;
//    uint256 ethToCoinbase = 0;

    // 2brl -> jbrl -> busd (used to repay the flashswap)
    IRedemptionStrategy[] memory redemptionStrategies = new IRedemptionStrategy[](2);
    bytes[] memory strategyData = new bytes[](2);
    {
      CurveLpTokenLiquidatorNoRegistry curveLpTokenLiquidator = CurveLpTokenLiquidatorNoRegistry(0x7449E1af974C7DD3b723C07deB31CBaf47e4e252);
      // 2brl -> jbrl
      redemptionStrategies[0] = curveLpTokenLiquidator;
      strategyData[0] = abi.encode(uint8(0), address(jBRLToken));
    }
    {
      // jbrl -> busd
      redemptionStrategies[1] = liquidator;
      strategyData[1] = "";
    }

    vm.startPrank(deployer);
    //    FuseSafeLiquidator fsl = FuseSafeLiquidator(payable(oldFslAddress));
    // deploy a new FSL because the old has W_TOKEN = address(0)
    FuseSafeLiquidator fsl = new FuseSafeLiquidator();
    {
      address _wtoken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
      address _uniswapV2router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
      address _stableToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
      address _btcToken = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
      fsl.initialize(
        _wtoken,
        _uniswapV2router,
        _stableToken,
        _btcToken,
        "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5"
      );
    }

    fsl._whitelistRedemptionStrategy(redemptionStrategies[0], true);
    fsl._whitelistRedemptionStrategy(redemptionStrategies[1], true);

    fsl.safeLiquidateToTokensWithFlashLoan(
      borrower,
      repayAmount,
      cErc20,
      cTokenCollateral,
      0,
      exchangeProfitTo,
      uniswapV2RouterForBorrow,
      uniswapV2RouterForCollateral,
      redemptionStrategies,
      strategyData,
      0
    );
    vm.stopPrank();
  }
}
