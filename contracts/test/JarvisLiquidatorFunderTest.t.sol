// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CToken } from "../compound/CToken.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import "./config/BaseTest.t.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";
import "../FuseSafeLiquidator.sol";

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract JarvisLiquidatorFunderTest is BaseTest {
  JarvisLiquidatorFunder private jarvisLiquidator;

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

    jarvisLiquidator = new JarvisLiquidatorFunder();
  }

  function getPool(address inputToken) internal view returns (ISynthereumLiquidityPool) {
    return synthereumLiquiditiyPool;
  }

  function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(minter);
    jBRLToken.mint(address(jarvisLiquidator), 10e18);

    bytes memory data = abi.encode(address(jBRLToken), address(synthereumLiquiditiyPool), 60 * 40);
    (uint256 redeemableAmount, ) = getPool(address(jBRLToken)).getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = jarvisLiquidator.redeem(jBRLToken, 10e18, data);

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount);
  }

  function testEmergencyRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    ISynthereumLiquidityPool pool = getPool(address(jBRLToken));
    address manager = pool.synthereumFinder().getImplementationAddress("Manager");
    vm.prank(manager);
    pool.emergencyShutdown();

    vm.prank(minter);
    jBRLToken.mint(address(jarvisLiquidator), 10e18);

    bytes memory data = abi.encode(address(jBRLToken), address(synthereumLiquiditiyPool), 60 * 40);
    (uint256 redeemableAmount, uint256 fee) = getPool(address(jBRLToken)).getRedeemTradeInfo(10e18);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = jarvisLiquidator.redeem(jBRLToken, 10e18, data);

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount + fee);
  }

  struct LiquidationData {
    address[] cTokens;
    IRedemptionStrategy[] strategies;
    bytes[] abis;
    CToken[] allMarkets;
    FuseSafeLiquidator liquidator;
  }

  function testJbrlLiquidation() public shouldRun(forChains(BSC_MAINNET)) {
    LiquidationData memory vars;
    vm.roll(block.number + 1);

    // setting up a new liquidator
    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
      0x10ED43C718714eb63d5aA57B78B54704E256024E,
      0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
      0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c,
      "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5"
    );

    Comptroller comptroller = Comptroller(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);

    vars.allMarkets = comptroller.getAllMarkets();
    CErc20Delegate cTokenJBRL = CErc20Delegate(0x82A3103bc306293227B756f7554AfAeE82F8ab7a);
    CErc20Delegate cTokenBUSD = CErc20Delegate(0xa7213deB44f570646Ea955771Cc7f39B58841363);

    uint256 borrowAmount = 1e21;
    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply JBRL
    dealJBRL(accountOne, 10e12);
    // Account One supply BUSD
    dealBUSD(accountOne, 10e21);

    // Account One deposit BUSD
    vm.startPrank(accountOne);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenJBRL);
      vars.cTokens[1] = address(cTokenBUSD);
      comptroller.enterMarkets(vars.cTokens);
    }
    bUSD.approve(address(cTokenBUSD), 1e36);
    require(cTokenBUSD.mint(5e21) == 0, "mint failed");
    vm.stopPrank();

    // Account One borrow jBRL
    vm.prank(accountOne);
    require(cTokenJBRL.borrow(borrowAmount) == 0, "borrow failed");

    // some time passes, interest accrues and prices change
    {
      vm.roll(block.number + 100);
      cTokenBUSD.accrueInterest();
      cTokenJBRL.accrueInterest();

      MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
      uint256 priceBUSD = mpo.getUnderlyingPrice(ICToken(address(cTokenBUSD)));
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(address(cTokenBUSD))),
        abi.encode(priceBUSD / 100)
      );
    }

    // prepare the liquidation
    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);

    IFundsConversionStrategy[] memory fundingStrategies = new IFundsConversionStrategy[](1);
    bytes[] memory data = new bytes[](1);
    data[0] = abi.encode(address(jBRLToken), address(synthereumLiquiditiyPool), 60 * 40);
    fundingStrategies[0] = jarvisLiquidator;

    // all strategies need to be whitelisted
    vars.liquidator._whitelistRedemptionStrategy(fundingStrategies[0], true);

    uint256 repayAmount = borrowAmount / 10;
    // liquidate
    vm.prank(accountTwo);
    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        repayAmount,
        ICErc20(address(cTokenJBRL)),
        ICErc20(address(cTokenBUSD)),
        0,
        address(0),
        address(bUSD),
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E),
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E),
        vars.strategies,
        vars.abis,
        0,
        fundingStrategies,
        data
      )
    );
  }

  function dealBUSD(address to, uint256 amount) internal {
    address busdAddress = address(bUSD);
    vm.prank(0x0000000000000000000000000000000000001004); // whale
    bUSD.transfer(to, amount);
  }

  function dealJBRL(address to, uint256 amount) internal {
    address jbrlAddress = address(jBRLToken);
    vm.prank(0xad51e40D8f255dba1Ad08501D6B1a6ACb7C188f3); // whale
    jBRLToken.transfer(to, amount);
  }
}
