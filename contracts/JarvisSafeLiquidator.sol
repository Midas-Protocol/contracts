// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./midas/SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";

import "./external/compound/ICToken.sol";
import "./external/compound/IComptroller.sol";

import "./external/compound/ICErc20.sol";
import "./external/compound/ICEther.sol";

import "./external/uniswap/IUniswapV2Router02.sol";
import "./external/uniswap/IUniswapV2Pair.sol";
import "./external/uniswap/IUniswapV2Factory.sol";
import "./external/uniswap/UniswapV2Library.sol";

contract JarvisSafeLiquidator is SafeOwnableUpgradeable {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev Cached liquidator profit exchange source.
   * ERC20 token address or the zero address for NATIVE.
   * For use in `safeLiquidateToTokensWithFlashLoan` after it is set by `postFlashLoanTokens`.
   */
  address private _liquidatorProfitExchangeSource;

  /**
   * @dev Cached flash swap amount.
   * For use in `repayTokenFlashLoan` after it is set by `safeLiquidateToTokensWithFlashLoan`.
   */
  uint256 private _flashSwapAmount;

  /**
   * @dev Cached flash swap token.
   * For use in `repayTokenFlashLoan` after it is set by `safeLiquidateToTokensWithFlashLoan`.
   */
  address private _flashSwapToken;

  /**
   * @dev Percentage of the flash swap fee, measured in basis points.
   */
  uint8 public flashSwapFee;

  function initialize() external initializer {
    __SafeOwnable_init();
    flashSwapFee = 30; // sushiswap - 0.3% swap fee
  }

  /**
   * @dev Receives NATIVE from liquidations and flashloans.
   * Requires that `msg.sender` is W_NATIVE, a CToken, or a Uniswap V2 Router, or another contract.
   */
  receive() external payable {
    require(payable(msg.sender).isContract(), "Sender is not a contract.");
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

    //    /**
    //      1. flash loan a pool asset - WETH
    //      2. supply the WETH in the pool
    //      3. borrow as much as the repay amount from the debt market
    //      4. liquidate
    //      5. keep the collateral and repay the flashloan with the initially borrowed WETH
    //    **/

    _flashSwapToken = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // WETH
    _flashSwapAmount = vars.fundingAmount;
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(0xc4e595acDD7d12feC385E5dA5D43160e8A0bAC0E); // sushi WETH-WMATIC
    bool token0IsFlashSwapFundingToken = flashSwapPair.token0() == _flashSwapToken;
    flashSwapPair.swap(
      token0IsFlashSwapFundingToken ? _flashSwapAmount : 0,
      !token0IsFlashSwapFundingToken ? _flashSwapAmount : 0,
      address(this),
      msg.data
    );

    // Transfer profit to msg.sender
    return transferSeizedFunds();
  }

  /**
   * @dev Transfers seized funds to the sender.
   */
  function transferSeizedFunds() internal returns (uint256) {
    IERC20Upgradeable token = IERC20Upgradeable(_liquidatorProfitExchangeSource);
    uint256 seizedOutputAmount = token.balanceOf(address(this));
    require(seizedOutputAmount >= 1, "Minimum token output amount not satisfied.");
    if (seizedOutputAmount > 0) token.safeTransfer(msg.sender, seizedOutputAmount);

    return seizedOutputAmount;
  }

  /**
   * @dev Callback function for Uniswap flashloans.
   */
  function uniswapV2Call(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) public {
    // Decode params
    LiquidateJarvisDebtVars memory vars = abi.decode(data[4:], (LiquidateJarvisDebtVars));

    // Post token flashloan
    // Cache liquidation profit token (or the zero address for NATIVE) for use as source for exchange later
    _liquidatorProfitExchangeSource = postFlashLoanTokens(vars);
  }

  function postFlashLoanTokens(LiquidateJarvisDebtVars memory vars) private returns (address) {
    // supply the collateral
    address jarvisWethMarketAddress = 0xc62D6B6539e7f828caa4798E282903c83948FA79;
    ICErc20 jarvisWethMarket = ICErc20(jarvisWethMarketAddress);
    IERC20Upgradeable weth = IERC20Upgradeable(jarvisWethMarket.underlying());
    weth.approve(jarvisWethMarketAddress, vars.fundingAmount);
    require(jarvisWethMarket.mint(vars.fundingAmount) == 0, "!mint stable asset");

    IComptroller pool = IComptroller(jarvisWethMarket.comptroller());
    pool.enterMarkets(array(jarvisWethMarketAddress, address(vars.collateralMarket), address(vars.debtMarket)));

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

    // redeem the WETH collateral
    uint256 redeemResult = jarvisWethMarket.redeem(vars.fundingAmount);
    require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

    // Repay flashloan
    return repayTokenFlashLoan(vars.collateralMarket, vars.redemptionStrategies, vars.redemptionStrategiesData);
  }

  /**
   * @dev Repays token flashloans.
   */
  function repayTokenFlashLoan(
    ICToken cTokenCollateral,
    IRedemptionStrategy[] memory redemptionStrategies,
    bytes[] memory strategyData
  ) private returns (address) {
    // Calculate flashloan return amount
    uint256 flashSwapReturnAmount = (_flashSwapAmount * 10000) / (10000 - flashSwapFee);
    if ((_flashSwapAmount * 10000) % (10000 - flashSwapFee) > 0) flashSwapReturnAmount++; // Round up if division resulted in a remainder
    uint256 feeToRepay = flashSwapReturnAmount - _flashSwapAmount;

    // Check underlying collateral seized
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(ICErc20(address(cTokenCollateral)).underlying());
    uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));
    uint256 collateralForFee = (underlyingCollateralSeized * 4) / 100; // 4 % is the incentive

    // transfer the main part of the borrower collateral to the liquidator
    underlyingCollateral.transfer(
      0x19F2bfCA57FDc1B7406337391d2F54063CaE8748,
      underlyingCollateralSeized - collateralForFee
    );

    // Redeem the remaining 4% to repay the flash loan fee
    if (redemptionStrategies.length > 0) {
      require(redemptionStrategies.length == strategyData.length, "!redemptionStrategies strategyData len");
      for (uint256 i = 0; i < redemptionStrategies.length; i++)
        (underlyingCollateral, collateralForFee) = redeemCustomCollateral(
          underlyingCollateral,
          collateralForFee,
          redemptionStrategies[i],
          strategyData[i]
        );
    }

    // at this point underlyingCollateral should be WMATIC
    //    IUniswapV2Pair pair = IUniswapV2Pair(msg.sender);
    //    if (address(underlyingCollateral) == pair.token0() || address(underlyingCollateral) == pair.token1()) {
    //    } else {
    //      revert("underlying collateral should be WMATIC");
    //    }

    // calculate the WMATIC needed to pay for the FL fee
    uint256 collateralRequired = UniswapV2Library.getAmountsIn(
      0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // sushiswap factory
      feeToRepay,
      array(address(underlyingCollateral), _flashSwapToken),
      flashSwapFee
    )[0];

    // Repay flashloan
    require(collateralRequired <= collateralForFee, "Token flashloan return amount greater than seized collateral.");

    // repay the flash loaned WETH
    require(
      IERC20Upgradeable(_flashSwapToken).transfer(msg.sender, _flashSwapAmount),
      "Failed to repay token flashloan on the borrow side."
    );

    // pay the FL fee in WMATIC
    require(
      underlyingCollateral.transfer(msg.sender, collateralRequired),
      "Failed to repay token flashloan on the non-borrow side."
    );

    return address(underlyingCollateral);
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
