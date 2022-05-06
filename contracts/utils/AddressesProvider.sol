// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract AddressesProvider is Initializable, OwnableUpgradeable {
    mapping(string => address) private _addresses;

    function initialize(address owner) public initializer {
        __Ownable_init();
        _transferOwnership(owner);
    }

    event AddressSet(string id, address indexed newAddress);

    /**
     * @dev Sets an address for an id replacing the address saved in the addresses map
     * @param id The id
     * @param newAddress The address to set
     */
    function setAddress(string calldata id, address newAddress) external onlyOwner {
        _addresses[id] = newAddress;
        emit AddressSet(id, newAddress);
    }

    /**
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(string calldata id) public view returns (address) {
        return _addresses[id];
    }
}
