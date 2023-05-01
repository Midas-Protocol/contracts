// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";
import "../compound/CTokenInterfaces.sol";

contract MockAsset is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract MaxBorrowTest is WithPool {
  address usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
  address daiWhale = 0x06959153B974D0D5fDfd87D561db6d8d4FA0bb0B;

  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
    MockAsset usdc;
    MockAsset dai;
  }

  function afterForkSetUp() internal override {
    super.setUpWithPool(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      ERC20Upgradeable(ap.getAddress("wtoken"))
    );

    if (block.chainid == POLYGON_MAINNET) {
      vm.prank(0x369582d2010B6eD950B571F4101e3bB9b554876F); // SAND/WMATIC
      MockERC20(address(underlyingToken)).transfer(address(this), 100e18);
      setUpPool("polygon-test", false, 0.1e18, 1.1e18);
    } else if (block.chainid == BSC_MAINNET) {
      deal(address(underlyingToken), address(this), 100e18);
      setUpPool("bsc-test", false, 0.1e18, 1.1e18);
    }
  }

  function testMaxBorrow() public fork(POLYGON_MAINNET) {
    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fusePoolDirectory);

    LiquidationData memory vars;
    vm.roll(1);
    vars.usdc = MockAsset(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    vars.dai = MockAsset(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

    deployCErc20Delegate(address(vars.usdc), "USDC", "usdc", 0.9e18);
    deployCErc20Delegate(address(vars.dai), "DAI", "dai", 0.9e18);

    // TODO no need to upgrade after the next deploy
    upgradePool(address(comptroller));

    vars.allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();

    CErc20Delegate cToken = CErc20Delegate(address(vars.allMarkets[0]));

    CErc20Delegate cDaiToken = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);

    address accountOne = address(1);

    vm.prank(usdcWhale);
    MockERC20(address(vars.usdc)).transfer(accountOne, 10000e6);

    vm.prank(daiWhale);
    MockERC20(address(vars.dai)).transfer(accountOne, 10000e18);

    // Account One Supply
    {
      emit log("Account One Supply");
      vm.startPrank(accountOne);
      vars.usdc.approve(address(cToken), 1e36);
      cToken.mint(1e6);
      vars.cTokens[0] = address(cToken);
      comptroller.enterMarkets(vars.cTokens);

      vars.dai.approve(address(cDaiToken), 1e36);
      cDaiToken.mint(1e18);
      vars.cTokens[0] = address(cDaiToken);
      comptroller.enterMarkets(vars.cTokens);

      vm.stopPrank();
      assertEq(cToken.totalSupply(), 1e6 * 5);
      assertEq(cDaiToken.totalSupply(), 1e18 * 5);

      uint256 maxBorrow = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cToken)));
      uint256 maxDaiBorrow = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cDaiToken)));
      assertApproxEqAbs((maxBorrow * 1e18) / 10**cToken.decimals(), maxDaiBorrow, uint256(1e16), "!max borrow");
    }

    // borrow cap for collateral test
    {
      ComptrollerFirstExtension asExtension = comptroller.asComptrollerFirstExtension();
      vm.prank(comptroller.admin());
      asExtension._setBorrowCapForCollateral(address(cToken), address(cDaiToken), 0.5e6);
    }

    uint256 maxBorrowAfterBorrowCap = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cToken)));
    assertApproxEqAbs(maxBorrowAfterBorrowCap, 0.5e6, uint256(1e5), "!max borrow");

    // blacklist
    {
      ComptrollerFirstExtension asExtension = comptroller.asComptrollerFirstExtension();
      vm.prank(comptroller.admin());
      asExtension._blacklistBorrowingAgainstCollateral(address(cToken), address(cDaiToken), true);
    }

    uint256 maxBorrowAfterBlacklist = poolLensSecondary.getMaxBorrow(accountOne, ICToken(address(cToken)));
    assertEq(maxBorrowAfterBlacklist, 0, "!blacklist");
  }

  // TODO test with the latest block and contracts and/or without the FSL
  function testBorrowCapPerCollateral() public debuggingOnly forkAtBlock(BSC_MAINNET, 23761190) {
    address payable jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);

    address poolAddress = jFiatPoolAddress;
    Comptroller pool = Comptroller(poolAddress);

    // TODO no need to upgrade after the next deploy
    upgradePool(address(pool));

    ComptrollerFirstExtension asExtension = ComptrollerFirstExtension(poolAddress);
    address[] memory borrowers = asExtension.getAllBorrowers();
    address someBorrower = borrowers[1];

    CTokenInterface[] memory markets = asExtension.getAllMarkets();
    for (uint256 i = 0; i < markets.length; i++) {
      CTokenInterface market = markets[i];
      uint256 borrowed = market.borrowBalanceStored(someBorrower);
      if (borrowed > 0) {
        emit log("borrower has borrowed");
        emit log_uint(borrowed);
        emit log("from market");
        emit log_address(address(market));
        emit log_uint(i);
        emit log("");
      }

      uint256 collateral = market.asCTokenExtensionInterface().balanceOf(someBorrower);
      if (collateral > 0) {
        emit log("has collateral");
        emit log_uint(collateral);
        emit log("in market");
        emit log_address(address(market));
        emit log_uint(i);
        emit log("");
      }
    }

    CTokenInterface marketToBorrow = markets[0];
    CTokenInterface cappedCollateralMarket = markets[6];
    uint256 borrowAmount = marketToBorrow.borrowBalanceStored(someBorrower);

    {
      (uint256 errBefore, uint256 liquidityBefore, uint256 shortfallBefore) = pool.getHypotheticalAccountLiquidity(
        someBorrower,
        address(marketToBorrow),
        0,
        borrowAmount
      );
      emit log("errBefore");
      emit log_uint(errBefore);
      emit log("liquidityBefore");
      emit log_uint(liquidityBefore);
      emit log("shortfallBefore");
      emit log_uint(shortfallBefore);

      assertGt(liquidityBefore, 0, "expected positive liquidity");
    }

    vm.prank(pool.admin());
    asExtension._setBorrowCapForCollateral(address(marketToBorrow), address(cappedCollateralMarket), 1);
    emit log("");

    (uint256 errAfter, uint256 liquidityAfter, uint256 shortfallAfter) = pool.getHypotheticalAccountLiquidity(
      someBorrower,
      address(marketToBorrow),
      0,
      borrowAmount
    );
    emit log("errAfter");
    emit log_uint(errAfter);
    emit log("liquidityAfter");
    emit log_uint(liquidityAfter);
    emit log("shortfallAfter");
    emit log_uint(shortfallAfter);

    assertGt(shortfallAfter, 0, "expected some shortfall");
  }

  // TODO test with the latest block and contracts and/or without the FSL
  function testBorrowAndSupplyCapWhitelist() public debuggingOnly forkAtBlock(BSC_MAINNET, 27827185) {
    address payable ankrBnbPool = payable(0x1851e32F34565cb95754310b031C5a2Fc0a8a905);

    address poolAddress = ankrBnbPool;
    Comptroller pool = Comptroller(poolAddress);

    // TODO no need to upgrade after the next deploy
    upgradePool(address(pool));

    ComptrollerFirstExtension asExtension = ComptrollerFirstExtension(poolAddress);
    address[] memory borrowers = asExtension.getAllBorrowers();
    address borrower = 0x28C0208b7144B511C73586Bb07dE2100495e92f3; // ANKR account
    address otherSupplier = 0x2924973E3366690eA7aE3FCdcb2b4e136Cf7f8Cc; // Supplier of ankrBNBAnkrMkt
    CTokenInterface ankrBNBAnkrMkt = CTokenInterface(0x71693C84486B37096192c9942852f542543639Bf);
    CTokenInterface ankrBNBMkt = CTokenInterface(0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa);

    uint256 borrowedAnkr = ankrBNBMkt.borrowBalanceStored(borrower);
    emit log_named_uint("Ankr borrower balance", borrowedAnkr);
    uint256 collateralAnkr = ankrBNBAnkrMkt.asCTokenExtensionInterface().balanceOf(borrower);
    emit log_named_uint("Ankr collateral balance of ankrBNB-ANKR", collateralAnkr);

    uint256 borrowedOther = ankrBNBMkt.borrowBalanceStored(otherSupplier);
    emit log_named_uint("Other supplier borrower balance", borrowedOther);
    uint256 collateralOther = ankrBNBAnkrMkt.asCTokenExtensionInterface().balanceOf(otherSupplier);
    emit log_named_uint("Other supplier collateral balance of ankrBNB-ANKR", collateralOther);

    emit log("");
    emit log("Before collateral caps");
    {
      (, uint256 liq, uint256 sf) = pool.getHypotheticalAccountLiquidity(borrower, address(ankrBNBMkt), 0, 0);
      emit log_named_uint("Liq for account 1 before setting BC", liq); // 1366119859198693075092
      emit log_named_uint("Shortfall for account 1 before setting BC", sf); // 0
      emit log("");
      (, uint256 liq1, uint256 sf1) = pool.getHypotheticalAccountLiquidity(otherSupplier, address(ankrBNBMkt), 0, 0);
      emit log_named_uint("Liq for account 2 before setting BC", liq1); // 24108891649595017
      emit log_named_uint("Shortfall for account 2 before setting BC", sf1); // 0

      assertGt(liq, 0, "expected positive liquidity");
      assertGt(liq1, 0, "expected positive liquidity");
      emit log("");
    }
    vm.prank(pool.admin());
    asExtension._setBorrowCapForCollateral(address(ankrBNBMkt), address(ankrBNBAnkrMkt), 1);
    emit log("");
    emit log("Borrow Caps Set");
    {
      (, uint256 liqAfter, uint256 sfAfter) = pool.getHypotheticalAccountLiquidity(borrower, address(ankrBNBMkt), 0, 0);
      emit log_named_uint("Liq for account 1 after setting BC", liqAfter);
      emit log_named_uint("Shortfall for account 1 after setting BC", sfAfter);
      (, uint256 liq1After, uint256 sf1After) = pool.getHypotheticalAccountLiquidity(
        otherSupplier,
        address(ankrBNBMkt),
        0,
        0
      );
      emit log("");
      emit log_named_uint("Liq for account 2 after setting BC", liq1After);
      emit log_named_uint("Shortfall for account 2 after setting BC", sf1After);
      emit log("");

      assertGt(sfAfter, 0, "expected some shortfall for ankr");
      assertLt(liq1After, 24108891649595017, "expected liquidity for account 2 to decrease");
    }

    vm.prank(pool.admin());
    asExtension._setBorrowCapForCollateralWhitelist(address(ankrBNBMkt), address(ankrBNBAnkrMkt), borrower, true);
    emit log("");

    (, uint256 liqAfterWl, uint256 sfAfterWl) = pool.getHypotheticalAccountLiquidity(
      borrower,
      address(ankrBNBMkt),
      0,
      0
    );
    (, uint256 liq1AfterWl, uint256 sf1AfterWl) = pool.getHypotheticalAccountLiquidity(
      otherSupplier,
      address(ankrBNBMkt),
      0,
      0
    );
    assertEq(sfAfterWl, 0, "expected shortfall to go back to 0");
    assertEq(liqAfterWl, 1366119859198693075092, "expected liq to go back to original");

    // expect liq for second (not whitelisted) account to stay reduced
    assertLt(liq1AfterWl, 24108891649595017, "expected liq to go back to prev value");
  }
}
