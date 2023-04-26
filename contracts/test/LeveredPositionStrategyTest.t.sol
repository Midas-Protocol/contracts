// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { Unitroller } from "../compound/Unitroller.sol";

import "../midas/vault/levered/LeveredPositionStrategy.sol";
import { AddressesProvider } from "../midas/AddressesProvider.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionStrategyTest is MarketsTest, ILeveredPositionFactory {
  address jBRLWhale = 0xBe9E8Ec25866B21bA34e97b9393BCabBcB4A5C86;
  // Jarvis jFiat bsc pool 0x31d76A64Bc8BbEffb601fac5884372DEF910F044
  ICErc20 collateralMarket = ICErc20(0x82A3103bc306293227B756f7554AfAeE82F8ab7a); // jBRL market
  ICErc20 stableMarket = ICErc20(0xa7213deB44f570646Ea955771Cc7f39B58841363); // bUSD market

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    address pool = collateralMarket.comptroller();
    _upgradePool(Unitroller(payable(pool)));
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));

    vm.startPrank(ap.owner());
    ap.setJarvisPool(
      collateralMarket.underlying(), // syntheticToken
      stableMarket.underlying(), // collateralToken
      0x0fD8170Dc284CD558325029f6AEc1538c7d99f49, // liquidityPool
      60 * 40 // expirationTime
    );
    vm.stopPrank();
  }

  function testOpenLeveredPosition() public fork(BSC_MAINNET) {
    address positionOwner = address(this);
    address jBRLAddress = collateralMarket.underlying();
    IERC20Upgradeable jBRL = IERC20Upgradeable(jBRLAddress);

    vm.prank(jBRLWhale);
    jBRL.transfer(address(this), 1e22);

    LeveredPositionStrategy position = new LeveredPositionStrategy(positionOwner, collateralMarket, stableMarket);

    jBRL.approve(address(position), 1e36);

    position.fundPosition(IERC20Upgradeable(jBRLAddress), 1e22);
    position.adjustLeverageRatio(1.5e18);

    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    emit log_named_uint("max ratio", position.getMaxLeverageRatio());
    emit log_named_uint("withdraw amount", position.closePosition());
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
  }

  function getFundingStrategy(IERC20Upgradeable fundingToken, IERC20Upgradeable outputToken)
    external
    returns (IFundsConversionStrategy fundingStrategy, bytes memory strategyData)
  {
    // JarvisLiquidatorFunder
    AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
    for (uint256 i = 0; i < pools.length; i++) {
      AddressesProvider.JarvisPool memory pool = pools[i];
      if (pool.collateralToken == address(fundingToken)) {
        require(address(outputToken) == pool.syntheticToken, "!output token mismatch");
        strategyData = abi.encode(pool.collateralToken, pool.liquidityPool, pool.expirationTime);
        fundingStrategy = new JarvisLiquidatorFunder();
        break;
      } else if (pool.syntheticToken == address(fundingToken)) {
        require(address(outputToken) == pool.collateralToken, "!output token mismatch");
        strategyData = abi.encode(pool.syntheticToken, pool.liquidityPool, pool.expirationTime);
        fundingStrategy = new JarvisLiquidatorFunder();
        break;
      }
    }
  }
}
