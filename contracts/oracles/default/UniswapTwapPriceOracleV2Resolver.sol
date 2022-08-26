// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IResolver } from "ops/interfaces/IResolver.sol";
import { UniswapTwapPriceOracleV2Root } from "./UniswapTwapPriceOracleV2Root.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract UniswapTwapPriceOracleV2Resolver is IResolver, Ownable {
  struct PairConfig {
    address pair;
    address baseToken;
    uint256 minPeriod;
    uint256 deviationThreshold;
  }

  // need to store as arrays for the UniswapTwapPriceOracleV2Root workable functions
  address[] calldata pairs,
  address[] calldata baseTokens,
  uint256[] calldata minPeriods,
  uint256[] calldata deviationThresholds

  UniswapTwapPriceOracleV2Root public root;
  uint256 public lastUpdate;

  constructor(PairConfig[] _pairConfigs, UniswapTwapPriceOracleV2Root _root) public {
    for (uint i = 0; i < _pairConfigs.length; i++) {
      pairs[i] = _pairConfigs[i].pair;
      baseTokens[i] = _pairConfigs[i].baseToken;
      minPeriods[i] = _pairConfigs[i].minPeriod;
      deviationThresholds[i] = _pairConfigs[i].deviationThreshold;
    }
    root = _root;
  }

  function changeRoot(UniswapTwapPriceOracleV2Root _root) external onlyOwner {
    root = _root;
  }

  function removeFromPairs(uint256 index) external onlyOwner returns (PairConfig[]) {
    if (index >= pairConfigs.length) return;

    for (uint256 i = index; i < pairConfigs.length - 1; i++) {
      pairConfigs[i] = pairConfigs[i + 1];
    }
    pairConfigs.pop();
    return pairConfigs;
  }

  function addPair(PairConfig pair) external onlyOwner returns (PairConfig[]) {
    pairConfigs.push(pair);
    return pairConfigs;
  }

  function getWorkablePairs() public view returns (PairConfig[] memory workablePairs) {
    bool[] memory pairs = root.workable(
      address[] calldata pairs,
      address[] calldata baseTokens,
      uint256[] calldata minPeriods,
      uint256[] calldata deviationThresholds
    );

    for (uint i = 0; i < pairs.length; i++) {
      if (pairs[i]) {
        workablePairs.push(pairConfigs[i]);
      }
    }
  }

  function updatePairs(PairConfig[] calldata workablePairs) external {
    if (workablePairs.length == 0) return;
    root.update(workablePairs);
  }

  function checker() external view override returns (bool canExec, bytes memory execPayload) {
    PairConfig[] memory workablePairs = getWorkablePairs();
    if (workablePairs.length == 0) {
      return (false, bytes("No workable pairs"));
    } 
    
    if (block.timestamp < lastUpdate + minUpdateInterval) {
      return (false, bytes("Not enough time has passed"));
    }
    
    canExec = true;
    execPayload = abi.encodeWithSignature("updatePairs()", workablePairs);
  }
}
