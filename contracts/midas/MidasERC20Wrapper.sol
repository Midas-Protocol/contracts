// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Wrapper, ERC20 } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MidasERC20Wrapper is ERC20Wrapper {
  address private _owner;
  uint8 private _decimals;

  constructor(
    address underlyingToken_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) ERC20(name_, symbol_) ERC20Wrapper(IERC20(underlyingToken_)) {
    _owner = msg.sender;
    _decimals = decimals_;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function recover() public returns (uint256) {
    return _recover(_owner);
  }
}
