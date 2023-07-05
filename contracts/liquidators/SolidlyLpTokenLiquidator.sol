// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../external/solidly/IRouter.sol";
import "../external/solidly/IPair.sol";
import "../oracles/default/SolidlyPriceOracle.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title SolidlyLpTokenLiquidator
 * @notice Exchanges seized Solidly LP token collateral for underlying tokens for use as a step in a liquidation.
 */
contract SolidlyLpTokenLiquidator is IRedemptionStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
   */
  function safeApprove(
    IERC20Upgradeable token,
    address to,
    uint256 minAmount
  ) internal {
    uint256 allowance = token.allowance(address(this), to);

    if (allowance < minAmount) {
      if (allowance > 0) token.safeApprove(to, 0);
      token.safeApprove(to, type(uint256).max);
    }
  }

  /**
   * @notice Redeems custom collateral `token` for an underlying token.
   * @param inputToken The input wrapped token to be redeemed for an underlying token.
   * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
   * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
   * @return outputToken The underlying ERC20 token outputted.
   * @return outputAmount The quantity of underlying tokens outputted.
   */
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    // Exit Uniswap pool
    IPair pair = IPair(address(inputToken));
    bool stable = pair.stable();

    address token0 = pair.token0();
    address token1 = pair.token1();
    pair.transfer(address(pair), inputAmount);
    (uint256 amount0, uint256 amount1) = pair.burn(address(this));

    // Swap underlying tokens
    (IRouter solidlyRouter, address tokenTo) = abi.decode(strategyData, (IRouter, address));

    if (tokenTo != token0) {
      safeApprove(IERC20Upgradeable(token0), address(solidlyRouter), amount0);
      solidlyRouter.swapExactTokensForTokensSimple(amount0, 0, token0, tokenTo, stable, address(this), block.timestamp);
    } else {
      safeApprove(IERC20Upgradeable(token1), address(solidlyRouter), amount1);
      solidlyRouter.swapExactTokensForTokensSimple(amount1, 0, token1, tokenTo, stable, address(this), block.timestamp);
    }
    // Get new collateral
    outputToken = IERC20Upgradeable(tokenTo);
    outputAmount = outputToken.balanceOf(address(this));
  }

  function name() public pure returns (string memory) {
    return "SolidlyLpTokenLiquidator";
  }
}

contract SolidlyLpTokenWrapper is IRedemptionStrategy {
  struct WrapSolidlyLpTokenVars {
    uint256 amountFor0;
    uint256 amountFor1;
    IRouter solidlyRouter;
    ERC20Upgradeable token0;
    ERC20Upgradeable token1;
    bool stable;
    IPair pair;
    IRouter.Route[] swapPath0;
    IRouter.Route[] swapPath1;
    uint256 price0;
    uint256 price1;
  }

  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    WrapSolidlyLpTokenVars memory vars;

    // calculate the amount for token0 or token1 that needs to be swapped for the other before adding the liquidity
    vars.amountFor0 = inputAmount / 2;
    vars.amountFor1 = inputAmount - vars.amountFor0;

    (vars.solidlyRouter, vars.pair, vars.swapPath0, vars.swapPath1, vars.price0, vars.price1) = abi.decode(
      strategyData,
      (IRouter, IPair, IRouter.Route[], IRouter.Route[], uint256, uint256)
    );
    vars.token0 = ERC20Upgradeable(vars.pair.token0());
    vars.token1 = ERC20Upgradeable(vars.pair.token1());
    uint256 token0Decimals = 10**vars.token0.decimals();
    uint256 token1Decimals = 10**vars.token1.decimals();

    // if the pair is not stable, then we cannot rely on the amounts to have comparable value
    // so we calculate the testing amount of token0/token1 by denominating in the other token
    vars.stable = vars.pair.stable();
    if (!vars.stable) {
      vars.price0 = (vars.price0 * 1e18) / token0Decimals;
      vars.price1 = (vars.price1 * 1e18) / token1Decimals;
      if (vars.token1 == inputToken) {
        vars.amountFor0 = (vars.amountFor0 * vars.price1) / vars.price0;
      }
      if (vars.token0 == inputToken) {
        vars.amountFor1 = (vars.amountFor1 * vars.price0) / vars.price1;
      }
    }

    // evaluate how much we would have received by swapping one for the other
    uint256 out1 = (vars.solidlyRouter.getAmountsOut(vars.amountFor0, vars.swapPath0)[vars.swapPath0.length] * 1e18) /
      token0Decimals;
    uint256 out0 = (vars.solidlyRouter.getAmountsOut(vars.amountFor1, vars.swapPath1)[vars.swapPath1.length] * 1e18) /
      token1Decimals;

    // use the comparative output amounts to check what is the actual required ratio of inputs
    (uint256 amountA, uint256 amountB, ) = vars.solidlyRouter.quoteAddLiquidity(
      address(vars.token0),
      address(vars.token1),
      vars.stable,
      out0,
      out1
    );

    amountA = (amountA * 1e18) / token0Decimals;
    amountB = (amountB * 1e18) / token1Decimals;
    uint256 ratio = (((out0 * 1e18) / out1) * amountB) / amountA;

    // recalculate the amounts to swap based on the ratio of the liquidity amounts required
    vars.amountFor0 = (inputAmount * 1e18) / (ratio + 1e18);
    vars.amountFor1 = inputAmount - vars.amountFor0;

    // swap amount of the input token for the other token
    if (vars.token0 == inputToken) {
      inputToken.approve(address(vars.solidlyRouter), vars.amountFor0);
      vars.solidlyRouter.swapExactTokensForTokens(vars.amountFor0, 0, vars.swapPath0, address(this), block.timestamp);
    }
    if (vars.token1 == inputToken) {
      inputToken.approve(address(vars.solidlyRouter), vars.amountFor1);
      vars.solidlyRouter.swapExactTokensForTokens(vars.amountFor1, 0, vars.swapPath1, address(this), block.timestamp);
    }

    // provide the liquidity
    uint256 token0Balance = vars.token0.balanceOf(address(this));
    uint256 token1Balance = vars.token1.balanceOf(address(this));
    vars.token0.approve(address(vars.solidlyRouter), token0Balance);
    vars.token1.approve(address(vars.solidlyRouter), token1Balance);
    vars.solidlyRouter.addLiquidity(
      address(vars.token0),
      address(vars.token1),
      vars.stable,
      token0Balance,
      token1Balance,
      1,
      1,
      address(this),
      block.timestamp
    );

    outputToken = IERC20Upgradeable(address(vars.pair));
    outputAmount = outputToken.balanceOf(address(this));
  }

  function name() public pure returns (string memory) {
    return "SolidlyLpTokenWrapper";
  }
}
