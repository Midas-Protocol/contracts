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

abstract contract BaseTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);
  ChainConfig internal chainConfig;

  struct ChainConfig {
    IERC20Upgradeable pool;
    address lpTokenWhale;
    IERC20Upgradeable lpToken;
    IERC20Upgradeable[] coins;
    WETH weth;
    CurveLpTokenPriceOracleNoRegistry curveLPTokenPriceOracleNoRegistry;
    ChainlinkPriceOracleV2 chainlinkOracle;
    ISynthereumLiquidityPool synthereumLiquiditiyPool;
    MasterPriceOracle masterPriceOracle;
    UniswapTwapPriceOracleV2Factory twapOraclesFactory;
    IUniswapV2Factory uniswapV2Factory;
  }

  mapping(uint256 => ChainConfig) private chainConfigs;

  constructor() {
    chainConfigs[56] = ChainConfig({
      pool: IERC20Upgradeable(0x160CAed03795365F3A589f10C379FfA7d75d4E76),
      lpToken: IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452),
      lpTokenWhale: 0x8D7408C2b3154F9f97fc6dd24cd36143908d1E52,
      coins: new IERC20Upgradeable[](2),
      weth: WETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)),
      curveLPTokenPriceOracleNoRegistry: CurveLpTokenPriceOracleNoRegistry(0x44ea7bAB9121D97630b5DB0F92aAd75cA5A401a3),
      chainlinkOracle: ChainlinkPriceOracleV2(0x2B5311De4555506400273CfaAFb4393F01EC2567),
      synthereumLiquiditiyPool: ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49),
      masterPriceOracle: MasterPriceOracle(0xC3ABf2cB82C65474CeF8F90f1a4DAe79929B1940),
      twapOraclesFactory: UniswapTwapPriceOracleV2Factory(0x8853F26C198fd5693E7886C081164E0c3F0a4E51),
      uniswapV2Factory: IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73)
    });
    chainConfigs[56].coins[0] = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    chainConfigs[56].coins[1] = IERC20Upgradeable(0x316622977073BBC3dF32E7d2A9B3c77596a0a603);

    chainConfigs[97] = ChainConfig({
      pool: IERC20Upgradeable(0x160CAed03795365F3A589f10C379FfA7d75d4E76),
      lpToken: IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452),
      lpTokenWhale: 0x0000000000000000000000000000000000000000,
      coins: new IERC20Upgradeable[](2),
      weth: WETH(payable(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd)),
      curveLPTokenPriceOracleNoRegistry: CurveLpTokenPriceOracleNoRegistry(0x0000000000000000000000000000000000000000),
      chainlinkOracle: ChainlinkPriceOracleV2(0x0000000000000000000000000000000000000000),
      synthereumLiquiditiyPool: ISynthereumLiquidityPool(0x0000000000000000000000000000000000000000),
      masterPriceOracle: MasterPriceOracle(0xC3ABf2cB82C65474CeF8F90f1a4DAe79929B1940),
      twapOraclesFactory: UniswapTwapPriceOracleV2Factory(0x944fed08a91983d06f653E9F55Eca995316Ccd3e),
      uniswapV2Factory: IUniswapV2Factory(0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc)
    });
    chainConfigs[97].coins[0] = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    chainConfigs[97].coins[1] = IERC20Upgradeable(0x8BaBbB98678facC7342735486C851ABD7A0d17Ca);

    chainConfigs[1284] = ChainConfig({
      pool: IERC20Upgradeable(0x0000000000000000000000000000000000000000),
      lpToken: IERC20Upgradeable(0x0000000000000000000000000000000000000000),
      lpTokenWhale: 0x0000000000000000000000000000000000000000,
      coins: new IERC20Upgradeable[](2),
      weth: WETH(payable(0xAcc15dC74880C9944775448304B263D191c6077F)),
      curveLPTokenPriceOracleNoRegistry: CurveLpTokenPriceOracleNoRegistry(0x0000000000000000000000000000000000000000),
      chainlinkOracle: ChainlinkPriceOracleV2(0x0000000000000000000000000000000000000000),
      synthereumLiquiditiyPool: ISynthereumLiquidityPool(0x0000000000000000000000000000000000000000),
      masterPriceOracle: MasterPriceOracle(0x0000000000000000000000000000000000000000),
      twapOraclesFactory: UniswapTwapPriceOracleV2Factory(0x0000000000000000000000000000000000000000),
      uniswapV2Factory: IUniswapV2Factory(0x985BcA32293A7A496300a48081947321177a86FD)
    });
    chainConfigs[1284].coins[0] = IERC20Upgradeable(0x0000000000000000000000000000000000000000);
    chainConfigs[1284].coins[1] = IERC20Upgradeable(0x0000000000000000000000000000000000000000);

    chainConfig = chainConfigs[block.chainid];
  }

  modifier shouldRun(bool run) {
    if (run) {
      _;
    }
  }

  uint256 BSC_MAINNET = 56;
  uint256 EVMOS_TESTNET = 9000;
  uint256 MOONBEAM_MAINNET = 1284;
  uint256 BSC_CHAPEL = 97;

  function forChains(uint256 id0) public view returns (bool) {
    return block.chainid == id0;
  }

  function forChains(uint256 id0, uint256 id1) public view returns (bool) {
    return block.chainid == id0 || block.chainid == id1;
  }
}
