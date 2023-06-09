// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../compound/CTokenInterfaces.sol";
import "../keydonix/UniswapOracle.sol";

interface IKeydonixUniswapTwapPriceOracle {
  function verifyPrice(ICErc20 cToken, UniswapOracle.ProofData calldata proofData) external returns (uint256, uint256);

  event PriceAlreadyVerified(address indexed cToken, uint256 price, uint256 block);
  event PriceVerified(address indexed cToken, uint256 price, uint256 block);
}
