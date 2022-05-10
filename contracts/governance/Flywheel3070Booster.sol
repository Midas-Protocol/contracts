// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "flywheel-v2/interfaces/IFlywheelBooster.sol";
import "../external/compound/ICToken.sol";

contract Flywheel3070Booster is IFlywheelBooster {
    function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
        // TODO figure out if this need also 30/70
        return strategy.totalSupply();
    }

    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256 boostedBalance) {
        // TODO accrue interest first
        ICToken asCToken = ICToken(address(strategy));

        // 30% of the rewards are for supplying
        boostedBalance = 3 * asCToken.balanceOf(user);

        // 70% of the rewards are for borrowing
        if (asCToken.totalBorrows() > 0) {
            boostedBalance +=
                (
                    7 * asCToken.borrowBalanceStored(user) * asCToken.totalSupply()
                ) / asCToken.totalBorrows();
        }
        boostedBalance /= 10;
    }
}
