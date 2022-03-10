// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../external/compound/ICToken.sol";
import "../keydonix/UniswapOracle.sol";

interface IKeydonixUniswapTwapPriceOracle {
  event PriceAlreadyVerified(address indexed underlying, uint256 price, uint256 block);
  event PriceVerified(address indexed underlying, uint256 price, uint256 block);

  function verifyPrice(ICToken cToken, UniswapOracle.ProofData calldata proofData) external returns (uint256, uint256);

  function verifyPriceUnderlying(address underlying, UniswapOracle.ProofData calldata proofData) external returns (uint256, uint256);
}
