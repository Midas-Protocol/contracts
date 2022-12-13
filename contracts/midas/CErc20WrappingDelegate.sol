// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { EIP20Interface } from "../compound/EIP20Interface.sol";
import { ERC20Wrapper } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract CErc20WrappingDelegate is CErc20Delegate {
  ERC20Wrapper public wrappedUnderlying;

  function _becomeImplementation(bytes memory data) public virtual override {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _becomeImplementation");

    address _wrappingUnderlying = abi.decode(data, (address));

    if (_wrappingUnderlying != address(0) && _wrappingUnderlying != address(_wrappingUnderlying)) {
      wrappedUnderlying = ERC20Wrapper(_wrappingUnderlying);
    }
  }

  function doTransferIn(address from, uint256 amount) internal virtual override returns (uint256) {
    require(EIP20Interface(underlying).transferFrom(from, address(this), amount), "send");

    wrappedUnderlying.depositFor(address(this), amount);
    return amount;
  }

  function doTransferOut(address to, uint256 amount) internal virtual override {
    wrappedUnderlying.withdrawTo(to, amount);
  }

  function contractType() external pure virtual override returns (string memory) {
    return "CErc20WrappingDelegate";
  }
}
