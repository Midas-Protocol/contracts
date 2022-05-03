// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "forge-std/Test.sol";
import { WithPool } from "./helpers/WithPool.sol";

contract ComptrollerEnterExitMarket is Test, WithPool {
  address alice = address(1337);
  address bob = address(1338);
  uint256 amount = 1 ether;

  function testEnterMarkets() public {
    underlyingToken.mint(alice, amount);
    startHoax(alice);
    underlyingToken.approve(address(cErc20), amount);

    require(comptroller.enterMarkets(markets)[0] == 0);
    cErc20.mint(amount);
  }

  function testExitMarket() public {
    underlyingToken.mint(alice, amount);
    underlyingToken.mint(bob, amount);

    hoax(alice);
    underlyingToken.approve(address(cErc20), amount);
    hoax(alice);
    require(comptroller.enterMarkets(markets)[0] == 0, "Failed to Enter Market");
    hoax(alice);
    cErc20.mint(amount);

    hoax(bob);
    underlyingToken.approve(address(cErc20), amount);
    hoax(bob);
    require(comptroller.enterMarkets(markets)[0] == 0, "Failed to Enter Market");
    hoax(bob);
    cErc20.mint(amount);

    // Exit market as contract, should work as I don't have any borrow balances
    require(comptroller.exitMarket(markets[0]) == 0);
    hoax(alice);
    require(comptroller.exitMarket(markets[0]) == 0);
    // Bob can't exit the market because the Comptroller.allBorrowers array will be empty
    // and causes an Index Out of Bounds Exception
    // hoax(bob);
    // require(comptroller.exitMarket(markets[0]) == 0);
  }
}
