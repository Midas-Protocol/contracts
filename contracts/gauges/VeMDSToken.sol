// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract VeMDSToken is ERC20 {
  address public immutable gaugesControllerAddress;

  constructor(address _gaugesControllerAddress) ERC20("Midas Voting Escrow Token", "veMDS", 18) {
    gaugesControllerAddress = _gaugesControllerAddress;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == gaugesControllerAddress, "caller not gauges controller");

    super._mint(to, amount);
  }
}
