// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../FusePoolDirectory.sol";
import "../FuseFeeDistributor.sol";
import "../oracles/MasterPriceOracle.sol";
import "../compound/CErc20.sol";
import "../compound/CErc20PluginRewardsDelegate.sol";
import "../midas/strategies/MidasERC4626.sol";
import "../midas/strategies/flywheel/MidasFlywheelCore.sol";

contract ProtocolRevenueTest is BaseTest {
  MasterPriceOracle internal mpo;
  FusePoolDirectory internal fpd;
  FuseFeeDistributor internal ffd;

  function afterForkSetUp() internal override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testFuseAdminFeesBsc() public fork(BSC_MAINNET) {
    _testFuseAdminFees();
  }

  function testFuseAdminFeesPolygon() public fork(POLYGON_MAINNET) {
    _testFuseAdminFees();
  }

  function testFuseAdminFeesMoonbeam() public fork(MOONBEAM_MAINNET) {
    _testFuseAdminFees();
  }

  function _testFuseAdminFees() internal {
    address ffdAddress = address(ffd);
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    uint256 fuseFeesTotal = 0;

    for (uint8 i = 0; i < pools.length; i++) {
      Comptroller pool = Comptroller(pools[i].comptroller);
      address fuseAdmin = pool.fuseAdmin();
      if (fuseAdmin != ffdAddress) {
        emit log_address(fuseAdmin);
        emit log_address(ffdAddress);
        revert("fuse admin is not the FFD");
      }

      CTokenInterface[] memory markets = pool.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CTokenInterface market = markets[j];

        uint256 fuseFees = market.totalFuseFees();
        //        emit log("fuse fees in underlying for market");
        //        emit log_address(address(pool));
        //        emit log_address(address(market));
        //        emit log_uint(fuseFees);

        // uint256 underlyingPrice = mpo.price(CErc20(address(market)).underlying());
        uint256 underlyingPrice = mpo.getUnderlyingPrice(ICToken(address(market)));
        uint256 nativeFee = (fuseFees * underlyingPrice) / 1e18;

        fuseFeesTotal += nativeFee;
      }
    }

    emit log("");
    emit log("total fuse fees in native");
    emit log_uint(fuseFeesTotal);
  }

  function testErc4626PluginFeesBsc() public fork(BSC_MAINNET) {
    _testErc4626PluginFees();
  }

  function testErc4626PluginFeesPolygon() public fork(POLYGON_MAINNET) {
    _testErc4626PluginFees();
  }

  function testErc4626PluginFeesMoonbeam() public fork(MOONBEAM_MAINNET) {
    _testErc4626PluginFees();
  }

  function _testErc4626PluginFees() internal {
    uint256 pluginFeesTotal = 0;
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    for (uint8 i = 0; i < pools.length; i++) {
      Comptroller pool = Comptroller(pools[i].comptroller);
      CTokenInterface[] memory markets = pool.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20PluginRewardsDelegate market = CErc20PluginRewardsDelegate(address(markets[j]));

        try market.plugin() returns (IERC4626 pluginIERC4626) {
          address pluginAddress = address(pluginIERC4626);
          MidasERC4626 plugin = MidasERC4626(address(pluginAddress));

          try plugin.performanceFee() returns (uint256 performanceFee) {
            uint256 performanceFeeAssets;
            ERC20Upgradeable asset = ERC20Upgradeable(plugin.asset());
            {
              uint256 shareValue = plugin.convertToAssets(10**asset.decimals());
              uint256 supply = plugin.totalSupply();
              uint256 vaultShareHWM = plugin.vaultShareHWM();
              uint256 performanceFeeShares = (performanceFee * (shareValue - vaultShareHWM) * supply) / 1e36;

              performanceFeeAssets = plugin.previewRedeem(performanceFeeShares);
            }

            uint256 underlyingPrice = mpo.price(address(asset));
            uint256 nativeFee = (performanceFeeAssets * underlyingPrice * (10**(18 - asset.decimals()))) / 1e18;

            pluginFeesTotal += nativeFee;
          } catch {
            emit log("plugin at this address has no performance fee");
            emit log_address(pluginAddress);
          }
        } catch {
          // not a plugin market
          continue;
        }
      }
    }

    emit log("total plugin performance fees in native");
    emit log_uint(pluginFeesTotal);
  }

  function testFlywheelFeesBsc() public fork(BSC_MAINNET) {
    _testFlywheelFees();
  }

  function testFlywheelFeesPolygon() public fork(POLYGON_MAINNET) {
    _testFlywheelFees();
  }

  function testFlywheelFeesMoonbeam() public fork(MOONBEAM_MAINNET) {
    _testFlywheelFees();
  }

  function _testFlywheelFees() internal {
    uint256 flywheelFeesTotal = 0;
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    for (uint8 i = 0; i < pools.length; i++) {
      Comptroller pool = Comptroller(pools[i].comptroller);
      address[] memory flywheels = pool.getRewardsDistributors();
      for (uint8 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = MidasFlywheelCore(flywheels[j]);
        try flywheel.performanceFee() returns (uint256 performanceFeeRewardTokens) {
          ERC20 rewardToken = flywheel.rewardToken();
          uint256 rewardTokenPrice = mpo.price(address(rewardToken));
          uint256 nativeFee = (performanceFeeRewardTokens * rewardTokenPrice * (10**(18 - rewardToken.decimals()))) /
            1e18;

          flywheelFeesTotal += nativeFee;
        } catch {
          emit log("this flywheel is not a performance fee flywheel");
          emit log_address(flywheels[j]);
        }
      }
    }

    emit log("total flywheel performance fees in native");
    emit log_uint(flywheelFeesTotal);
  }
}
