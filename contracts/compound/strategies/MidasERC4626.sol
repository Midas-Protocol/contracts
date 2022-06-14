// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "solmate/mixins/ERC4626.sol";
import "solmate/tokens/ERC20.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

abstract contract MidasERC4626 is ERC4626, AccessControl {
  address public owner;

  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) {
    owner = _msgSender();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  modifier ownerOnly() {
    require(_msgSender() == owner, "Only available for owner.");
    _;
  }

  modifier adminOnly() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Admin role required.");
    _;
  }

  function addAdmin(address _address) external ownerOnly {
    _grantRole(DEFAULT_ADMIN_ROLE, _address);
  }

  function removeAdmin(address _address) external ownerOnly {
    _revokeRole(DEFAULT_ADMIN_ROLE, _address);
  }

  // function withdrawERC20(address _token) external adminOnly {
  //   ERC20(_token).transfer(_msgSender(), ERC20(_token).balanceOf(address(this)));
  // }
}
