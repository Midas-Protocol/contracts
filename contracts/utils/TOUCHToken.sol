// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract TOUCHToken is ERC20 {

  event Transfer(address indexed from, address indexed to, uint256 amount, bytes indexed memo);

  constructor(uint256 initialSupply, address tokenOwner) ERC20("Midas TOUCH Token", "TOUCH", 18) {
    _mint(tokenOwner, initialSupply);
  }

  function transfer(address to, uint256 amount, bytes calldata memo) public returns (bool) {
    // require redundant since the underlying transfer call returns true or reverts
//    require(
    transfer(to, amount);
//    , "ERC20 transfer failed");
    emit Transfer(msg.sender, to, amount, memo);

    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount,
    bytes calldata memo
  ) public returns (bool) {
    transferFrom(from, to, amount);

    // the signature of this Transfer event is different than the standard ERC20 Transfer sig
    emit Transfer(from, to, amount, memo);

    return true;
  }
}
