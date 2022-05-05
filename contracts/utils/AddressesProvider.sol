// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract AddressesProvider is Initializable, OwnableUpgradeable {
    mapping(bytes32 => address) private _addresses;

    function initialize(address owner) public initializer {
        __Ownable_init();
        _transferOwnership(owner);
    }

    event AddressSet(bytes32 id, address indexed newAddress);


    bytes32 private constant LENDING_POOL = 'LENDING_POOL';


    /**
     * @dev Sets an address for an id replacing the address saved in the addresses map
     * @param id The id
     * @param newAddress The address to set
     */
    function setAddress(bytes32 id, address newAddress) external onlyOwner {
        _addresses[id] = newAddress;
        emit AddressSet(id, newAddress);
    }

    /**
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(bytes32 id) public view returns (address) {
        return _addresses[id];
    }
}
