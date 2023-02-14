// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./midas/SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";
import "./liquidators/JarvisLiquidatorFunder.sol";
import "./midas/AddressesProvider.sol";

import "./external/compound/ICToken.sol";
import "./external/compound/IComptroller.sol";

import "./external/compound/ICErc20.sol";
import "./external/compound/ICEther.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract JarvisSafeLiquidator is SafeOwnableUpgradeable {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

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

    //    /**
    //      1. flash loan a pool asset - WETH
    //      2. supply the WETH in the pool
    //      3. borrow as much as the repay amount from the debt market
    //      4. liquidate
    //      5. keep the collateral and repay the flashloan with the initially borrowed WETH
    //    **/

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

  function redeemAllCollateral() public {
    address jPoolAddress = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;
    IComptroller jpool = IComptroller(jPoolAddress);
    ICToken[] memory markets = jpool.getAllMarkets();
    for(uint i = 0; i < markets.length; i++) {
      redeemCollateral(ICErc20(address(markets[i])));
    }
  }

  function redeemCollateral(ICErc20 collateralMarket) public {
    require(msg.sender == 0x19F2bfCA57FDc1B7406337391d2F54063CaE8748, "!liquidator");

    address underlyingAddress = collateralMarket.underlying();
    IERC20Upgradeable underlying = IERC20Upgradeable(underlyingAddress);
    uint256 jslBalance = underlying.balanceOf(address(this));
    JarvisLiquidatorFunder jlf = JarvisLiquidatorFunder(0xaC64c0391a54Eba34E23429847986D437bE82da0);
    redeemCustomCollateral(underlying, jslBalance, jlf, abi.encode(underlying, getPoolAddress(underlyingAddress), 0));
  }

  function getPoolAddress(address token) internal returns (address) {
    AddressesProvider ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
    for (uint i = 0; i < pools.length; i++) {
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
