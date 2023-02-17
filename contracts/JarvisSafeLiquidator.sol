// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./midas/SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";
import "./liquidators/JarvisLiquidatorFunder.sol";
import "./liquidators/UniswapV2Liquidator.sol";
import "./liquidators/UniswapLpTokenLiquidator.sol";
import "./liquidators/CurveLpTokenLiquidatorNoRegistry.sol";

import "./midas/AddressesProvider.sol";

import "./external/compound/ICToken.sol";
import "./external/compound/IComptroller.sol";

import "./external/compound/ICErc20.sol";
import "./external/compound/ICEther.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract JarvisSafeLiquidator is SafeOwnableUpgradeable {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // just in case
  uint256[99] private __gap;

  mapping(address => uint256) public marketCTokensTotalSupply;
  mapping(address => uint256) public valueOwedToMarket;
  mapping(address => uint256) public usdcRedeemed;
  uint256 public totalUsdcSeized;
  uint256 public totalValueOwedToMarkets;
  address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

  function initialize() external initializer {
    __SafeOwnable_init();
  }

  struct LiquidateJarvisDebtVars {
    address borrower;
    uint256 repayAmount;
    ICErc20 debtMarket;
    ICErc20 collateralMarket;
    uint256 fundingAmount;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] redemptionStrategiesData;
  }

  function liquidateJarvisDebt(LiquidateJarvisDebtVars calldata vars) external returns (uint256) {
    // Input validation
    require(vars.repayAmount > 0, "Repay amount must be greater than 0.");
    require(msg.sender == 0x19F2bfCA57FDc1B7406337391d2F54063CaE8748, "!liquidator");

    /**
      1. flash loan a pool asset - WETH
      2. supply the WETH in the pool
      3. borrow as much as the repay amount from the debt market
      4. liquidate
      5. keep the collateral and repay the flashloan with the initially borrowed WETH
    **/

    IComptroller pool = IComptroller(vars.collateralMarket.comptroller());
    pool.enterMarkets(array(address(vars.collateralMarket), address(vars.debtMarket)));

    // borrow the debt asset
    require(vars.debtMarket.borrow(vars.repayAmount) == 0, "!borrow debt asset");

    address underlyingBorrow = vars.debtMarket.underlying();
    IERC20Upgradeable(underlyingBorrow).approve(address(vars.debtMarket), vars.repayAmount);

    // Liquidate borrow
    require(
      vars.debtMarket.liquidateBorrow(vars.borrower, vars.repayAmount, vars.collateralMarket) == 0,
      "Liquidation failed."
    );

    // Redeem seized cTokens for underlying asset
    uint256 seizedCTokenAmount = vars.collateralMarket.balanceOf(address(this));
    require(seizedCTokenAmount > 0, "No cTokens seized.");

    //    // transfer the main part of the borrower collateral to the liquidator
    //    vars.collateralMarket.transfer(
    //      0x19F2bfCA57FDc1B7406337391d2F54063CaE8748,
    //      seizedCTokenAmount
    //    );

    return 0;
  }

  function redistributeCollateral() public returns (IERC20Upgradeable[] memory) {
    require(msg.sender == 0x19F2bfCA57FDc1B7406337391d2F54063CaE8748, "!liquidator");
    require(totalUsdcSeized == 0, "twice");

    IERC20Upgradeable[] memory collateralTokens = redeemAllCollateral();

    address jPoolAddress = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;
    IComptroller jpool = IComptroller(jPoolAddress);
    ICToken[] memory markets = jpool.getAllMarkets();
    IPriceOracle oracle = jpool.oracle();

    uint256 totalOwedValue = 0;
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(address(markets[i]));
      uint256 underlyingOwed = market.borrowBalanceCurrent(address(this));
      uint256 price = oracle.getUnderlyingPrice(market);
      uint256 underlyingOwedValue = (price * underlyingOwed) / 1e18;
      valueOwedToMarket[address(market)] = underlyingOwedValue;
      totalOwedValue += underlyingOwedValue;
      marketCTokensTotalSupply[address(market)] = market.totalSupply();
    }

    totalValueOwedToMarkets = totalOwedValue;
    totalUsdcSeized = IERC20Upgradeable(usdc).balanceOf(address(this));

    return collateralTokens;
  }

  function reimburseRedeemer(
    address redeemer,
    address market,
    uint256 redeemTokens
  ) public {
    address jPoolAddress = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;
    require(msg.sender == jPoolAddress, "!jpool");

    uint256 marketShareOfCollateral = (valueOwedToMarket[market] * 1e18) / totalValueOwedToMarkets;
    uint256 redeemerShareOfMarket = (redeemTokens * 1e18) / marketCTokensTotalSupply[market];

    uint256 usdcForMarket = (marketShareOfCollateral * totalUsdcSeized) / 1e18;
    uint256 amount = (redeemerShareOfMarket * usdcForMarket) / 1e18;
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(usdc), redeemer, amount);
  }

  function redeemAllCollateral() internal returns (IERC20Upgradeable[] memory) {
    require(msg.sender == 0x19F2bfCA57FDc1B7406337391d2F54063CaE8748, "!liquidator");

    address jPoolAddress = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;
    IComptroller jpool = IComptroller(jPoolAddress);
    ICToken[] memory markets = jpool.getAllMarkets();
    IERC20Upgradeable[] memory outputTokens = new IERC20Upgradeable[](markets.length);

    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(address(markets[i]));
      uint256 underlyingBalance = market.balanceOfUnderlying(address(this));
      if (underlyingBalance > 0) {
        require(jpool.exitMarket(address(market)) == 0, "exit");
        require(market.redeemUnderlying(type(uint256).max) == 0, "redeem coll");
        uint256 borrows = market.borrowBalanceCurrent(address(this));
        if (borrows > 0) {
          uint256 repayAmount = 0;
          if (borrows < underlyingBalance) {
            repayAmount = borrows;
          } else {
            repayAmount = underlyingBalance;
          }
          IERC20Upgradeable(market.underlying()).approve(address(market), repayAmount);
          require(market.repayBorrow(repayAmount) == 0, "!repay");
        }
        outputTokens[i] = redeemCollateral(market);
      }
    }

    return outputTokens;
  }

  function redeemCollateral(ICErc20 collateralMarket) internal returns (IERC20Upgradeable) {
    address underlyingAddress = collateralMarket.underlying();
    IERC20Upgradeable underlying = IERC20Upgradeable(underlyingAddress);
    uint256 jslBalance = underlying.balanceOf(address(this));
    if (jslBalance > 0) {
      address mai = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;
      address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
      address jarvisPool = getPoolAddress(underlyingAddress);
      if (jarvisPool != address(0)) {
        JarvisLiquidatorFunder jlf = JarvisLiquidatorFunder(0xaC64c0391a54Eba34E23429847986D437bE82da0);
        (IERC20Upgradeable outputToken, ) = redeemCustomCollateral(
          underlying,
          jslBalance,
          jlf,
          abi.encode(underlying, jarvisPool, 0)
        );
        return outputToken;
      } else if (underlyingAddress == 0x160532D2536175d65C03B97b0630A9802c274daD) {
        // uni v2 mai/usdc pair -> usdc
        address quickSwapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        UniswapLpTokenLiquidator uniLPLiq = UniswapLpTokenLiquidator(0xB22Fb94b0da976c2c16E2F9a581dB9282E204c01);
        address[] memory swapPath0 = new address[](0);
        address[] memory swapPath1 = new address[](2);
        swapPath1[0] = mai;
        swapPath1[1] = usdc;
        (IERC20Upgradeable outputToken, ) = redeemCustomCollateral(
          underlying,
          jslBalance,
          uniLPLiq,
          abi.encode(quickSwapRouter, swapPath0, swapPath1)
        );
        return outputToken;
      } else if (underlyingAddress == 0xaA91CDD7abb47F821Cf07a2d38Cc8668DEAf1bdc) {
        // 2jpy -> jjpy -> usdc
        ICurvePool curvePool = ICurvePool(underlyingAddress);
        curvePool.remove_liquidity_one_coin(jslBalance, 0, 1);
        IERC20Upgradeable jjpy = IERC20Upgradeable(0x8343091F2499FD4b6174A46D067A920a3b851FF9);
        address jarvisPool = getPoolAddress(0x8343091F2499FD4b6174A46D067A920a3b851FF9);
        if (jarvisPool != address(0)) {
          JarvisLiquidatorFunder jlf = JarvisLiquidatorFunder(0xaC64c0391a54Eba34E23429847986D437bE82da0);
          (IERC20Upgradeable outputToken, ) = redeemCustomCollateral(
            jjpy,
            jjpy.balanceOf(address(this)),
            jlf,
            abi.encode(address(0), jarvisPool, 0)
          );
          return outputToken;
        }
      } else if (underlyingAddress == 0x2C3cc8e698890271c8141be9F6fD6243d56B39f1) {
        // 2eur -> jeur -> repaid
        ICurvePool curvePool = ICurvePool(underlyingAddress);
        curvePool.remove_liquidity_one_coin(jslBalance, 1, 1);
        IERC20Upgradeable jeur = IERC20Upgradeable(0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c);
        address jarvisPool = getPoolAddress(0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c);
        if (jarvisPool != address(0)) {
          JarvisLiquidatorFunder jlf = JarvisLiquidatorFunder(0xaC64c0391a54Eba34E23429847986D437bE82da0);
          (IERC20Upgradeable outputToken, ) = redeemCustomCollateral(
            jeur,
            jeur.balanceOf(address(this)),
            jlf,
            abi.encode(address(0), jarvisPool, 0)
          );
          return outputToken;
        }
      } else if (underlyingAddress == 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1) {
        // mai -> usdc
        address quickSwapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        UniswapV2Liquidator univ2liq = UniswapV2Liquidator(0xd0CE13FD52b4bE9e375EAEf5B2d4F6dB207c0E90);
        address[] memory swapPath = new address[](2);
        swapPath[0] = mai;
        swapPath[1] = usdc;
        (IERC20Upgradeable outputToken, ) = redeemCustomCollateral(
          underlying,
          jslBalance,
          univ2liq,
          abi.encode(quickSwapRouter, swapPath)
        );
        return outputToken;
      } else {
        return underlying;
      }
    }

    return IERC20Upgradeable(address(0));
  }

  function getPoolAddress(address token) internal returns (address) {
    AddressesProvider ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
    for (uint256 i = 0; i < pools.length; i++) {
      if (token == pools[i].syntheticToken) return pools[i].liquidityPool;
    }

    return address(0);
  }

  function redeemCustomCollateral(
    IERC20Upgradeable underlyingCollateral,
    uint256 underlyingCollateralSeized,
    IRedemptionStrategy strategy,
    bytes memory strategyData
  ) public returns (IERC20Upgradeable, uint256) {
    bytes memory returndata = _functionDelegateCall(
      address(strategy),
      abi.encodeWithSelector(strategy.redeem.selector, underlyingCollateral, underlyingCollateralSeized, strategyData)
    );
    return abi.decode(returndata, (IERC20Upgradeable, uint256));
  }

  /**
   * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`], but performing a delegate call.
   * Copied from https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/contracts/blob/cb4774ace1cb84f2662fa47c573780aab937628b/contracts/utils/MulticallUpgradeable.sol#L37
   */
  function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
    require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.delegatecall(data);
    return _verifyCallResult(success, returndata, "Address: low-level delegate call failed");
  }

  /**
   * @dev Used by `_functionDelegateCall` to verify the result of a delegate call.
   * Copied from https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/contracts/blob/cb4774ace1cb84f2662fa47c573780aab937628b/contracts/utils/MulticallUpgradeable.sol#L45
   */
  function _verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) private pure returns (bytes memory) {
    if (success) {
      return returndata;
    } else {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }
  }


  function array(address a, address b) private pure returns (address[] memory) {
    address[] memory arr = new address[](2);
    arr[0] = a;
    arr[1] = b;
    return arr;
  }

  /**
   * @dev Returns an array containing the parameters supplied.
   */
  function array(
    address a,
    address b,
    address c
  ) private pure returns (address[] memory) {
    address[] memory arr = new address[](3);
    arr[0] = a;
    arr[1] = b;
    arr[2] = c;
    return arr;
  }
}
