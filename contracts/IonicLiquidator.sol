// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";

import "./external/uniswap/IUniswapV2Pair.sol";

import { ICErc20 } from "./compound/CTokenInterfaces.sol";

/**
 * @title FuseSafeLiquidator
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidator safely liquidates unhealthy borrowers (with flashloan support).
 * @dev Do not transfer NATIVE or tokens directly to this address. Only send NATIVE here when using a method, and only approve tokens for transfer to here when using a method. Direct NATIVE transfers will be rejected and direct token transfers will be lost.
 */
contract FuseSafeLiquidator is OwnableUpgradeable {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  mapping(address => bool) public redemptionStrategiesWhitelist;

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

  function initialize() external initializer {
    __Ownable_init();
  }

  function _becomeImplementation(bytes calldata data) external {}

  /**
   * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
   */
  function safeApprove(IERC20Upgradeable token, address to, uint256 minAmount) private {
    uint256 allowance = token.allowance(address(this), to);

    if (allowance < minAmount) {
      if (allowance > 0) token.safeApprove(to, 0);
      token.safeApprove(to, type(uint256).max);
    }
  }

  /**
   * @dev Internal function to approve
   */
  function justApprove(IERC20Upgradeable token, address to, uint256 amount) private {
    token.approve(to, amount);
  }

  /**
   * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable).
   * @param borrower The borrower's Ethereum address.
   * @param repayAmount The amount to repay to liquidate the unhealthy loan.
   * @param cErc20 The borrowed cErc20 to repay.
   * @param cTokenCollateral The cToken collateral to be liquidated.
   * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
   */
  function safeLiquidate(
    address borrower,
    uint256 repayAmount,
    ICErc20 cErc20,
    ICErc20 cTokenCollateral,
    uint256 minOutputAmount
  ) external returns (uint256) {
    // Transfer tokens in, approve to cErc20, and liquidate borrow
    require(repayAmount > 0, "Repay amount (transaction value) must be greater than 0.");
    IERC20Upgradeable underlying = IERC20Upgradeable(cErc20.underlying());
    underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
    justApprove(underlying, address(cErc20), repayAmount);
    require(cErc20.liquidateBorrow(borrower, repayAmount, address(cTokenCollateral)) == 0, "Liquidation failed.");
    // Transfer seized amount to sender
    return transferSeizedFunds(address(cTokenCollateral), minOutputAmount);
  }

  /**
   * @dev Transfers seized funds to the sender.
   * @param erc20Contract The address of the token to transfer.
   * @param minOutputAmount The minimum amount to transfer.
   */
  function transferSeizedFunds(address erc20Contract, uint256 minOutputAmount) internal returns (uint256) {
    IERC20Upgradeable token = IERC20Upgradeable(erc20Contract);
    uint256 seizedOutputAmount = token.balanceOf(address(this));
    require(seizedOutputAmount >= minOutputAmount, "Minimum token output amount not satified.");
    if (seizedOutputAmount > 0) token.safeTransfer(msg.sender, seizedOutputAmount);

    return seizedOutputAmount;
  }

  /**
   * borrower The borrower's Ethereum address.
   * repayAmount The amount to repay to liquidate the unhealthy loan.
   * cErc20 The borrowed CErc20 contract to repay.
   * cTokenCollateral The cToken collateral contract to be liquidated.
   * minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
   * redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
   * strategyData The data for the chosen IRedemptionStrategy contracts, if any.
   */
  struct LiquidateToTokensWithFlashSwapVars {
    address borrower;
    uint256 repayAmount;
    ICErc20 cErc20;
    ICErc20 cTokenCollateral;
    IUniswapV2Pair flashSwapPair;
    uint256 minProfitAmount;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] strategyData;
    IFundsConversionStrategy[] debtFundingStrategies;
    bytes[] debtFundingStrategiesData;
  }

  /**
   * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in NATIVE profit is seized.
   * @param vars @see LiquidateToTokensWithFlashSwapVars.
   */
  function safeLiquidateToTokensWithFlashLoan(
    LiquidateToTokensWithFlashSwapVars calldata vars
  ) external returns (uint256) {
    // Input validation
    require(vars.repayAmount > 0, "Repay amount must be greater than 0.");

    // we want to calculate the needed flashSwapAmount on-chain to
    // avoid errors due to changing market conditions
    // between the time of calculating and including the tx in a block
    uint256 fundingAmount = vars.repayAmount;
    IERC20Upgradeable fundingToken;
    if (vars.debtFundingStrategies.length > 0) {
      require(
        vars.debtFundingStrategies.length == vars.debtFundingStrategiesData.length,
        "Funding IFundsConversionStrategy contract array and strategy data bytes array must be the same length."
      );
      // estimate the initial (flash-swapped token) input from the expected output (debt token)
      for (uint256 i = 0; i < vars.debtFundingStrategies.length; i++) {
        bytes memory strategyData = vars.debtFundingStrategiesData[i];
        IFundsConversionStrategy fcs = vars.debtFundingStrategies[i];
        (fundingToken, fundingAmount) = fcs.estimateInputAmount(fundingAmount, strategyData);
      }
    } else {
      fundingToken = IERC20Upgradeable(ICErc20(address(vars.cErc20)).underlying());
    }

    // the last outputs from estimateInputAmount are the ones to be flash-swapped
    _flashSwapAmount = fundingAmount;
    _flashSwapToken = address(fundingToken);

    bool token0IsFlashSwapFundingToken = vars.flashSwapPair.token0() == address(fundingToken);
    vars.flashSwapPair.swap(
      token0IsFlashSwapFundingToken ? fundingAmount : 0,
      !token0IsFlashSwapFundingToken ? fundingAmount : 0,
      address(this),
      msg.data
    );

    return transferSeizedFunds(address(vars.cTokenCollateral), vars.minProfitAmount);
  }

  /**
   * @dev Receives NATIVE from liquidations and flashloans.
   * Requires that `msg.sender` is W_NATIVE, a CToken, or a Uniswap V2 Router, or another contract.
   */
  receive() external payable {
    require(payable(msg.sender).isContract(), "Sender is not a contract.");
  }

  /**
   * @dev for security reasons only whitelisted redemption strategies may be used.
   * Each whitelisted redemption strategy has to be checked to not be able to
   * call `selfdestruct` with the `delegatecall` call in `redeemCustomCollateral`
   */
  function _whitelistRedemptionStrategy(IRedemptionStrategy strategy, bool whitelisted) external onlyOwner {
    redemptionStrategiesWhitelist[address(strategy)] = whitelisted;
  }

  /**
   * @dev for security reasons only whitelisted redemption strategies may be used.
   * Each whitelisted redemption strategy has to be checked to not be able to
   * call `selfdestruct` with the `delegatecall` call in `redeemCustomCollateral`
   */
  function _whitelistRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    bool[] calldata whitelisted
  ) external onlyOwner {
    require(
      strategies.length > 0 && strategies.length == whitelisted.length,
      "list of strategies empty or whitelist does not match its length"
    );

    for (uint256 i = 0; i < strategies.length; i++) {
      redemptionStrategiesWhitelist[address(strategies[i])] = whitelisted[i];
    }
  }

  /**
   * @dev Redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
   * Public visibility because we have to call this function externally if called from a payable FuseSafeLiquidator function (for some reason delegatecall fails when called with msg.value > 0).
   */
  function redeemCustomCollateral(
    IERC20Upgradeable underlyingCollateral,
    uint256 underlyingCollateralSeized,
    IRedemptionStrategy strategy,
    bytes memory strategyData
  ) public returns (IERC20Upgradeable, uint256) {
    require(redemptionStrategiesWhitelist[address(strategy)], "only whitelisted redemption strategies can be used");

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

  /**
   * @dev Returns an array containing the parameters supplied.
   */
  function array(uint256 a) private pure returns (uint256[] memory) {
    uint256[] memory arr = new uint256[](1);
    arr[0] = a;
    return arr;
  }

  /**
   * @dev Returns an array containing the parameters supplied.
   */
  function array(address a) private pure returns (address[] memory) {
    address[] memory arr = new address[](1);
    arr[0] = a;
    return arr;
  }

  /**
   * @dev Returns an array containing the parameters supplied.
   */
  function array(address a, address b) private pure returns (address[] memory) {
    address[] memory arr = new address[](2);
    arr[0] = a;
    arr[1] = b;
    return arr;
  }

  /**
   * @dev Returns an array containing the parameters supplied.
   */
  function array(address a, address b, address c) private pure returns (address[] memory) {
    address[] memory arr = new address[](3);
    arr[0] = a;
    arr[1] = b;
    arr[2] = c;
    return arr;
  }
}
