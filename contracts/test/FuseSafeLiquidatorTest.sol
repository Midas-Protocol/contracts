// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "../FuseSafeLiquidator.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./config/BaseTest.t.sol";

contract MockRedemptionStrategy is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    return (IERC20Upgradeable(address(0)), 1);
  }
}

contract FuseSafeLiquidatorTest is BaseTest {
  FuseSafeLiquidator fsl;
  address alice = address(10);

  function setUp() public {
    if (block.chainid == BSC_MAINNET) {
      // the proxy/storage is using slot 51 for the owner address
      fsl = FuseSafeLiquidator(payable(0xc9C3D317E89f4390A564D56180bBB1842CF3c99C));
    } else {
      fsl = new FuseSafeLiquidator();
      fsl.initialize(address(1), address(2), address(3), address(4), "");
    }
  }

  function testWhitelistRevert() public {
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(address(0));
    uint256 underlyingCollateralSeized = 1;
    IRedemptionStrategy strategy = new MockRedemptionStrategy();
    bytes memory strategyData = "";

    vm.expectRevert("only whitelisted redemption strategies can be used");
    fsl.redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, strategy, strategyData);
  }

  function testWhitelist() public {
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(address(0));
    uint256 underlyingCollateralSeized = 1;
    IRedemptionStrategy strategy = new MockRedemptionStrategy();
    bytes memory strategyData = "";

    fsl._whitelistRedemptionStrategy(strategy, true);
    fsl.redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, strategy, strategyData);
  }

  function testUpgrade() public {
    emit log_address(fsl.owner());

    // in case these slots start to get used, please redeploy the FSL
    // with a larger storage gap to protect the owner variable of OwnableUpgradeable
    // from being overwritten by the FuseSafeLiquidator storage
    for (uint i = 40; i < 51; i++) {
      emit log_uint(i);
      address atSloti = address(uint160(uint256(vm.load(address(fsl), bytes32(i)))));
      emit log_address(atSloti);
      assertEq(atSloti, address(0), "replace the FSL proxy/storage contract with a new one before the owner variable is overwritten");
    }
  }
}
