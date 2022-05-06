// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { CurveLpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import "../../oracles/default/ChainlinkPriceOracleV2.sol";
import "../../external/jarvis/ISynthereumLiquidityPool.sol";
import "../../oracles/MasterPriceOracle.sol";
import "../../oracles/default/UniswapTwapPriceOracleV2Factory.sol";
import "../../utils/AddressesProvider.sol";

abstract contract BaseTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  uint256 constant BSC_MAINNET = 56;
  uint256 constant MOONBEAM_MAINNET = 1284;

  uint256 constant EVMOS_TESTNET = 9000;
  uint256 constant BSC_CHAPEL = 97;

  // TODO instantiate from the deployed delegator/storage address
  AddressesProvider ap = new AddressesProvider();

  constructor() {
//    ap.initialize(address(this));
    // TODO remove this code when there is an on-chain AddressesProvider instance to use
    configureAddressesProvider();
  }

  function configureAddressesProvider() internal {
    if (ap.owner() == address(0)) {
      if(block.chainid == BSC_MAINNET) {
        // external addresses
        ap.setAddress("wtoken", 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        ap.setAddress("uniswapV2Factory", 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

        ap.setAddress("bUSD", 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

        // system addresses
        ap.setAddress("masterPriceOracle", 0xC3ABf2cB82C65474CeF8F90f1a4DAe79929B1940);
        ap.setAddress("twapOraclesFactory", 0x8853F26C198fd5693E7886C081164E0c3F0a4E51);
        ap.setAddress("chainlinkOracle", 0x2B5311De4555506400273CfaAFb4393F01EC2567);
      } else if(block.chainid == BSC_CHAPEL) {
        // external addresses
        ap.setAddress("wtoken", 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd);
        ap.setAddress("uniswapV2Factory", 0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc);

        // system addresses
        ap.setAddress("masterPriceOracle", 0xC3ABf2cB82C65474CeF8F90f1a4DAe79929B1940);
        ap.setAddress("twapOraclesFactory", 0x944fed08a91983d06f653E9F55Eca995316Ccd3e);
      } else if(block.chainid == MOONBEAM_MAINNET) {
        // external addresses
        ap.setAddress("wtoken", 0xAcc15dC74880C9944775448304B263D191c6077F);
        ap.setAddress("uniswapV2Factory", 0x985BcA32293A7A496300a48081947321177a86FD);

        // system addresses
        ap.setAddress("masterPriceOracle", 0x14C15B9ec83ED79f23BF71D51741f58b69ff1494);
      }
    }
  }

  modifier shouldRun(bool run) {
    if (run) {
      _;
    }
  }

  function forChains(uint256 id0) public view returns (bool) {
    return block.chainid == id0;
  }

  function forChains(uint256 id0, uint256 id1) public view returns (bool) {
    return block.chainid == id0 || block.chainid == id1;
  }
}
