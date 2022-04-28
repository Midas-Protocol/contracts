// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/ICToken.sol";

import "solmate/tokens/ERC20.sol";

// TODO is ERC20 even necessary to be inherited?
contract AssetSupplierToken /* is ERC20 */ {
    ICToken cToken;

    function totalSupply() external view returns (uint256) {
        return cToken.totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        return cToken.balanceOf(account);
    }
}
