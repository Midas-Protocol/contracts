// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface ISynthereumLiquidityPool {
  struct RedeemParams {
    // Amount of synthetic tokens that user wants to use for redeeming
    uint256 numTokens;
    // Minimium amount of collateral that user wants to redeem (anti-slippage)
    uint256 minCollateral;
    // Expiration time of the transaction
    uint256 expiration;
    // Address to which send collateral tokens redeemed
    address recipient;
  }

  /**
  * The redeem operation allows you to burn synthetic fiat in exchange for the underlying collateral based on the current price.
  * For BSC this collateral is bUSD, while for GnosisChain it is wXDAI.
  * The first parameter is numTokens
  *   This is the amount of synthetic tokens that the user wants to burn in order to unlock the underlying collateral.
  * The second parameter is minCollateral
  *   This value can be passed as 0 or it can be used as an anti-slippage measure. In order to use it as anti-slippage
  *    measure you should calculate the amount of collateral that will be unlocked by using the latest Chainlink price
  *    feed and accounting for the fees paid for the protocol.
  *    You can use the following formula:
  *       (numTokens * price) - (feePercentage * (numTokens * price))
  * The third parameter is expiration
  *   This is an epoch timestamp and we suggest to pass a timestamp at least 30 minutes in the future to account for
  *   network congestions etc.
  * The fourth parameter is recipient
  *   Here you can pass either the user address that is interacting with the protocol or someone else as a recipient
  *    of the synthetic tokens minted.
  */
  function redeem(RedeemParams calldata params) external returns (uint256 collateralRedeemed, uint256 feePaid);

  /**
  * Passing an input of syntheticTokens value to this function it will return the amount of collateral that the
  * user will be unlocking and also the amount of fee that will be paid. You can use that function to populate
  * the minCollateral parameter in the redeem() function call.
  */
  function getRedeemTradeInfo(uint256 syntheticTokens) external returns (uint256 collateralRedeemed, uint256 feePaid);
}
