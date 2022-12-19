// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { EllipsisERC4626, ILpTokenStaker } from "../../midas/strategies/EllipsisERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IEllipsisRewardToken {
  function mint(address, uint256) external;

  function burnFrom(address, uint256) external;
}

contract EllipsisERC4626Test is AbstractERC4626Test {
  ILpTokenStaker lpTokenStaker = ILpTokenStaker(0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe);
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;
  uint256 poolId;
  address epxToken = 0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71;
  address minter = 0x408A61e158D7BC0CD339BC76917b8Ea04739d473;
  address marketAddress;
  address asset;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardTokens;

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    sendUnderlyingToken(depositAmount, address(this));
    asset = abi.decode(data, (address));

    testPreFix = _testPreFix;

    flywheel = new FlywheelCore(
      ERC20(epxToken),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    EllipsisERC4626 ellipsisERC4626 = new EllipsisERC4626();
    ellipsisERC4626.initialize(ERC20Upgradeable(asset), FlywheelCore(address(flywheel)), lpTokenStaker);

    initialStrategyBalance = getStrategyBalance();

    plugin = ellipsisERC4626;

    marketKey = ERC20(address(plugin));
    flywheel.addStrategyForRewards(marketKey);
  }

  function increaseAssetsInVault() public override {
    vm.prank(minter);
    IEllipsisRewardToken(address(underlyingToken)).mint(address(1), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(minter);
    IEllipsisRewardToken(address(underlyingToken)).burnFrom(address(1), 1e18);
  }

  function getDepositShares() public view override returns (uint256) {
    (uint256 amount, ) = lpTokenStaker.userInfo(asset, address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return ERC20(asset).balanceOf(address(lpTokenStaker));
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    emit log("this is testInitializeValues");
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(
      address(EllipsisERC4626(address(plugin)).lpTokenStaker()),
      address(lpTokenStaker),
      string(abi.encodePacked("!pool ", testPreFix))
    );
  }
}
