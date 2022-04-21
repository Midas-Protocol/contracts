// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract TOUCHToken is ERC20 {
  constructor(uint256 _initialSupply) ERC20("Midas TOUCH Token", "TOUCH", 18) {
    _mint(msg.sender, _initialSupply);
  }
}
