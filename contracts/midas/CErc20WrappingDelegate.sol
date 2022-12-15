// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { EIP20Interface } from "../compound/EIP20Interface.sol";
import { IFuseFeeDistributor } from "../compound/IFuseFeeDistributor.sol";

import { ERC20Wrapper } from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract CErc20WrappingDelegate is CErc20Delegate {
  event NewErc20WrappingImplementation(address oldImpl, address newImpl);
  
  ERC20Wrapper public wrappingUnderlying;

  function _becomeImplementation(bytes memory data) public virtual override {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _becomeImplementation");

    address _wrappingUnderlying = abi.decode(data, (address));

    if (_wrappingUnderlying == address(0) && address(wrappingUnderlying) != address(0)) {
      _wrappingUnderlying = IFuseFeeDistributor(fuseAdmin).latestERC20WrappingImplementation(address(wrappingUnderlying));
    }

    if (_wrappingUnderlying != address(0) && _wrappingUnderlying != address(wrappingUnderlying)) {
      _updateUnderlying(_wrappingUnderlying);
    }
  }

  function _updateUnderlying(address _wrappingUnderlying) public {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _updateUnderlying");

    address oldImplementation = address(wrappingUnderlying) != address(0) ? address(wrappingUnderlying) : _wrappingUnderlying;

    require(
      IFuseFeeDistributor(fuseAdmin).erc20WrappingImplementationWhitelist(oldImplementation, _wrappingUnderlying),
      "erc20Wrapping implementation not whitelisted"
    );

    if (address(wrappingUnderlying) != address(0) && wrappingUnderlying.balanceOf(address(this)) != 0) {
      doTransferOut(address(this), wrappingUnderlying.balanceOf(address(this)));
    }

    wrappingUnderlying = ERC20Wrapper(_wrappingUnderlying);

    EIP20Interface(underlying).approve(_wrappingUnderlying, type(uint256).max);

    uint256 amount = EIP20Interface(underlying).balanceOf(address(this));

    if (amount != 0) {
      doTransferIn(address(this), amount);
    }

    emit NewErc20WrappingImplementation(address(wrappingUnderlying), _wrappingUnderlying);
  }

  function doTransferIn(address from, uint256 amount) internal virtual override returns (uint256) {
    require(EIP20Interface(underlying).transferFrom(from, address(this), amount), "send");

    wrappingUnderlying.depositFor(address(this), amount);
    return amount;
  }

  function doTransferOut(address to, uint256 amount) internal virtual override {
    wrappingUnderlying.withdrawTo(to, amount);
  }

  function contractType() external pure virtual override returns (string memory) {
    return "CErc20WrappingDelegate";
  }
}
