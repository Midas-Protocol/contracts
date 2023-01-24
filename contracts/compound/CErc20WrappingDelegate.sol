// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CErc20Delegate } from "./CErc20Delegate.sol";
import { EIP20Interface } from "./EIP20Interface.sol";
import { IFuseFeeDistributor } from "../compound/IFuseFeeDistributor.sol";
import { MidasERC20Wrapper } from "../midas/MidasERC20Wrapper.sol";

contract CErc20WrappingDelegate is CErc20Delegate {
  event NewErc20WrappingImplementation(address oldImpl, address newImpl);

  MidasERC20Wrapper public underlyingWrapper;

  function _becomeImplementation(bytes memory data) public virtual override {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _becomeImplementation");

    if (address(underlyingWrapper) == address(0)) {
      EIP20Interface asErc20 = EIP20Interface(underlying);
      underlyingWrapper = new MidasERC20Wrapper(underlying, asErc20.name(), asErc20.symbol(), asErc20.decimals());
    } else {
      address _newWrapper = abi.decode(data, (address));
      if (_newWrapper == address(0)) {
        _newWrapper = IFuseFeeDistributor(fuseAdmin).latestERC20WrapperForUnderlying(address(underlyingWrapper));
      }

      if (_newWrapper != address(0) && _newWrapper != address(underlyingWrapper)) {
        _updateWrapper(_newWrapper);
      }
    }
  }

  function _updateWrapper(address _newWrapper) public {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _updateWrapper");

    address oldImplementation = address(underlyingWrapper) != address(0) ? address(underlyingWrapper) : _newWrapper;

    require(
      IFuseFeeDistributor(fuseAdmin).erc20WrapperUpgradeWhitelist(oldImplementation, _newWrapper),
      "erc20Wrapping implementation not whitelisted"
    );

    if (address(underlyingWrapper) != address(0) && underlyingWrapper.balanceOf(address(this)) != 0) {
      doTransferOut(address(this), underlyingWrapper.balanceOf(address(this)));
    }

    emit NewErc20WrappingImplementation(address(underlyingWrapper), _newWrapper);

    underlyingWrapper = MidasERC20Wrapper(_newWrapper);

    EIP20Interface(underlying).approve(_newWrapper, type(uint256).max);

    uint256 amount = EIP20Interface(underlying).balanceOf(address(this));

    if (amount != 0) {
      doTransferIn(address(this), amount);
    }
  }

  function doTransferIn(address from, uint256 amount) internal virtual override returns (uint256) {
    require(EIP20Interface(underlying).transferFrom(from, address(this), amount), "send");
    require(EIP20Interface(underlying).approve(address(underlyingWrapper), amount), "approve wrapper");
    underlyingWrapper.depositFor(address(this), amount);
    return amount;
  }

  function doTransferOut(address to, uint256 amount) internal virtual override {
    underlyingWrapper.withdrawTo(to, amount);
  }

  function contractType() external pure virtual override returns (string memory) {
    return "CErc20WrappingDelegate";
  }
}
