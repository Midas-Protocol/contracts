// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/**
 * @title AddressesProvider
 * @notice The Addresses Provider serves as a central storage of system internal and external
 *         contract addresses that change between deploys and across chains
 * @author Veliko Minkov <veliko@midascapital.xyz>
 */
contract AddressesProvider is OwnableUpgradeable {
  mapping(string => address) private _addresses;
  mapping(address => Contract) public flywheelRewards;
  mapping(address => Contract) public plugins;

  /// @dev Initializer to set the admin that can set and change contracts addresses
  function initialize(address owner) public initializer {
    __Ownable_init();
    _transferOwnership(owner);
  }

  event AddressSet(string id, address indexed newAddress);

  /**
   * @dev The contract address and a string that uniquely identifies the contract's interface
   */
  struct Contract {
    address addr;
    string contractInterface;
  }

  /**
   * @dev sets the address and contract interface ID of the flywheel for the reward token
   * @param rewardToken the reward token address
   * @param flywheelRewardsModule the flywheel rewards module address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setFlywheelRewards(
    address rewardToken,
    address flywheelRewardsModule,
    string calldata contractInterface
  ) public onlyOwner {
    flywheelRewards[rewardToken] = Contract(flywheelRewardsModule, contractInterface);
  }

  /**
   * @dev sets the address and contract interface ID of the ERC4626 plugin for the asset
   * @param asset the asset address
   * @param plugin the ERC4626 plugin address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setPlugin(
    address asset,
    address plugin,
    string calldata contractInterface
  ) public onlyOwner {
    plugins[asset] = Contract(plugin, contractInterface);
  }

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
