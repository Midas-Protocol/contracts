// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import {CurveLpTokenPriceOracleNoRegistry} from "../../contracts/oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

abstract contract BaseTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  struct ChainConfig {
    IERC20Upgradeable pool;
    address whale;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable[] coins;
    WETH weth;
    CurveLpTokenPriceOracleNoRegistry oracle;
  }

  mapping(uint => ChainConfig) public chainConfigs;

  function setUp() virtual public {
    chainConfigs[56] = ChainConfig({
      pool: IERC20Upgradeable(0x160CAed03795365F3A589f10C379FfA7d75d4E76),
      lpToken: IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452),
      whale: 0x516E5B72C3fD2D2E59835C82005ba6A2BC5788A4,
      coins: new IERC20Upgradeable[](1),
      weth: WETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)),
      oracle: CurveLpTokenPriceOracleNoRegistry(0x274F5dFBDB6af889124EFcfA065A247A15243EC2)
    });
    chainConfigs[56].coins[0] = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  }
}
