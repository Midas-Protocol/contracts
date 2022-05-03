// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "flywheel-v2/interfaces/IFlywheelBooster.sol";
import "../external/compound/ICToken.sol";

contract Flywheel3070Booster is IFlywheelBooster {
    function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
        // TODO figure out if this need also 30/70
        return strategy.totalSupply();
    }

    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256) {
        // TODO accrue interest first
        ICToken asCToken = ICToken(address(strategy));
        return (
                3 * asCToken.balanceOf(user) * asCToken.totalBorrows()
                + 7 * asCToken.borrowBalanceStored(user) * asCToken.totalSupply()
            ) / (10 * asCToken.totalBorrows());

//        (3 * asCToken.balanceOf(user) + (7 * asCToken.borrowBalanceCurrent(user) * asCToken.totalSupply()) / asCToken.totalBorrowsCurrent()) / 10;

    }
}
