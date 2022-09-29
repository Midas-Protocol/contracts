// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CToken } from "../compound/CToken.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import "./config/BaseTest.t.sol";
import "./helpers/WithPool.sol";
import "../liquidators/UniswapV3LiquidatorFunder.sol";
import "../FuseSafeLiquidator.sol";
import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";
import "../external/uniswap/ISwapRouter.sol";
import "../external/uniswap/IUniswapV3Factory.sol";
import "../external/uniswap/Quoter/Quoter.sol";
import "../external/uniswap/IUniswapV3Pool.sol";


interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract UniswapV3LiquidatorFunderTest is BaseTest, WithPool {
  UniswapV3LiquidatorFunder private uniswapv3Liquidator;

  IUniswapV3Pool pool =
    IUniswapV3Pool(0x80A9ae39310abf666A87C743d6ebBD0E8C42158E);

  address minter = 0x68863dDE14303BcED249cA8ec6AF85d4694dea6A;
  IMockERC20 gmxToken = IMockERC20(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);

  IERC20Upgradeable weth;

  constructor() WithPool() {
    super.setUpWithPool(
      MasterPriceOracle(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1),
      ERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
    );
  }

  function setUp() public shouldRun(forChains(ARBITRUM_ONE)) {
    uint64 expirationPeriod = 60 * 40; // 40 mins
    weth = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    IUniswapV3Pool[] memory pools = new IUniswapV3Pool[](1);
    pools[0] = pool;
    uint256[] memory times = new uint256[](1);
    times[0] = expirationPeriod;

    Quoter quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    
    uniswapv3Liquidator = new UniswapV3LiquidatorFunder(
      ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564),
      IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984),
      quoter
    );
  }

  function getPool(address inputToken) internal view returns (IUniswapV3Pool) {
    return pool;
  }

  // function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
  //   vm.prank(minter);
  //   gmxToken.mint(address(uniswapv3Liquidator), 10e18);

  //   bytes memory data = abi.encode(address(gmxToken), address(pool), 60 * 40);
  //   (uint256 redeemableAmount, ) = getPool(address(gmxToken)).getRedeemTradeInfo(10e18);
  //   (IERC20Upgradeable outputToken, uint256 outputAmount) = uniswapv3Liquidator.redeem(gmxToken, 10e18, data);

  //   // should be weth
  //   assertEq(address(outputToken), address(weth));
  //   assertEq(outputAmount, redeemableAmount);
  // }

  // function testEmergencyRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
  //   IUniswapV3Pool pool = getPool(address(gmxToken));
  //   address manager = pool.synthereumFinder().getImplementationAddress("Manager");
  //   vm.prank(manager);
  //   pool.emergencyShutdown();

  //   vm.prank(minter);
  //   gmxToken.mint(address(uniswapv3Liquidator), 10e18);

  //   bytes memory data = abi.encode(address(gmxToken), address(pool), 60 * 40);
  //   (uint256 redeemableAmount, uint256 fee) = getPool(address(gmxToken)).getRedeemTradeInfo(10e18);
  //   (IERC20Upgradeable outputToken, uint256 outputAmount) = uniswapv3Liquidator.redeem(gmxToken, 10e18, data);

  //   // should be weth
  //   assertEq(address(outputToken), address(weth));
  //   assertEq(outputAmount, redeemableAmount + fee);
  // }

  struct LiquidationData {
    address[] cTokens;
    IRedemptionStrategy[] strategies;
    bytes[] abis;
    CToken[] allMarkets;
    FuseSafeLiquidator liquidator;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] data;
  }

  function testEstimateInputAmount() public shouldRun(forChains(ARBITRUM_ONE)) {
    // address _inputToken = address();

  }

  function testGMXLiquidation() public shouldRun(forChains(ARBITRUM_ONE)) {
    LiquidationData memory vars;
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    // setting up a new liquidator
    //    vars.liquidator = FuseSafeLiquidator(payable(0xc9C3D317E89f4390A564D56180bBB1842CF3c99C));
    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      ap.getAddress("wtoken"),
      address(uniswapRouter),
      0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH
      0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, // BTCB
      "0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303",
      25
    );

    Comptroller comptroller = Comptroller(0x185Fa7d0e7d8A4FE7E09eB9df68B549c660e1116);

    vars.allMarkets = comptroller.getAllMarkets();
    CErc20Delegate cTokenGMX = CErc20Delegate(0x14334AeEc3CE1DcFCCB822171aFD9A3f47B1b229);
    CErc20Delegate cTokenWETH = CErc20Delegate(0xB97eFc8553c8515D0C103106EE7C91F8A9Ba6af9);

    uint256 borrowAmount = 2e20;
    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply GMX
    dealGMX(accountOne, 10e21);
    // Account One supply weth
    dealWETH(accountOne, 10e9);

    emit log_uint(weth.balanceOf(accountOne));

    // Account One deposit weth
    vm.startPrank(accountOne);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenWETH);
      comptroller.enterMarkets(vars.cTokens);
    }
    weth.approve(address(cTokenWETH), 1e36);
    gmxToken.approve(address(cTokenGMX), 1e36);
    require(cTokenWETH.mint(5e8) == 0, "WETH mint failed");
    require(cTokenGMX.mint(5e21) == 0, "GMX mint failed");
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(0x82eDcFe00bd0ce1f3aB968aF09d04266Bc092e0E);
    comptroller._setBorrowPaused(CToken(address(cTokenGMX)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cTokenGMX.borrow(borrowAmount) == 0, "borrow failed");
    vm.stopPrank();

    // some time passes, interest accrues and prices change
    {
      vm.roll(block.number + 100);
      cTokenWETH.accrueInterest();
      cTokenGMX.accrueInterest();

      MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
      uint256 priceweth = mpo.getUnderlyingPrice(ICToken(address(cTokenWETH)));
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(address(cTokenWETH))),
        abi.encode(priceweth / 100)
      );
    }

    // prepare the liquidation
    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);

    vars.fundingStrategies = new IFundsConversionStrategy[](1);
    vars.data = new bytes[](1);
    vars.data[0] = abi.encode(weth, gmxToken, 3000);
    vars.fundingStrategies[0] = uniswapv3Liquidator;

    // all strategies need to be whitelisted
    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(vars.fundingStrategies[0], true);

    emit log_address(uniswapRouter.factory());
    emit log_address(ap.getAddress("wtoken"));
    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(weth), ap.getAddress("wtoken"));
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    uint256 repayAmount = borrowAmount / 10;
    // liquidate
    vm.prank(accountTwo);
    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        repayAmount,
        ICErc20(address(cTokenGMX)),
        ICErc20(address(cTokenWETH)),
        flashSwapPair,
        0,
        address(0),
        uniswapRouter,
        uniswapRouter,
        vars.strategies,
        vars.abis,
        0,
        vars.fundingStrategies,
        vars.data
      )
    );
  }

  function dealWETH(address to, uint256 amount) internal {
    vm.prank(0x489ee077994B6658eAfA855C308275EAd8097C4A); // whale
    weth.transfer(to, amount);
  }

  function dealGMX(address to, uint256 amount) internal {
    vm.prank(minter); // whale
    gmxToken.mint(to, amount);
  }
}
