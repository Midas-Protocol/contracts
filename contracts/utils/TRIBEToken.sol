pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TRIBEToken is ERC20
{
    constructor(uint256 initialSupply) ERC20("TRIBE", "TRIBE Governance Token") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}