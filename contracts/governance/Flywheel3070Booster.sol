// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "flywheel-v2/interfaces/IFlywheelBooster.sol";
import "../external/compound/ICToken.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";
import "solmate/utils/SafeCastLib.sol";

/**
 * @title Flywheel3070Booster
 * @notice A booster that splits the rewards in a 30/70 ratio between supply and borrow
 *
 *                                    strategy.balance_of(user)            strategy.borrowed_principal_of(user)
 *  user_rewards = rewards * (0.3 * ----------------------------- + 0.7 * --------------------------------------)
 *                                    strategy.total_supplied()             strategy.total_borrowed_principal()
 *
 *                                   booster.boosted_balance_of()
 *  also, user_rewards = rewards * --------------------------------
 *                                  booster.boosted_total_supply()
 *
 * @author Veliko Minkov <veliko@midascapital.xyz>
 */
contract Flywheel3070Booster is IFlywheelBooster {
    using SafeCastLib for uint256;

    uint16 public minSupplyBorrowedBps;

    constructor(uint16 _minSupplyBorrowedBps) public {
        require(_minSupplyBorrowedBps <= 10000, "invalid min supplied borrowed value");
        // expressed in hundreds of the percent, meaning 100% = 10000
        minSupplyBorrowedBps = _minSupplyBorrowedBps;
    }

    function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
        ICToken asCToken = ICToken(address(strategy));
        // total borrows is denominated in underlying
        uint224 totalBorrows = asCToken.totalBorrows().safeCastTo224();
        // total supply is denominated in cTokens
        uint224 totalSupply = asCToken.totalSupply().safeCastTo224();

        // if not enough of the supply is borrowed, 100% of the rewards are for supplying
        if (totalBorrows * 10000 < totalSupply * minSupplyBorrowedBps) {
            return totalSupply;
        } else {
//            return btoi(bmul(BONE * totalBorrows, totalSupply));
            return totalBorrows * totalSupply;
        }
    }

    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256) {
        ICToken asCToken = ICToken(address(strategy));
        // total borrows is denominated in underlying
        uint224 totalBorrows = asCToken.totalBorrows().safeCastTo224();
        // total supply is denominated in cTokens
        uint224 totalSupply = asCToken.totalSupply().safeCastTo224();
        // balance is denominated in cTokens
        uint224 balance = asCToken.balanceOf(user).safeCastTo224();

        // 30% of the rewards are for supplying
        // 70% of the rewards are for borrowing

        // if not enough of the supply is borrowed, 100% of the rewards are for supplying
        if (totalBorrows * 10000 < totalSupply * minSupplyBorrowedBps) {
            return balance;
        } else {
            // borrow balance is denominated in underlying
            uint256 borrowed = asCToken.borrowBalanceStored(user);
            return
            (
//                7 * btoi(bmul(BONE * borrowed, totalSupply))
//                +
//                3 * btoi(bmul(BONE * balance, totalBorrows))
                7 * borrowed * totalSupply
                +
                3 * balance * totalBorrows
            ) / 10;
        }
    }
}
