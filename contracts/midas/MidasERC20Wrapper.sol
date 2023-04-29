// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Wrapper, ERC20 } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MidasERC20Wrapper is ERC20Wrapper {
  address private _owner;
  uint8 private _decimals;

  //  string private _nameOverride;
  //  string private _symbolOverride;

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

  function recover(address token) public returns (uint256) {
    if (token == address(this)) {
      return _recover(_owner);
    } else {
      uint256 balance = IERC20(token).balanceOf(address(this));
      return IERC20(token).transfer(_owner, balance) ? balance : 0;
    }
  }

  //  function name() public view virtual override returns (string memory) {
  //    if (bytes(_nameOverride).length == 0) {
  //      return super.name();
  //    } else {
  //      return _nameOverride;
  //    }
  //  }
  //
  //  function symbol() public view virtual override returns (string memory) {
  //    if (bytes(_symbolOverride).length == 0) {
  //      return super.symbol();
  //    } else {
  //      return _symbolOverride;
  //    }
  //  }
  //
  //  function _overrideNameAndSymbol(string memory name_, string memory symbol_) external {
  //    require(msg.sender == _owner, "!owner");
  //    _name = name_;
  //    _symbol = symbol_;
  //  }
}
