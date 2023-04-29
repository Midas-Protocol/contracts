// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract TOUCHToken is ERC20 {
  event TransferWithMemo(address indexed from, address indexed to, uint256 amount, bytes indexed memo);

  constructor(address tokenOwner, uint256 initialSupply) ERC20("Midas TOUCH Token", "TOUCH", 18) {
    _mint(tokenOwner, initialSupply);
  }

  function transferWithMemo(
    address to,
    uint256 amount,
    bytes calldata memo
  ) public returns (bool) {
    // checking the transfer() return value is redundant since it always reverts on failure
    transfer(to, amount);

    emit TransferWithMemo(msg.sender, to, amount, memo);

    return true;
  }

  function transferFromWithMemo(
    address from,
    address to,
    uint256 amount,
    bytes calldata memo
  ) public returns (bool) {
    // checking the transferFrom() return value is redundant since it always reverts on failure
    transferFrom(from, to, amount);

    emit TransferWithMemo(from, to, amount, memo);

    return true;
  }
}
