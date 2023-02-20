// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import { Comptroller } from "../../compound/Comptroller.sol";
import { ComptrollerInterface } from "../../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { IAutoHedgeLeveragedPosition } from "../../external/autonomy/IAutoHedgeLeveragedPosition.sol";
import { AutoHedgeOracle } from "../../oracles/default/AutoHedgeOracle.sol";
import { IAutoHedgeLeveragedPositionFactory } from "../../external/autonomy/IAutoHedgeLeveragedPositionFactory.sol";
import { IAutoHedgeStableVolatilePairUpgradeableV2 } from "../../external/autonomy/IAutoHedgeStableVolatilePairUpgradeableV2.sol";
import { IFlashloanWrapper } from "../../external/autonomy/IFlashloanWrapper.sol";

import { BaseTest } from "../config/BaseTest.t.sol";

contract AutoHedgeLeveragedPositionTest is BaseTest {
  Comptroller comptroller = Comptroller(0xEF0B026F93ba744cA3EDf799574538484c2C4f80);
  address POOL_ADMIN = 0x7dB8d33114462e032E5bf636D271f8680619Ba25;
  address FUSE_ADMIN = 0xFc1f56C58286E7215701A773b61bFf2e18A177dE;
  address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address JRM = 0x8A163f41414c005c3f551f2179bC9Ad8dcadE1C6;
  address CER20_IMPL_ADDRESS = 0x88d90463b4689aA9a622b711B0FA73c936E04B55;
  address FACTORY_PROXY = 0xa91799f00cA544ADb8bC4ea98B3406f59076E0Ee;
  address WBNB_BUSD_PAIR = 0x457c94c9880fc5D576392310608355Cde22F9943;
  address PCS_FACTORY_ADDR = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
  address PCS_WBNB_BUSD_ADDR = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
  address SUSHI_BENTOBOX_ADDR = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
  address PAIR_V1_BUSD_WBNB_ADDRESS = 0xd591c027F5415944E9183365cD6F192C6AcA4C71;

  function setUpBaseContracts() public {}

  function deployOracle() public {
    AutoHedgeOracle ahOracle = new AutoHedgeOracle(wbnb);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(ahOracle));
    MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
    vm.prank(mpo.admin());
    mpo.add(asArray(WBNB_BUSD_PAIR), oracles);
  }

  function deployMarket() public fork(BSC_MAINNET) {
    vm.roll(1);
    vm.prank(POOL_ADMIN);
    comptroller._deployMarket(
      false,
      abi.encode(
        WBNB_BUSD_PAIR,
        comptroller,
        payable(address(FUSE_ADMIN)),
        InterestRateModel(address(JRM)),
        "BUSD BNB AHLP",
        "fAH-BUSD-BNB-185",
        address(CER20_IMPL_ADDRESS),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );
  }

  function testDeployAutoHedge() public fork(BSC_MAINNET) {
    deployOracle();
    deployMarket();
  }
}
