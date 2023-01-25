// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../external/saddle/ISwap.sol";
import { SaddleLpPriceOracle } from "../oracles/default/SaddleLpPriceOracle.sol";

contract SaddleLpTokenLiquidator is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (address outputTokenAddress, address oracleAddr) = abi.decode(strategyData, (address, address));
    SaddleLpPriceOracle oracle = SaddleLpPriceOracle(oracleAddr);

    ISwap pool = ISwap(oracle.poolOf(address(inputToken)));
    uint8 index = pool.getTokenIndex(outputTokenAddress);

    outputAmount = pool.removeLiquidityOneToken(inputAmount, index, 1, block.timestamp);
    outputToken = IERC20Upgradeable(outputTokenAddress);
  }
}
