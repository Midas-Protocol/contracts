// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { WETH } from "@rari-capital/solmate/src/tokens/WETH.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

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
    address whale;
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
      whale: 0x516E5B72C3fD2D2E59835C82005ba6A2BC5788A4,
      coins: new IERC20Upgradeable[](2),
      weth: WETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)),
      curveLPTokenPriceOracleNoRegistry: CurveLpTokenPriceOracleNoRegistry(0x274F5dFBDB6af889124EFcfA065A247A15243EC2),
      chainlinkOracle: ChainlinkPriceOracleV2(0xb87bC7F78F8c87d37e6FA2abcADF4C6Da0bc124A),
      synthereumLiquiditiyPool: ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49),
      masterPriceOracle: MasterPriceOracle(0x37CF9eA8C6Bb6C020D4B5e7C3C462B02313aaFF4),
      twapOraclesFactory: UniswapTwapPriceOracleV2Factory(0x98EC86b8d2CbAf5329A032b4F655CF0ff6cc029a),
      uniswapV2Factory: IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73)
    });
    chainConfigs[56].coins[0] = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    chainConfigs[56].coins[1] = IERC20Upgradeable(0x316622977073BBC3dF32E7d2A9B3c77596a0a603);

    chainConfig = chainConfigs[block.chainid];
  }

  modifier shouldRun(bool run) {
    if(run) {
      _;
    }
  }

  uint BSC_MAINNET = 56;
  uint EVMOS_TESTNET = 9000;

  function forChains(uint id0) public view returns (bool) {
    return block.chainid == id0;
  }

  function forChains(uint id0, uint id1) public view returns (bool) {
    return block.chainid == id0
      || block.chainid == id1;
  }
}
