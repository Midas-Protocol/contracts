// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../external/angle/IGenericLender.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

struct LendStatus {
  string name;
  uint256 assets;
  uint256 rate;
  address add;
}

contract OptimizerAPRStrategy is Initializable {
  IGenericLender[] public lenders;

  /// @notice Reference to the ERC20 farmed by this strategy
  IERC20Upgradeable public want;

  function initialize(IERC20Upgradeable _want) public initializer {
    want = _want;
  }

  // =============================== VIEW FUNCTIONS ==============================

  /// @notice View function to check the current state of the strategy
  /// @return Returns the status of all lenders attached the strategy
  function lendStatuses() external view returns (LendStatus[] memory) {
    uint256 lendersLength = lenders.length;
    LendStatus[] memory statuses = new LendStatus[](lendersLength);
    for (uint256 i; i < lendersLength; ++i) {
      LendStatus memory s;
      s.name = lenders[i].lenderName();
      s.add = address(lenders[i]);
      s.assets = lenders[i].nav();
      s.rate = lenders[i].apr();
      statuses[i] = s;
    }
    return statuses;
  }

  /// @notice View function to check the total assets lent
  function lentTotalAssets() public view returns (uint256) {
    uint256 nav;
    uint256 lendersLength = lenders.length;
    for (uint256 i; i < lendersLength; ++i) {
      nav += lenders[i].nav();
    }
    return nav;
  }

  /// @notice View function to check the total assets managed by the strategy
  function estimatedTotalAssets() public view returns (uint256 nav) {
    nav = lentTotalAssets() + want.balanceOf(address(this));
  }

  /// @notice View function to check the number of lending platforms
  function numLenders() external view returns (uint256) {
    return lenders.length;
  }

  /// @notice Returns the weighted apr of all lenders
  /// @dev It's computed by doing: `sum(nav * apr) / totalNav`
  function estimatedAPR() external view returns (uint256) {
    uint256 bal = estimatedTotalAssets();
    if (bal == 0) {
      return 0;
    }

    uint256 weightedAPR;
    uint256 lendersLength = lenders.length;
    for (uint256 i; i < lendersLength; ++i) {
      weightedAPR += lenders[i].weightedApr();
    }

    return weightedAPR / bal;
  }
}
