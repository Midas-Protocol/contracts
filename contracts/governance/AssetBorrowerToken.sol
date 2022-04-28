// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/ICToken.sol";

import "solmate/tokens/ERC20.sol";

// TODO is ERC20 even necessary to be inherited?
contract AssetBorrowerToken /* is ERC20 */ {
    ICToken cToken;

    // TODO figure out if view is possible
    function totalSupply() external /*view*/ returns (uint256) {
        return cToken.totalBorrowsCurrent();
    }

    // TODO figure out if view is possible
    function balanceOf(address account) external /*view*/ returns (uint256) {
        return cToken.borrowBalanceCurrent(account);
    }
}
