// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import "./GaugesController.sol";

contract VeMDSToken is ERC20 {
  GaugesController public immutable gaugesController;

  constructor(address _gaugesControllerAddress) ERC20("Midas Voting Escrow Token", "veMDS", 18) {
    gaugesController = GaugesController(_gaugesControllerAddress);
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == address(gaugesController), "caller not gauges controller");

    // TODO mint amount, should Transfer be emitted at all?
    super._mint(to, amount);
  }

  function _mint(address to, uint256 amount) internal override {
    totalSupply += amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    unchecked {
      balanceOf[to] += amount;
    }
//    emit Transfer(address(0), to, amount);
  }

  function votingPowerOf(address account) public view returns (uint) {
    if (totalSupply == 0) return 0;

    uint stakingStartedTime = gaugesController.stakingStartedTime(account);
    if (stakingStartedTime == 0) {
      return 0;
    } else {
      uint _balance = balanceOf[account];
      uint hoursSinceStaked = (block.timestamp - stakingStartedTime) % 3600;
      if (hoursSinceStaked < 7143) { // 7143 * 0.014 = 100.002
        // hours since staked * 0.014
        return _balance * hoursSinceStaked * 14 / 100000;
      } else {
        // 298 * 24 = 7152
        // during day 298 voting power becomes 100% of the staked MDS
        return _balance;
      }
    }
  }
}
