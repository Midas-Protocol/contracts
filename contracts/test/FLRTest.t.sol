// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { IERC20MetadataUpgradeable, IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { FlywheelStaticRewards } from "flywheel-v2/rewards/FlywheelStaticRewards.sol";
import { FuseFlywheelCore } from "fuse-flywheel/FuseFlywheelCore.sol";

import { CErc20 } from "../compound/CErc20.sol";
import { IonicFlywheelLensRouter, IComptroller, ICErc20, ERC20, IPriceOracle } from "../ionic/strategies/flywheel/IonicFlywheelLensRouter.sol";
import { IonicFlywheel } from "../ionic/strategies/flywheel/IonicFlywheel.sol";
import { PoolDirectory } from "../PoolDirectory.sol";
import { IonicFlywheelCore } from "../ionic/strategies/flywheel/IonicFlywheelCore.sol";

contract FLRTest is BaseTest {
  address rewardToken;

  IonicFlywheel flywheel;
  FlywheelStaticRewards rewards;
  IonicFlywheelLensRouter lensRouter;

  PoolDirectory internal fpd;

  function afterForkSetUp() internal override {
    fpd = PoolDirectory(ap.getAddress("PoolDirectory"));
    lensRouter = new IonicFlywheelLensRouter(fpd);
  }

  function setUpFlywheel(
    address _rewardToken,
    address mkt,
    IComptroller comptroller,
    address admin
  ) public {
    flywheel = new IonicFlywheel();
    flywheel.initialize(
      ERC20(_rewardToken),
      FlywheelStaticRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this)
    );

    rewards = new FlywheelStaticRewards(FuseFlywheelCore(address(flywheel)), address(this), Authority(address(0)));
    flywheel.setFlywheelRewards(rewards);

    flywheel.addStrategyForRewards(ERC20(mkt));

    // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
    vm.prank(admin);
    require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

    // seed rewards to flywheel
    deal(_rewardToken, address(rewards), 1_000_000 * (10**ERC20(_rewardToken).decimals()));

    // Start reward distribution at 1 token per second
    rewards.setRewardsInfo(
      ERC20(mkt),
      FlywheelStaticRewards.RewardsInfo({
        rewardsPerSecond: uint224(789 * 10**ERC20(_rewardToken).decimals()),
        rewardsEndTimestamp: 0
      })
    );
  }

  function testFuseFlywheelLensRouterBsc() public debuggingOnly fork(BSC_MAINNET) {
    rewardToken = address(0x71be881e9C5d4465B3FfF61e89c6f3651E69B5bb); // BRZ
    emit log_named_address("rewardToken", address(rewardToken));
    address mkt = 0x159A529c00CD4f91b65C54E77703EDb67B4942e4;
    setUpFlywheel(rewardToken, mkt, IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117), ap.owner());
    emit log_named_uint("mkt dec", ERC20(mkt).decimals());

    (uint224 index, uint32 lastUpdatedTimestamp) = flywheel.strategyState(ERC20(mkt));

    emit log_named_uint("index", index);
    emit log_named_uint("lastUpdatedTimestamp", lastUpdatedTimestamp);
    emit log_named_uint("block.timestamp", block.timestamp);
    emit log_named_uint(
      "underlying price",
      IPriceOracle(address(IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117).oracle())).price(
        address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
      )
    );

    vm.warp(block.timestamp + 10);

    (uint224 rewardsPerSecond, uint32 rewardsEndTimestamp) = rewards.rewardsInfo(ERC20(mkt));

    vm.prank(address(flywheel));
    uint256 accrued = rewards.getAccruedRewards(ERC20(mkt), lastUpdatedTimestamp);

    emit log_named_uint("accrued", accrued);
    emit log_named_uint("rewardsPerSecond", rewardsPerSecond);
    emit log_named_uint("rewardsEndTimestamp", rewardsEndTimestamp);
    emit log_named_uint("mkt ts", ERC20(mkt).totalSupply());

    IonicFlywheelLensRouter.MarketRewardsInfo[] memory marketRewardsInfos = lensRouter.getPoolMarketRewardsInfo(
      IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117)
    );
    for (uint256 i = 0; i < marketRewardsInfos.length; i++) {
      if (address(marketRewardsInfos[i].market) != mkt) {
        emit log("NO REWARDS INFO");
        continue;
      }

      emit log("");
      emit log_named_address("RUNNING FOR MARKET", address(marketRewardsInfos[i].market));
      for (uint256 j = 0; j < marketRewardsInfos[i].rewardsInfo.length; j++) {
        emit log_named_uint(
          "rewardSpeedPerSecondPerToken",
          marketRewardsInfos[i].rewardsInfo[j].rewardSpeedPerSecondPerToken
        );
        emit log_named_uint("rewardTokenPrice", marketRewardsInfos[i].rewardsInfo[j].rewardTokenPrice);
        emit log_named_uint("formattedAPR", marketRewardsInfos[i].rewardsInfo[j].formattedAPR);
        emit log_named_address("rewardToken", address(marketRewardsInfos[i].rewardsInfo[j].rewardToken));
      }
    }
  }

  function testMoonbeamFlywheelLensRouter() public debuggingOnly fork(MOONBEAM_MAINNET) {
    ERC20 market = ERC20(0xa9736bA05de1213145F688e4619E5A7e0dcf4C72);
    rewardToken = address(0x931715FEE2d06333043d11F658C8CE934aC61D0c);
    IComptroller comptroller = IComptroller(0xeB2D3A9D962d89b4A9a34ce2bF6a2650c938e185);
    // setUpFlywheel(rewardToken, address(market), comptroller, ap.owner());

    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72),
      abi.encode(34315417857347)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685),
      abi.encode(15786961530391797)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector),
      abi.encode(10)
    );

    IonicFlywheelLensRouter.MarketRewardsInfo[] memory info = lensRouter.getPoolMarketRewardsInfo(comptroller);
    for (uint8 i = 0; i < info.length; i++) {
      for (uint8 j = 0; j < info[i].rewardsInfo.length; j++) {
        if (info[i].rewardsInfo[j].formattedAPR != 0) {
          emit log("");
          emit log_named_address("market", address(info[i].market));
          emit log_named_uint("rewardSpeedPerSecondPerToken", info[i].rewardsInfo[j].rewardSpeedPerSecondPerToken);
          emit log_named_uint("formattedAPR", info[i].rewardsInfo[j].formattedAPR);
          emit log_named_uint("rewardTokenPrice", info[i].rewardsInfo[j].rewardTokenPrice);
          emit log_named_address("rewardToken", info[i].rewardsInfo[j].rewardToken);
          emit log_named_uint("totalSupply", info[i].market.totalSupply());
        }
      }
    }
  }

  function testBscLensRouter() public fork(BSC_MAINNET) {
    IComptroller pool = IComptroller(0x1851e32F34565cb95754310b031C5a2Fc0a8a905);
    address user = 0x927d81b91c41D1961e3A7d24847b95484e60C626;
    IonicFlywheelLensRouter router = IonicFlywheelLensRouter(ap.getAddress("IonicFlywheelLensRouter"));

    router.claimRewardsForPool(user, pool);
  }

  function testChapelRouter() public fork(BSC_CHAPEL) {
    IonicFlywheelLensRouter router = IonicFlywheelLensRouter(0x3391ed1C5203168337Fa827cB5Ac8BB8B60D93B7);
    router.getPoolMarketRewardsInfo(IComptroller(0x044c436b2f3EF29D30f89c121f9240cf0a08Ca4b));
  }

  function testMoonbeamLensRouter() public fork(MOONBEAM_MAINNET) {
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72),
      abi.encode(34315417857347)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685),
      abi.encode(15786961530391797)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector),
      abi.encode(10)
    );

    IonicFlywheelLensRouter router = IonicFlywheelLensRouter(ap.getAddress("IonicFlywheelLensRouter"));

    (, PoolDirectory.Pool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      router.getPoolMarketRewardsInfo(IComptroller(pools[i].comptroller));
    }
  }
}
