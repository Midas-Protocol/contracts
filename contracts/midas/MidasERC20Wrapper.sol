// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Wrapper } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MidasERC20Wrapper is ERC20Wrapper {
  address private owner;

  constructor(IERC20 underlyingToken) ERC20Wrapper(underlyingToken) {
    owner = msg.sender;
  }

  function recover() public returns (uint256) {
    return _recover(owner);
  }
}
