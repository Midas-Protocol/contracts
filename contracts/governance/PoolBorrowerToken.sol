// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/IComptroller.sol";
import "../external/compound/IPriceOracle.sol";

import "solmate/tokens/ERC20.sol";

// TODO is ERC20 even necessary to be inherited?
contract PoolBorrowerToken /* is ERC20 */ {
    IComptroller public comptroller;

    constructor(IComptroller _comptroller) {
        comptroller = _comptroller;
    }

    // calculate the total value of the debt across all assets in the pool
    // TODO filter out the non-gauge whitelisted assets
    // TODO figure out if view is possible
    function totalSupply() external /*view*/ returns (uint256) {
        uint256 _totalBorrowValue = 0;
        ICToken[] memory cTokens = comptroller.getAllMarkets();
        IPriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            ICToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            uint256 assetTotalBorrow = cToken.totalBorrowsCurrent();
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            _totalBorrowValue = _totalBorrowValue + (assetTotalBorrow * underlyingPrice) / 1e18;
        }

        return _totalBorrowValue;
    }

    // calculate the total value of the user borrows across all pool assets
    // TODO filter out the non-gauge whitelisted assets
    // TODO figure out if view is possible
    function balanceOf(address account) external /*view*/ returns (uint256) {
        uint256 _accountBorrowValue = 0;
        ICToken[] memory cTokens = comptroller.getAllMarkets();
        IPriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            ICToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            // TODO or borrowBalanceStored without calling accrueInterest()
            uint256 accountAssetBorrow = cToken.borrowBalanceCurrent(account);
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            _accountBorrowValue = _accountBorrowValue + (accountAssetBorrow * underlyingPrice) / 1e18;
        }

        return _accountBorrowValue;
    }
}
