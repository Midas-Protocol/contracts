// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import "ds-test/test.sol";
// import "forge-std/Vm.sol";
// import "../helpers/WithPool.sol";
// import "../config/BaseTest.t.sol";

// import { MidasERC4626, AutofarmERC4626, IAutofarmV2, IAutoStrat } from "../../midas/strategies/AutofarmERC4626.sol";
// import { ERC20 } from "solmate/tokens/ERC20.sol";
// import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
// import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
// import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
// import { Authority } from "solmate/auth/Auth.sol";
// import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
// import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
// import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
// import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
// import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

// struct RewardsCycle {
//   uint32 start;
//   uint32 end;
//   uint192 reward;
// }

// contract AutofarmERC4626Test is AbstractERC4626Test {
//   using FixedPointMathLib for uint256;

//   IAutofarmV2 autoFarm = IAutofarmV2(0x0895196562C7868C5Be92459FaE7f877ED450452);
//   FlywheelCore flywheel;
//   FuseFlywheelDynamicRewards flywheelRewards;
//   uint256 poolId;
//   address autoToken = 0x4508ABB72232271e452258530D4Ed799C685eccb;
//   address marketAddress;
//   ERC20 marketKey;
//   ERC20Upgradeable[] rewardTokens;

//   constructor() WithPool() {}

//   function setUp(string memory _testPreFix, bytes calldata data) public override {
//     sendUnderlyingToken(depositAmount, address(this));
//     (address _asset, uint256 _poolId) = abi.decode(data, (address, uint256));

//     testPreFix = _testPreFix;
//     poolId = _poolId;

//     flywheel = new FlywheelCore(
//       ERC20(autoToken),
//       IFlywheelRewards(address(0)),
//       IFlywheelBooster(address(0)),
//       address(this),
//       Authority(address(0))
//     );

//     flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
//     flywheel.setFlywheelRewards(flywheelRewards);

//     AutofarmERC4626 autofarmERC4626 = new AutofarmERC4626();
//     autofarmERC4626.initialize(
//       ERC20Upgradeable(_asset),
//       FlywheelCore(address(flywheel)),
//       poolId,
//       ERC20Upgradeable(address(autoToken)),
//       autoFarm
//     );

//     initialStrategyBalance = getStrategyBalance();

//     plugin = autofarmERC4626;

//     marketKey = ERC20(address(plugin));
//     flywheel.addStrategyForRewards(marketKey);

//     // Add mockStrategy to Autofarm
//     // MockAutofarmV2(autoFarm).add(ERC20(address(_asset)), 1, address(mockStrategy));
//   }

//   function increaseAssetsInVault() public override {
//     deal(address(underlyingToken), address(1), 1e18);
//     vm.prank(address(1));
//     underlyingToken.transfer(address(autoFarm), 1e18);
//   }

//   function decreaseAssetsInVault() public override {
//     vm.prank(address(autoFarm));
//     underlyingToken.transfer(address(1), 2e18);
//   }

//   function getDepositShares() public view override returns (uint256) {
//     uint256 realShares = autoFarm.stakedWantTokens(poolId, address(plugin));

//     return realShares;
//   }

//   function getStrategyBalance() public view override returns (uint256) {
//     (address want, , , , address strat) = autoFarm.poolInfo(poolId);

//     return ERC20(want).balanceOf(IAutoStrat(strat).vTokenAddress());
//   }

//   function getExpectedDepositShares() public view override returns (uint256) {
//     return depositAmount;
//   }

//   // function getExpectedDepositAmount() public view override returns (uint256) {
//   //   return depositAmount * 9990 / 10000;
//   // }

//   function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
//     assertEq(
//       plugin.name(),
//       string(abi.encodePacked("Midas ", assetName, " Vault")),
//       string(abi.encodePacked("!name ", testPreFix))
//     );
//     assertEq(
//       plugin.symbol(),
//       string(abi.encodePacked("mv", assetSymbol)),
//       string(abi.encodePacked("!symbol ", testPreFix))
//     );
//     assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
//     assertEq(
//       address(AutofarmERC4626(address(plugin)).autofarm()),
//       address(autoFarm),
//       string(abi.encodePacked("!pool ", testPreFix))
//     );
//   }

//   // function testAccumulatingRewardsOnDeposit() public {
//   //   deposit(address(this), depositAmount / 2);
//   //   deal(address(autoToken), address(this), 100e18);
//   //   ERC20(autoToken).transfer(address(pool), 100e18);

//   //   uint256 expectedReward = pool.pendingMIMO(address(plugin));

//   //   deposit(address(this), depositAmount / 2);

//   //   assertEq(
//   //     ERC20(autoToken).balanceOf(address(plugin)),
//   //     expectedReward,
//   //     string(abi.encodePacked("!mimoBal ", testPreFix))
//   //   );
//   // }

//   // function testAccumulatingRewardsOnWithdrawal() public {
//   //   deposit(address(this), depositAmount);
//   //   deal(address(autoToken), address(this), 100e18);
//   //   ERC20(autoToken).transfer(address(pool), 100e18);

//   //   uint256 expectedReward = pool.pendingMIMO(address(plugin));

//   //   plugin.withdraw(1, address(this), address(this));

//   //   assertEq(
//   //     ERC20(autoToken).balanceOf(address(plugin)),
//   //     expectedReward,
//   //     string(abi.encodePacked("!mimoBal ", testPreFix))
//   //   );
//   // }

//   // function testClaimRewards() public {
//   //   vm.startPrank(address(this));
//   //   underlyingToken.approve(marketAddress, depositAmount);
//   //   CErc20(marketAddress).mint(depositAmount);
//   //   vm.stopPrank();

//   //   deal(address(underlyingToken), address(this), depositAmount);
//   //   deposit(address(this), depositAmount);

//   //   deal(address(autoToken), address(this), 100e18);
//   //   ERC20(autoToken).transfer(address(pool), 100e18);
//   //   uint256 expectedReward = pool.pendingMIMO(address(plugin));

//   //   (uint32 mimoStart, uint32 mimoEnd, uint192 mimoReward) = flywheelRewards.rewardsCycle(
//   //     ERC20(address(marketAddress))
//   //   );

//   //   emit log_named_uint("mimoReward", mimoReward);

//   //   // Rewards can be transfered in the next cycle
//   //   assertEq(mimoEnd, 0, string(abi.encodePacked("!mimoEnd ", testPreFix)));

//   //   // Reward amount is still 0
//   //   assertEq(mimoReward, 0, string(abi.encodePacked("!mimoReward ", testPreFix)));

//   //   vm.warp(block.timestamp + 150);
//   //   vm.roll(20);

//   //   // Call accrue as proxy for withdraw/deposit to claim rewards
//   //   flywheel.accrue(ERC20(marketAddress), address(this));

//   //   // Accrue rewards to send rewards to flywheelRewards
//   //   flywheel.accrue(ERC20(marketAddress), address(this));

//   //   (mimoStart, mimoEnd, mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

//   //   emit log_named_uint("mimoReward after", mimoReward);

//   //   // Rewards can be transfered in the next cycle
//   //   assertGt(mimoEnd, 1000000000, string(abi.encodePacked("!2.mimoEnd ", testPreFix)));
//   //   assertApproxEqAbs(
//   //     mimoReward,
//   //     expectedReward,
//   //     uint256(1000),
//   //     string(abi.encodePacked("!2.mimoReward ", testPreFix))
//   //   );

//   //   vm.warp(block.timestamp + 150);
//   //   vm.roll(20);

//   //   (mimoStart, mimoEnd, mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

//   //   emit log_named_uint("mimoReward after 111", mimoReward);

//   //   flywheel.accrue(ERC20(marketAddress), address(this));

//   //   // Claim Rewards for the user
//   //   flywheel.claimRewards(address(this));

//   //   assertApproxEqAbs(
//   //     ERC20(autoToken).balanceOf(address(this)),
//   //     expectedReward,
//   //     uint256(1000),
//   //     string(abi.encodePacked("!mimoBal User ", testPreFix))
//   //   );
//   //   assertEq(
//   //     ERC20(autoToken).balanceOf(address(flywheel)),
//   //     0,
//   //     string(abi.encodePacked("!mimoBal Flywheel ", testPreFix))
//   //   );
//   // }
// }
