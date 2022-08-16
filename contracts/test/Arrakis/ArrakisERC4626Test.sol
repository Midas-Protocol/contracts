// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, ArrakisERC4626, IGuniPool } from "../../compound/strategies/ArrakisERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

// Using 2BRL
// Tested on block 19052824
contract ArrakisERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  uint256 withdrawalFee = 10;

  IGuniPool pool; // ERC4626 => underlyingToken => beefyStrategy
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewardsPlugin flywheelRewards;
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D; // beefyStrategy => underlyingToken => lpChef
  address bob = 0xbB60ADbe38B4e6ab7fb0f9546C2C1b665B86af11; // beefyStrategy => underlyingToken => .
  // address JRT_MIMO = 0xAFC780bb79E308990c7387AB8338160bA8071B67; // reward token
  address JRT_MIMO = 0xADAC33f543267c4D59a8c299cF804c303BC3e4aC;
  address marketAddress;
  ERC20 marketKey;

  constructor() WithPool() {
    flywheel = new FlywheelCore(
      ERC20(JRT_MIMO),
      FlywheelDynamicRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);
  }

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("arrakis-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    (address _asset, address _pool) = abi.decode(data, (address, address));

    pool = IGuniPool(_pool);
    underlyingToken = MockERC20(_asset);

    plugin = MidasERC4626(address(new ArrakisERC4626(underlyingToken, flywheel, pool)));

    initialStrategyBalance = pool.totalStake();
    // initialStrategySupply = pool.totalSupply();
    emit log("0");
    deployCErc20PluginRewardsDelegate(ERC4626(address(plugin)), 0.9e18);
    emit log("1");
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    emit log("2");
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    emit log("3");
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    emit log("4");
    assertEq(address(cToken.plugin()), address(plugin));
  
    emit log("5");
    cToken.approve(address(JRT_MIMO), address(flywheelRewards));

    emit log("6");
    flywheel.addStrategyForRewards(ERC20(address(plugin)));
    
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(pool), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(pool));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return pool.stake(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return pool.totalStake();
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    // return (depositAmount * pool.totalStake()) / pool.balanceOf();
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol)
    public
    override
    shouldRun(forChains(POLYGON_MAINNET))
  {
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
      address(ArrakisERC4626(address(plugin)).pool()),
      address(pool),
      string(abi.encodePacked("!pool ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    vm.warp(block.timestamp + 150000);
    // vm.roll(10);

    deposit(address(this), depositAmount / 2);
    // (uint256 amount, ) = ArrakisERC4626(address(plugin)).pool()._users(address(plugin));
    // emit log_uint(amount);
    emit log("reward token amount");
    emit log_uint(ERC20(JRT_MIMO).balanceOf(address(plugin)));
    emit log_uint(ERC20(JRT_MIMO).balanceOf(address(this)));
    assertGt(ERC20(JRT_MIMO).balanceOf(address(plugin)), 0.0006 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
  }
}
