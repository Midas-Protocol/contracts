// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/ICToken.sol";

import "solmate/tokens/ERC20.sol";

// TODO is ERC20 even necessary to be inherited?
contract MarketBorrowStrategy /* is ERC20 */ {
    ICToken cToken;

    constructor(ICToken _cToken) {
        cToken = _cToken;
    }

    // TODO figure out if view is possible
    function totalSupply() external /*view*/ returns (uint256) {
//        cToken.accrueInterest();
        // accrue interest called in totalBorrowsCurrent
        return cToken.totalBorrowsCurrent();
    }

    // TODO figure out if view is possible
    function balanceOf(address account) external /*view*/ returns (uint256) {
//        cToken.accrueInterest();
        // accrue interest called in borrowBalanceCurrent
        return cToken.borrowBalanceCurrent(account);
    }
}
