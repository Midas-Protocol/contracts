// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "./config/BaseTest.t.sol";
import "../compound/strategies/BeamERC4626.sol";
import "./mocks/beam/MockVault.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

contract MockBoringERC20 is MockERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint8 decimal
  ) MockERC20(name, symbol, decimal) {}

  function safeTransferFrom(
    address from,
    address to,
    uint256 amount
  ) public {
    transferFrom(from, to, amount);
  }

  function safeTransfer(address to, uint256 amount) public {
    transfer(to, amount);
  }
}

contract BeamERC4626Test is BaseTest {
  BeamERC4626 beamErc4626;
  MockVault mockBeamChef;
  MockBoringERC20 testToken;
  MockERC20 glintToken;
  ERC20 marketKey;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  uint256 depositAmount = 100e18;

  function setUp() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    testToken = new MockBoringERC20("TestToken", "TST", 18);
    glintToken = new MockERC20("GlintToken", "GLINT", 18);
    mockBeamChef = new MockVault(IBoringERC20(address(testToken)), 0, address(0), 0, address(0));
    vm.warp(1);
    vm.roll(1);

    flywheel = new FlywheelCore(
      glintToken,
      FlywheelDynamicRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    beamErc4626 = new BeamERC4626(testToken, "test", "tst", 0, glintToken, IBeamVault(address(mockBeamChef)), flywheel);
    marketKey = ERC20(address(beamErc4626));
    flywheel.addStrategyForRewards(marketKey);

    IMultipleRewards[] memory rewarders = new IMultipleRewards[](0);
    mockBeamChef.add(1, IBoringERC20(address(testToken)), 0, 0, rewarders);
    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public {
    assertEq(beamErc4626.name(), "test");
    assertEq(beamErc4626.symbol(), "tst");
    assertEq(address(beamErc4626.asset()), address(testToken));
    assertEq(address(beamErc4626.BEAM_VAULT()), address(mockBeamChef));
    assertEq(address(marketKey), address(beamErc4626));
    assertEq(testToken.allowance(address(beamErc4626), address(mockBeamChef)), type(uint256).max);
    assertEq(glintToken.allowance(address(beamErc4626), address(flywheelRewards)), type(uint256).max);
  }

  function _deposit() internal {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(beamErc4626), depositAmount);
    flywheel.accrue(ERC20(beamErc4626), address(this));
    beamErc4626.deposit(depositAmount, address(this));
    flywheel.accrue(ERC20(beamErc4626), address(this));
  }

  function testDeposit() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    _deposit();

    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockBeamChef)), depositAmount);

    // //Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    _deposit();
    beamErc4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockBeamChef)), 0);

    // //Test that we burned the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), 0);
  }
}
