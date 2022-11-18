// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "../../midas/AddressesProvider.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract BaseTest is Test {
  uint128 constant BSC_MAINNET = 56;
  uint128 constant MOONBEAM_MAINNET = 1284;
  uint128 constant POLYGON_MAINNET = 137;
  uint128 constant ARBITRUM_ONE = 42161;
  uint128 constant FANTOM_OPERA = 250;

  uint128 constant EVMOS_TESTNET = 9000;
  uint128 constant BSC_CHAPEL = 97;
  uint128 constant NEON_DEVNET = 245022926;

  AddressesProvider public ap;
  ProxyAdmin public dpa;

  mapping(uint128 => uint256) private forkIds;

  modifier fork(uint128 chainid) {
    _forkAtBlock(chainid, 0);
    _;
  }

  modifier forkAtBlock(uint128 chainid, uint256 blockNumber) {
    _forkAtBlock(chainid, blockNumber);
    _;
  }

  function _forkAtBlock(uint128 chainid, uint256 blockNumber) private {
    if (block.chainid != chainid) {
      vm.selectFork(getForkId(chainid));
      if (blockNumber != 0) {
        vm.rollFork(blockNumber);
      }
      configureAddressesProvider(chainid);
      afterForkSetUp();
    }
  }

  function getForkId(uint128 chainid) private returns (uint256) {
    if (forkIds[chainid] == 0) {
      if (chainid == BSC_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("bsc")) + 100;
      } else if (chainid == BSC_CHAPEL) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("bsc_chapel")) + 100;
      } else if (chainid == MOONBEAM_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("moonbeam")) + 100;
      } else if (chainid == EVMOS_TESTNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("evmos_test")) + 100;
      } else if (chainid == POLYGON_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("polygon")) + 100;
      } else if (chainid == NEON_DEVNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("neon_dev")) + 100;
      } else if (chainid == ARBITRUM_ONE) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("arbitrum")) + 100;
      } else if (chainid == FANTOM_OPERA) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("fantom")) + 100;
      }
    }
    return forkIds[chainid] - 100;
  }

  function afterForkSetUp() internal virtual {}

  function configureAddressesProvider(uint128 chainid) internal {
    if (block.chainid == BSC_MAINNET) {
      ap = AddressesProvider(0x01c97299b37E66c03419bC4Db24074a89FB36e6d);
    } else if (block.chainid == BSC_CHAPEL) {
      ap = AddressesProvider(0x38742363597fBaE312B0bdcC351fCc6107E9E27E);
    } else if (block.chainid == MOONBEAM_MAINNET) {
      ap = AddressesProvider(0x771ee5a72A57f3540E5b9A6A8C226C2a24A70Fae);
    } else if (block.chainid == EVMOS_TESTNET) {
      ap = AddressesProvider(0xB88C6a114F01a80Dc8465b55067C8D046C2F445A);
    } else if (block.chainid == POLYGON_MAINNET) {
      ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    } else if (block.chainid == NEON_DEVNET) {
      ap = AddressesProvider(0x3B0B043f5c459F9f5dC39ECb04AA39D1E675565B);
    } else if (block.chainid == ARBITRUM_ONE) {
      ap = AddressesProvider(0xe693a13526Eb4cff15EbeC54779Ea640E2F36a9f);
    } else {
      dpa = new ProxyAdmin();
      AddressesProvider logic = new AddressesProvider();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(logic),
        address(dpa),
        abi.encodeWithSelector(ap.initialize.selector, address(this))
      );
      ap = AddressesProvider(address(proxy));
    }
    if (ap.owner() == address(0)) {
      ap.initialize(address(this));
    }
  }

  function diff(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a > b) {
      return a - b;
    } else {
      return b - a;
    }
  }

  function compareStrings(string memory a, string memory b) public pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function asArray(address value) public pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = value;
    return array;
  }

  function asArray(address value0, address value1) public pure returns (address[] memory) {
    address[] memory array = new address[](2);
    array[0] = value0;
    array[1] = value1;
    return array;
  }

  function asArray(bool value) public pure returns (bool[] memory) {
    bool[] memory array = new bool[](1);
    array[0] = value;
    return array;
  }

  function asArray(uint256 value) public pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](1);
    array[0] = value;
    return array;
  }
}
