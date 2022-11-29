// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import { AddressesProvider } from "../../midas/AddressesProvider.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract BaseTest is Test {
  uint128 constant BSC_MAINNET = 56;
  uint128 constant MOONBEAM_MAINNET = 1284;
  uint128 constant POLYGON_MAINNET = 137;
  uint128 constant ARBITRUM_ONE = 42161;
  uint128 constant FANTOM_OPERA = 250;
  uint128 constant EVMOS_MAINNET = 9001;

  uint128 constant BSC_CHAPEL = 97;
  uint128 constant NEON_DEVNET = 245022926;

  AddressesProvider public ap;
  ProxyAdmin public dpa;

  mapping(uint128 => uint256) private forkIds;

  constructor() {
    configureAddressesProvider(0);
  }

  uint256 constant CRITICAL = 100;
  uint256 constant NORMAL = 90;
  uint256 constant LOW = 80;

  modifier importance(uint256 testImportance) {
    uint256 runLevel = NORMAL;

    try vm.envString("GH_ACTION") returns (string memory ghAction) {
      emit log(ghAction);
    } catch {
      emit log("failed to get env param GH_ACTION");
    }

    try vm.envUint("TEST_RUN_LEVEL") returns (uint256 level) {
      runLevel = level;
    } catch {
      emit log("failed to get env param TEST_RUN_LEVEL");
    }

    if (testImportance >= runLevel) {
      _;
    } else {
      emit log("not running the test");
      emit log("testImportance");
      emit log_uint(testImportance);
      emit log("runLevel");
      emit log_uint(runLevel);
    }
  }

  modifier fork(uint128 chainid) {
    if (shouldRunForChain(chainid)) {
      _forkAtBlock(chainid, 0);
      _;
    }
  }

  modifier forkAtBlock(uint128 chainid, uint256 blockNumber) {
    if (shouldRunForChain(chainid)) {
      _forkAtBlock(chainid, blockNumber);
      _;
    }
  }

  function shouldRunForChain(uint256 chainid) internal returns (bool) {
    bool run = true;
    try vm.envUint("TEST_RUN_CHAINID") returns (uint256 envChainId) {
      run = envChainId == chainid;
    } catch {
      emit log("failed to get env param TEST_RUN_CHAINID");
    }
    return run;
  }

  function _forkAtBlock(uint128 chainid, uint256 blockNumber) private {
    if (block.chainid != chainid) {
      if (blockNumber != 0) {
        vm.selectFork(getArchiveForkId(chainid));
        vm.rollFork(blockNumber);
      } else {
        vm.selectFork(getForkId(chainid));
      }
    }
    configureAddressesProvider(chainid);
    afterForkSetUp();
  }

  function getForkId(uint128 chainid, bool archive) private returns (uint256) {
    return archive ? getForkId(chainid) : getArchiveForkId(chainid);
  }

  function getForkId(uint128 chainid) private returns (uint256) {
    if (forkIds[chainid] == 0) {
      if (chainid == BSC_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("bsc")) + 100;
      } else if (chainid == BSC_CHAPEL) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("bsc_chapel")) + 100;
      } else if (chainid == MOONBEAM_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("moonbeam")) + 100;
      } else if (chainid == EVMOS_MAINNET) {
        forkIds[chainid] = vm.createFork(vm.rpcUrl("evmos")) + 100;
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

  function getArchiveForkId(uint128 chainid) private returns (uint256) {
    // store the archive rpc urls in the forkIds mapping at an offset
    uint128 chainidWithOffset = chainid + type(uint64).max;
    if (forkIds[chainidWithOffset] == 0) {
      if (chainid == BSC_MAINNET) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("bsc_archive")) + 100;
      } else if (chainid == BSC_CHAPEL) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("bsc_chapel_archive")) + 100;
      } else if (chainid == MOONBEAM_MAINNET) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("moonbeam_archive")) + 100;
      } else if (chainid == EVMOS_MAINNET) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("evmos_archive")) + 100;
      } else if (chainid == POLYGON_MAINNET) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("polygon_archive")) + 100;
      } else if (chainid == NEON_DEVNET) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("neon_dev_archive")) + 100;
      } else if (chainid == ARBITRUM_ONE) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("arbitrum_archive")) + 100;
      } else if (chainid == FANTOM_OPERA) {
        forkIds[chainidWithOffset] = vm.createFork(vm.rpcUrl("fantom_archive")) + 100;
      }
    }
    return forkIds[chainidWithOffset] - 100;
  }

  function afterForkSetUp() internal virtual {}

  function configureAddressesProvider(uint128 chainid) private {
    if (chainid == BSC_MAINNET) {
      ap = AddressesProvider(0x01c97299b37E66c03419bC4Db24074a89FB36e6d);
    } else if (chainid == BSC_CHAPEL) {
      ap = AddressesProvider(0x38742363597fBaE312B0bdcC351fCc6107E9E27E);
    } else if (chainid == MOONBEAM_MAINNET) {
      ap = AddressesProvider(0x771ee5a72A57f3540E5b9A6A8C226C2a24A70Fae);
    } else if (block.chainid == EVMOS_MAINNET) {
      ap = AddressesProvider(0xe693a13526Eb4cff15EbeC54779Ea640E2F36a9f);
    } else if (block.chainid == POLYGON_MAINNET) {
      ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    } else if (chainid == NEON_DEVNET) {
      ap = AddressesProvider(0x3B0B043f5c459F9f5dC39ECb04AA39D1E675565B);
    } else if (chainid == ARBITRUM_ONE) {
      ap = AddressesProvider(0xe693a13526Eb4cff15EbeC54779Ea640E2F36a9f);
    } else if (chainid == FANTOM_OPERA) {
      ap = AddressesProvider(0xC1B6152d3977E994F5a4E0dead9d0a11a0D229Ef);
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
