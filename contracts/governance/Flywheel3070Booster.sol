// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "flywheel-v2/interfaces/IFlywheelBooster.sol";
import "../external/compound/ICToken.sol";
import "../external/balancer/BNum.sol";
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
contract Flywheel3070Booster is IFlywheelBooster, BNum {
    using SafeCastLib for uint256;

    /* Calculate new borrow balance using the interest index:
     *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
     */
    function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
        ICToken asCToken = ICToken(address(strategy));
        uint224 index = asCToken.borrowIndex().safeCastTo224();
        // total borrows is denominated in underlying
        uint224 totalBorrows = asCToken.totalBorrows().safeCastTo224();
        uint256 totalBorrowedPrincipal = bdiv(totalBorrows, index);
        // total supply is denominated in cTokens
        uint224 totalSupply = asCToken.totalSupply().safeCastTo224();

        return bmul(/*BONE * */totalBorrowedPrincipal, totalSupply);
    }

    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256 boostedBalance) {
        ICToken asCToken = ICToken(address(strategy));
        uint224 index = asCToken.borrowIndex().safeCastTo224();
        // total borrows is denominated in underlying
        uint224 totalBorrows = asCToken.totalBorrows().safeCastTo224();

        uint256 userBorrowedPrincipal = bdiv(asCToken.borrowBalanceStored(user), index);
        uint256 totalBorrowedPrincipal = bdiv(totalBorrows, index);

        // total supply is denominated in cTokens
        uint224 totalSupply = asCToken.totalSupply().safeCastTo224();
        // balance is denominated in cTokens
        uint224 balance = asCToken.balanceOf(user).safeCastTo224();

        // 30% of the rewards are for supplying
        // 70% of the rewards are for borrowing
        return
                    (
                        7 * bmul(/*BONE * */totalSupply, userBorrowedPrincipal)
                        +
                        3 * bmul(/*BONE * */totalBorrowedPrincipal, balance)
                    ) / 10;
    }
}
