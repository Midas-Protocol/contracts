// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/IComptroller.sol";
import "../external/compound/IPriceOracle.sol";

import "solmate/tokens/ERC20.sol";

// TODO is ERC20 even necessary to be inherited?
contract PoolSupplierToken /* is ERC20 */ {
    IComptroller public comptroller;

    constructor(IComptroller _comptroller) {
        comptroller = _comptroller;
    }

    // calculate the total value of the all supplied assets in the pool
    // TODO filter out the non-gauge whitelisted assets
    // TODO figure out if view is possible
    function totalSupply() external /*view*/ returns (uint256) {
        uint256 _totalSupplyValue = 0;
        ICToken[] memory cTokens = comptroller.getAllMarkets();
        IPriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            ICToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            uint256 assetTotalBorrow = cToken.totalBorrowsCurrent();
            uint256 assetTotalSupply = cToken.getCash() + assetTotalBorrow - (cToken.totalReserves() + cToken.totalAdminFees() + cToken.totalFuseFees());
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            _totalSupplyValue = _totalSupplyValue + (assetTotalSupply * underlyingPrice) / 1e18;
        }

        return _totalSupplyValue;
    }

    // calculate the total value of the user supplied assets in the pool
    // TODO filter out the non-gauge whitelisted assets
    // TODO figure out if view is possible
    function balanceOf(address account) external /*view*/ returns (uint256) {
        uint256 _accountSupplyValue = 0;
        ICToken[] memory cTokens = comptroller.getAllMarkets();
        IPriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            ICToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            // TODO or balanceOfUnderlying without calling accrueInterest()
            uint256 accountAssetSupply = cToken.balanceOfUnderlying(account);
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            _accountSupplyValue = _accountSupplyValue + (accountAssetSupply * underlyingPrice) / 1e18;
        }

        return _accountSupplyValue;
    }
}
