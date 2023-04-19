// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../midas/vault/levered/LeveredPositionStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LeveredPositionStrategyTest is BaseTest {
  address jBRLWhale = 0xBe9E8Ec25866B21bA34e97b9393BCabBcB4A5C86;

  function testOpenLeveredPosition() public fork(BSC_MAINNET) {

    // Jarvis jFiat bsc pool 0x31d76A64Bc8BbEffb601fac5884372DEF910F044
    ICErc20 collateralMarket = ICErc20(0x82A3103bc306293227B756f7554AfAeE82F8ab7a); // jBRL market
    ICErc20 stableMarket = ICErc20(0xa7213deB44f570646Ea955771Cc7f39B58841363); // bUSD market
    address positionOwner = address(this);
    address jBRLAddress = collateralMarket.underlying();
    IERC20 jBRL = IERC20(jBRLAddress);

    vm.prank(jBRLWhale);
    jBRL.transfer(address(this), 1e22);


    LeveredPositionStrategy position = new LeveredPositionStrategy(
      collateralMarket,
      stableMarket,
      positionOwner
    );

    jBRL.approve(address(position), 1e36);

    position.leverUp(1e22, IERC20(jBRLAddress));
  }
}