// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MidasCompensationToken is ERC20 {
  address private constant agEurMarket = 0x5aa0197D0d3E05c4aA070dfA2f54Cd67A447173A;
  address private constant jchfMarket = 0x62Bdc203403e7d44b75f357df0897f2e71F607F3;
  address private constant jeurMarket = 0xe150e792e0a18C9984a0630f051a607dEe3c265d;
  address private constant jgbpMarket = 0x7ADf374Fa8b636420D41356b1f714F18228e7ae2;

  address[] public holders;

  constructor() ERC20("Midas Exploit Compensation Token", "MECT", 18) {}

  function mint(address to, uint256 amount) public {
    require(
      msg.sender == agEurMarket || msg.sender == jchfMarket || msg.sender == jeurMarket || msg.sender == jgbpMarket,
      "!minter"
    );
    _mint(to, amount);

    // add to the set of holders
    for(uint256 i = 0; i < holders.length; i++) {
      if (holders[i] == to) return;
    }

    holders.push(to);
  }

  function getAllHolders() public returns (address[] memory) {
    return holders;
  }
}
