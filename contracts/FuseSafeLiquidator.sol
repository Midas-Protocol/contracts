// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";
import "./liquidators/JarvisLiquidatorFunder.sol";

import "./external/compound/ICToken.sol";

import "./external/compound/ICErc20.sol";
import "./external/compound/ICEther.sol";

import "./utils/IW_NATIVE.sol";

import "./external/uniswap/IUniswapV2Router02.sol";
import "./external/uniswap/IUniswapV2Callee.sol";
import "./external/uniswap/IUniswapV2Pair.sol";
import "./external/uniswap/IUniswapV2Factory.sol";
import "./external/uniswap/UniswapV2Library.sol";
import "./external/compound/IComptroller.sol";

/**
 * @title FuseSafeLiquidator
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidator safely liquidates unhealthy borrowers (with flashloan support).
 * @dev Do not transfer NATIVE or tokens directly to this address. Only send NATIVE here when using a method, and only approve tokens for transfer to here when using a method. Direct NATIVE transfers will be rejected and direct token transfers will be lost.
 */
contract FuseSafeLiquidator is OwnableUpgradeable, IUniswapV2Callee {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev W_NATIVE contract address.
   */
  address public W_NATIVE_ADDRESS;

  /**
   * @dev W_NATIVE contract object.
   */
  IW_NATIVE public W_NATIVE;

  /**
   * @dev UniswapV2Router02 contract address.
   */
  address public UNISWAP_V2_ROUTER_02_ADDRESS;

  /**
   * @dev Stable token to use for flash loans
   */
  address public STABLE_TOKEN;

  /**
   * @dev Wrapped BTC token to use for flash loans
   */
  address public BTC_TOKEN;

  /**
   * @dev Hash code of the pair used by `UNISWAP_V2_ROUTER_02`
   */
  bytes PAIR_INIT_HASH_CODE;

  /**
   * @dev UniswapV2Router02 contract object. (Is interchangable with any UniV2 forks)
   */
  IUniswapV2Router02 public UNISWAP_V2_ROUTER_02;

  /**
   * @dev Cached liquidator profit exchange source.
   * ERC20 token address or the zero address for NATIVE.
   * For use in `safeLiquidateToTokensWithFlashLoan` after it is set by `postFlashLoanTokens`.
   */
  address private _liquidatorProfitExchangeSource;

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

  /**
   * @dev Percentage of the flash swap fee, measured in basis points.
   */
  uint8 public flashSwapFee;

  function initialize(
    address _wtoken,
    address _uniswapV2router,
    address _stableToken,
    address _btcToken,
    bytes memory _uniswapPairInitHashCode,
    uint8 _flashSwapFee
  ) external initializer {
    __Ownable_init();

    require(_uniswapV2router != address(0), "UniswapV2Factory not defined.");
    W_NATIVE_ADDRESS = _wtoken;
    UNISWAP_V2_ROUTER_02_ADDRESS = _uniswapV2router;
    STABLE_TOKEN = _stableToken;
    BTC_TOKEN = _btcToken;
    W_NATIVE = IW_NATIVE(W_NATIVE_ADDRESS);
    UNISWAP_V2_ROUTER_02 = IUniswapV2Router02(UNISWAP_V2_ROUTER_02_ADDRESS);
    PAIR_INIT_HASH_CODE = _uniswapPairInitHashCode;
    flashSwapFee = _flashSwapFee;
  }

  function _becomeImplementation(bytes calldata data) external {
    uint8 _flashSwapFee = abi.decode(data, (uint8));
    if (_flashSwapFee != 0) {
      flashSwapFee = _flashSwapFee;
    } else {
      flashSwapFee = 30;
    }
  }

  /**
   * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
   */
  function safeApprove(
    IERC20Upgradeable token,
    address to,
    uint256 minAmount
  ) private {
    uint256 allowance = token.allowance(address(this), to);

    if (allowance < minAmount) {
      if (allowance > 0) token.safeApprove(to, 0);
      token.safeApprove(to, type(uint256).max);
    }
  }

  /**
   * @dev Internal function to approve
   */
  function justApprove(
    IERC20Upgradeable token,
    address to,
    uint256 amount
  ) private {
    token.approve(to, amount);
  }

  /**
   * @dev Internal function to exchange the entire balance of `from` to at least `minOutputAmount` of `to`.
   * @param from The input ERC20 token address (or the zero address if NATIVE) to exchange from.
   * @param to The output ERC20 token address (or the zero address if NATIVE) to exchange to.
   * @param minOutputAmount The minimum output amount of `to` necessary to complete the exchange without reversion.
   * @param uniswapV2Router The UniswapV2Router02 to use. (Is interchangable with any UniV2 forks)
   */
  function exchangeAllWethOrTokens(
    address from,
    address to,
    uint256 minOutputAmount,
    IUniswapV2Router02 uniswapV2Router
  ) private {
    if (to == address(0)) to = W_NATIVE_ADDRESS; // we want W_NATIVE instead of NATIVE
    if (to == from) return;

    // From NATIVE, W_NATIVE, or something else?
    if (from == address(0)) {
      if (to == W_NATIVE_ADDRESS) {
        // Deposit all NATIVE to W_NATIVE
        W_NATIVE.deposit{ value: address(this).balance }();
      } else {
        // Exchange from NATIVE to tokens
        uniswapV2Router.swapExactETHForTokens{ value: address(this).balance }(
          minOutputAmount,
          array(W_NATIVE_ADDRESS, to),
          address(this),
          block.timestamp
        );
      }
    } else {
      // Approve input tokens
      IERC20Upgradeable fromToken = IERC20Upgradeable(from);
      uint256 inputBalance = fromToken.balanceOf(address(this));
      justApprove(fromToken, address(uniswapV2Router), inputBalance);

      // TODO check if redemption strategies make this obsolete
      // Exchange from tokens to tokens
      uniswapV2Router.swapExactTokensForTokens(
        inputBalance,
        minOutputAmount,
        from == W_NATIVE_ADDRESS || to == W_NATIVE_ADDRESS ? array(from, to) : array(from, W_NATIVE_ADDRESS, to),
        address(this),
        block.timestamp
      ); // Put W_NATIVE in the middle of the path if not already a part of the path
    }
  }

  /**
   * @dev Internal function to exchange the entire balance of `from` to at least `minOutputAmount` of `to`.
   * @param from The input ERC20 token address (or the zero address if NATIVE) to exchange from.
   * @param outputAmount The output amount of NATIVE.
   * @param uniswapV2Router The UniswapV2Router02 to use. (Is interchangable with any UniV2 forks)
   */
  function exchangeToExactEth(
    address from,
    uint256 outputAmount,
    IUniswapV2Router02 uniswapV2Router
  ) private {
    if (from == address(0)) return;

    // From W_NATIVE something else?
    if (from == W_NATIVE_ADDRESS) {
      // Withdraw W_NATIVE to NATIVE
      W_NATIVE.withdraw(outputAmount);
    } else {
      // Approve input tokens
      IERC20Upgradeable fromToken = IERC20Upgradeable(from);
      uint256 inputBalance = fromToken.balanceOf(address(this));
      justApprove(fromToken, address(uniswapV2Router), inputBalance);

      // Exchange from tokens to NATIVE
      uniswapV2Router.swapTokensForExactETH(
        outputAmount,
        inputBalance,
        array(from, W_NATIVE_ADDRESS),
        address(this),
        block.timestamp
      );
    }
  }

  /**
   * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable).
   * @param borrower The borrower's Ethereum address.
   * @param repayAmount The amount to repay to liquidate the unhealthy loan.
   * @param cErc20 The borrowed cErc20 to repay.
   * @param cTokenCollateral The cToken collateral to be liquidated.
   * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
   * @param exchangeSeizedTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for NATIVE).
   * @param uniswapV2Router The UniswapV2Router to use to convert the seized underlying collateral. (Is interchangable with any UniV2 forks)
   * @param redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
   * @param strategyData The data for the chosen IRedemptionStrategy contracts, if any.
   */
  function safeLiquidate(
    address borrower,
    uint256 repayAmount,
    ICErc20 cErc20,
    ICToken cTokenCollateral,
    uint256 minOutputAmount,
    address exchangeSeizedTo,
    IUniswapV2Router02 uniswapV2Router,
    IRedemptionStrategy[] memory redemptionStrategies,
    bytes[] memory strategyData
  ) external returns (uint256) {
    // Transfer tokens in, approve to cErc20, and liquidate borrow
    require(repayAmount > 0, "Repay amount (transaction value) must be greater than 0.");
    IERC20Upgradeable underlying = IERC20Upgradeable(cErc20.underlying());
    underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
    justApprove(underlying, address(cErc20), repayAmount);
    require(cErc20.liquidateBorrow(borrower, repayAmount, cTokenCollateral) == 0, "Liquidation failed.");

    // Redeem seized cToken collateral if necessary
    if (exchangeSeizedTo != address(cTokenCollateral)) {
      uint256 seizedCTokenAmount = cTokenCollateral.balanceOf(address(this));

      if (seizedCTokenAmount > 0) {
        uint256 redeemResult = cTokenCollateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // If cTokenCollateral is CEther
        if (cTokenCollateral.isCEther()) {
          revert("not used anymore");
        } else {
          // Redeem custom collateral if liquidation strategy is set
          IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(ICErc20(address(cTokenCollateral)).underlying());

          if (redemptionStrategies.length > 0) {
            require(
              redemptionStrategies.length == strategyData.length,
              "IRedemptionStrategy contract array and strategy data bytes array must be the same length."
            );
            uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));
            for (uint256 i = 0; i < redemptionStrategies.length; i++)
              (underlyingCollateral, underlyingCollateralSeized) = redeemCustomCollateral(
                underlyingCollateral,
                underlyingCollateralSeized,
                redemptionStrategies[i],
                strategyData[i]
              );
          }

          // Exchange redeemed token collateral if necessary
          exchangeAllWethOrTokens(address(underlyingCollateral), exchangeSeizedTo, minOutputAmount, uniswapV2Router);
        }
      }
    }

    // Transfer seized amount to sender
    return transferSeizedFunds(exchangeSeizedTo, minOutputAmount);
  }

  function safeLiquidate(
    address borrower,
    ICEther cEther,
    ICErc20 cErc20Collateral,
    uint256 minOutputAmount,
    address exchangeSeizedTo,
    IUniswapV2Router02 uniswapV2Router,
    IRedemptionStrategy[] memory redemptionStrategies,
    bytes[] memory strategyData
  ) external payable returns (uint256) {
    revert("not used anymore");
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
   * exchangeProfitTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for NATIVE).
   * uniswapV2RouterForBorrow The UniswapV2Router to use to convert the NATIVE to the underlying borrow (and flashloan the underlying borrow for NATIVE). (Is interchangable with any UniV2 forks)
   * uniswapV2RouterForCollateral The UniswapV2Router to use to convert the underlying collateral to NATIVE. (Is interchangable with any UniV2 forks)
   * redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
   * strategyData The data for the chosen IRedemptionStrategy contracts, if any.
   */
  struct LiquidateToTokensWithFlashSwapVars {
    address borrower;
    uint256 repayAmount;
    ICErc20 cErc20;
    ICToken cTokenCollateral;
    IUniswapV2Pair flashSwapPair;
    uint256 minProfitAmount;
    address exchangeProfitTo;
    IUniswapV2Router02 uniswapV2RouterForBorrow;
    IUniswapV2Router02 uniswapV2RouterForCollateral;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] strategyData;
    uint256 ethToCoinbase;
    IFundsConversionStrategy[] debtFundingStrategies;
    bytes[] debtFundingStrategiesData;
  }

  /**
   * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in NATIVE profit is seized.
   * @param vars @see LiquidateToTokensWithFlashSwapVars.
   */
  function safeLiquidateToTokensWithFlashLoan(LiquidateToTokensWithFlashSwapVars calldata vars)
    external
    returns (uint256)
  {
    // Input validation
    require(vars.repayAmount > 0, "Repay amount must be greater than 0.");

    // we want to calculate the needed flashSwapAmount on-chain to
    // avoid errors due to changing market conditions
    // between the time of calculating and including the tx in a block
    uint256 flashSwapAmount = vars.repayAmount;
    IERC20Upgradeable flashSwapFundingToken = IERC20Upgradeable(ICErc20(address(vars.cErc20)).underlying());
    if (vars.debtFundingStrategies.length > 0) {
      require(
        vars.debtFundingStrategies.length == vars.debtFundingStrategiesData.length,
        "Funding IFundsConversionStrategy contract array and strategy data bytes array must be the same length."
      );
      // loop backwards to estimate the initial input from the final expected output
      for (uint256 i = vars.debtFundingStrategies.length; i > 0; i--) {
        bytes memory strategyData = vars.debtFundingStrategiesData[i - 1];
        IFundsConversionStrategy fcs = vars.debtFundingStrategies[i - 1];
        (flashSwapFundingToken, flashSwapAmount) = fcs.estimateInputAmount(flashSwapAmount, strategyData);
      }
    }

    _flashSwapAmount = flashSwapAmount;
    _flashSwapToken = address(flashSwapFundingToken);

    bool token0IsFlashSwapFundingToken = vars.flashSwapPair.token0() == address(flashSwapFundingToken);
    vars.flashSwapPair.swap(
      token0IsFlashSwapFundingToken ? flashSwapAmount : 0,
      !token0IsFlashSwapFundingToken ? flashSwapAmount : 0,
      address(this),
      msg.data
    );

    // Exchange profit, send NATIVE to coinbase if necessary, and transfer seized funds
    return distributeProfit(vars.exchangeProfitTo, vars.minProfitAmount, vars.ethToCoinbase);
  }

  function safeLiquidateToEthWithFlashLoan(
    address borrower,
    uint256 repayAmount,
    ICEther cEther,
    ICErc20 cErc20Collateral,
    uint256 minProfitAmount,
    address exchangeProfitTo,
    IUniswapV2Router02 uniswapV2RouterForCollateral,
    IRedemptionStrategy[] memory redemptionStrategies,
    bytes[] memory strategyData,
    uint256 ethToCoinbase
  ) external returns (uint256) {
    revert("not used anymore");
  }

  /**
   * Exchange profit, send NATIVE to coinbase if necessary, and transfer seized funds to sender.
   */
  function distributeProfit(
    address exchangeProfitTo,
    uint256 minProfitAmount,
    uint256 ethToCoinbase
  ) private returns (uint256) {
    if (exchangeProfitTo == address(0)) exchangeProfitTo = W_NATIVE_ADDRESS;

    // Transfer NATIVE to block.coinbase if requested
    if (ethToCoinbase > 0) {
      uint256 currentBalance = address(this).balance;
      if (ethToCoinbase > currentBalance) {
        exchangeToExactEth(_liquidatorProfitExchangeSource, ethToCoinbase - currentBalance, UNISWAP_V2_ROUTER_02);
      }
      block.coinbase.call{ value: ethToCoinbase }("");
    }

    // Exchange profit if necessary
    exchangeAllWethOrTokens(_liquidatorProfitExchangeSource, exchangeProfitTo, minProfitAmount, UNISWAP_V2_ROUTER_02);

    // Transfer profit to msg.sender
    return transferSeizedFunds(exchangeProfitTo, minProfitAmount);
  }

  /**
   * @dev Receives NATIVE from liquidations and flashloans.
   * Requires that `msg.sender` is W_NATIVE, a CToken, or a Uniswap V2 Router, or another contract.
   */
  receive() external payable {
    require(payable(msg.sender).isContract(), "Sender is not a contract.");
  }

  /**
   * @dev Callback function for Uniswap flashloans.
   */
  function uniswapV2Call(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) public override {
    address cToken = abi.decode(data[100:132], (address));

    // Liquidate unhealthy borrow, exchange seized collateral, return flashloaned funds, and exchange profit
    if (ICToken(cToken).isCEther()) {
      revert("not used anymore");
    } else {
      // Decode params
      LiquidateToTokensWithFlashSwapVars memory vars = abi.decode(data[4:], (LiquidateToTokensWithFlashSwapVars));

      // Post token flashloan
      // Cache liquidation profit token (or the zero address for NATIVE) for use as source for exchange later
      _liquidatorProfitExchangeSource = postFlashLoanTokens(vars);
    }
  }

  /**
   * @dev Callback function for PCS flashloans.
   */
  function pancakeCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external override {
    uniswapV2Call(sender, amount0, amount1, data);
  }

  /**
   * @dev Callback function for BeamSwap flashloans.
   */
  function BeamSwapCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {
    uniswapV2Call(sender, amount0, amount1, data);
  }

  function moraswapCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {
    uniswapV2Call(sender, amount0, amount1, data);
  }

  /**
   * @dev Liquidate unhealthy token borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
   */
  function postFlashLoanTokens(LiquidateToTokensWithFlashSwapVars memory vars) private returns (address) {
    IERC20Upgradeable debtRepaymentToken = IERC20Upgradeable(_flashSwapToken);
    uint256 debtRepaymentAmount = debtRepaymentToken.balanceOf(address(this));

    if (vars.debtFundingStrategies.length > 0) {
      for (uint256 i = 0; i < vars.debtFundingStrategies.length; i++)
        (debtRepaymentToken, debtRepaymentAmount) = convertCustomFunds(
          debtRepaymentToken,
          debtRepaymentAmount,
          vars.debtFundingStrategies[i],
          vars.debtFundingStrategiesData[i]
        );
    }

    // Approve the debt repayment transfer, liquidate and redeem the seized collateral
    {
      address underlyingBorrow = vars.cErc20.underlying();
      require(
        address(debtRepaymentToken) == underlyingBorrow,
        "the debt repayment funds should be converted to the underlying debt token"
      );
      require(debtRepaymentAmount >= vars.repayAmount, "debt repayment amount not enough");
      // Approve repayAmount to cErc20
      justApprove(IERC20Upgradeable(underlyingBorrow), address(vars.cErc20), vars.repayAmount);

      // Liquidate borrow
      require(
        vars.cErc20.liquidateBorrow(vars.borrower, vars.repayAmount, vars.cTokenCollateral) == 0,
        "Liquidation failed."
      );

      // Redeem seized cTokens for underlying asset
      uint256 seizedCTokenAmount = vars.cTokenCollateral.balanceOf(address(this));
      require(seizedCTokenAmount > 0, "No cTokens seized.");
      uint256 redeemResult = vars.cTokenCollateral.redeem(seizedCTokenAmount);
      require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");
    }

    // Repay flashloan
    return
      repayTokenFlashLoan(
        vars.cTokenCollateral,
        vars.exchangeProfitTo,
        vars.uniswapV2RouterForBorrow,
        vars.uniswapV2RouterForCollateral,
        vars.redemptionStrategies,
        vars.strategyData
      );
  }

  /**
   * @dev Repays token flashloans.
   */
  function repayTokenFlashLoan(
    ICToken cTokenCollateral,
    address exchangeProfitTo,
    IUniswapV2Router02 uniswapV2RouterForBorrow,
    IUniswapV2Router02 uniswapV2RouterForCollateral,
    IRedemptionStrategy[] memory redemptionStrategies,
    bytes[] memory strategyData
  ) private returns (address) {
    // Calculate flashloan return amount
    uint256 flashSwapReturnAmount = (_flashSwapAmount * 10000) / (10000 - flashSwapFee);
    if ((_flashSwapAmount * 10000) % (10000 - flashSwapFee) > 0) flashSwapReturnAmount++; // Round up if division resulted in a remainder

    // Swap cTokenCollateral for cErc20 via Uniswap
    if (cTokenCollateral.isCEther()) {
      revert("not used anymore");
    }

    // Check underlying collateral seized
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(ICErc20(address(cTokenCollateral)).underlying());
    uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

    // Redeem custom collateral if liquidation strategy is set
    if (redemptionStrategies.length > 0) {
      require(
        redemptionStrategies.length == strategyData.length,
        "IRedemptionStrategy contract array and strategy data bytes array mnust the the same length."
      );
      for (uint256 i = 0; i < redemptionStrategies.length; i++)
        (underlyingCollateral, underlyingCollateralSeized) = redeemCustomCollateral(
          underlyingCollateral,
          underlyingCollateralSeized,
          redemptionStrategies[i],
          strategyData[i]
        );
    }

    IUniswapV2Pair pair = IUniswapV2Pair(msg.sender);

    // Check if we can repay directly one of the sides with collateral
    if (address(underlyingCollateral) == pair.token0() || address(underlyingCollateral) == pair.token1()) {
      // Repay flashloan directly with collateral
      uint256 collateralRequired;
      if (address(underlyingCollateral) == _flashSwapToken) {
        // repay amount for the borrow side
        collateralRequired = flashSwapReturnAmount;
      } else {
        // repay amount for the non-borrow side
        collateralRequired = UniswapV2Library.getAmountsIn(
          uniswapV2RouterForBorrow.factory(),
          _flashSwapAmount, //flashSwapReturnAmount,
          array(address(underlyingCollateral), _flashSwapToken),
          flashSwapFee
        )[0];
      }

      // Repay flashloan
      require(
        collateralRequired <= underlyingCollateralSeized,
        "Token flashloan return amount greater than seized collateral."
      );
      require(
        underlyingCollateral.transfer(msg.sender, collateralRequired),
        "Failed to repay token flashloan on borrow side."
      );

      return address(underlyingCollateral);
    } else {
      // exchange the collateral to W_NATIVE to repay the borrow side
      uint256 wethRequired;
      if (_flashSwapToken == W_NATIVE_ADDRESS) {
        wethRequired = flashSwapReturnAmount;
      } else {
        // Get W_NATIVE required to repay flashloan
        wethRequired = UniswapV2Library.getAmountsIn(
          uniswapV2RouterForBorrow.factory(),
          flashSwapReturnAmount,
          array(W_NATIVE_ADDRESS, _flashSwapToken),
          flashSwapFee
        )[0];
      }

      if (address(underlyingCollateral) != W_NATIVE_ADDRESS) {
        // Approve to Uniswap router
        justApprove(underlyingCollateral, address(uniswapV2RouterForCollateral), underlyingCollateralSeized);

        // Swap collateral tokens for W_NATIVE to be repaid via Uniswap router
        if (exchangeProfitTo == address(underlyingCollateral))
          uniswapV2RouterForCollateral.swapTokensForExactTokens(
            wethRequired,
            underlyingCollateralSeized,
            array(address(underlyingCollateral), W_NATIVE_ADDRESS),
            address(this),
            block.timestamp
          );
        else
          uniswapV2RouterForCollateral.swapExactTokensForTokens(
            underlyingCollateralSeized,
            wethRequired,
            array(address(underlyingCollateral), W_NATIVE_ADDRESS),
            address(this),
            block.timestamp
          );
      }

      // Repay flashloan
      require(
        wethRequired <= IERC20Upgradeable(W_NATIVE_ADDRESS).balanceOf(address(this)),
        "Not enough W_NATIVE exchanged from seized collateral to repay flashloan."
      );
      require(
        W_NATIVE.transfer(msg.sender, wethRequired),
        "Failed to repay Uniswap flashloan with W_NATIVE exchanged from seized collateral."
      );

      // Return the profited token (underlying collateral if same as exchangeProfitTo; otherwise, W_NATIVE)
      return exchangeProfitTo == address(underlyingCollateral) ? address(underlyingCollateral) : W_NATIVE_ADDRESS;
    }
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
  function _whitelistRedemptionStrategies(IRedemptionStrategy[] calldata strategies, bool[] calldata whitelisted)
    external
    onlyOwner
  {
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

  function convertCustomFunds(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IFundsConversionStrategy strategy,
    bytes memory strategyData
  ) public returns (IERC20Upgradeable, uint256) {
    require(redemptionStrategiesWhitelist[address(strategy)], "only whitelisted redemption strategies can be used");

    bytes memory returndata = _functionDelegateCall(
      address(strategy),
      abi.encodeWithSelector(strategy.convert.selector, inputToken, inputAmount, strategyData)
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
