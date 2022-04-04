// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import "./GaugesController.sol";

// TODO research ERC20VotesUpgradeable
contract VeMDSToken is ERC20 {
  GaugesController public immutable gaugesController;

  constructor(address _gaugesControllerAddress) ERC20("Midas Voting Escrow Token", "veMDS", 18) {
    gaugesController = GaugesController(_gaugesControllerAddress);
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == address(gaugesController), "caller not gauges controller");
    super._mint(to, amount);
  }

  function burn(address to, uint256 amount) public {
    require(msg.sender == address(gaugesController), "caller not gauges controller");
    super._burn(to, amount);
  }

  // TODO non-transferable - but can be bridged
}
