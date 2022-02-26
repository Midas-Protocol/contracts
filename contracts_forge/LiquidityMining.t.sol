// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {CErc20} from "../contracts/compound/CErc20.sol";
import {MockERC20} from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";
import {WhitePaperInterestRateModel} from "../contracts/compound/WhitePaperInterestRateModel.sol";
import {Unitroller} from "../contracts/compound/Unitroller.sol";
import {Comptroller} from "../contracts/compound/Comptroller.sol";
import {CErc20Delegate} from "../contracts/compound/CErc20Delegate.sol";
import {CErc20Delegator} from "../contracts/compound/CErc20Delegator.sol";
import {RewardsDistributorDelegate} from "../contracts/compound/RewardsDistributorDelegate.sol";
import {RewardsDistributorDelegator} from "../contracts/compound/RewardsDistributorDelegator.sol";
import {ComptrollerInterface} from "../contracts/compound/ComptrollerInterface.sol";
import {InterestRateModel} from "../contracts/compound/InterestRateModel.sol";

contract LiquidityMiningTest is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  MockERC20 underlyingToken;
  MockERC20 rewardsToken;

  WhitePaperInterestRateModel interestModel;
  Comptroller comptroller;
  CErc20Delegate cErc20Delegate;
  CErc20 cErc20;
  RewardsDistributorDelegate rewardsDistributorDelegate;
  RewardsDistributorDelegate rewardsDistributor;

  uint256 depositAmount = 100e18;
  uint256 supplyRewardPerBlock = 10e18;
  uint256 borrowRewardPerBlocK = 1e18;

  address[] markets;

  function setUp() public {
    underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    rewardsToken = new MockERC20("RewardsToken", "RT", 18);
    interestModel = new WhitePaperInterestRateModel(100e18, 100e18);
    Unitroller tempUnitroller = new Unitroller();
    Comptroller tempComptroller = new Comptroller();
    cErc20Delegate = new CErc20Delegate();
    rewardsDistributorDelegate = new RewardsDistributorDelegate();
    rewardsDistributor = RewardsDistributorDelegate(
      address(
        new RewardsDistributorDelegator(address(this), address(rewardsToken), address(rewardsDistributorDelegate))
      )
    );

    tempUnitroller._setPendingImplementation(address(tempComptroller));
    /*tempUnitroller._acceptImplementation();

    comptroller = Comptroller(address(tempUnitroller));

    markets.push(address(cErc20));

    comptroller._deployMarket(
      false,
      abi.encodePacked(
        address(underlyingToken),
        ComptrollerInterface(address(comptroller)),
        InterestRateModel(address(interestModel)),
        "CUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      90e18
    );

    cErc20 = CErc20(address(comptroller.cTokensByUnderlying(address(underlyingToken))));

    rewardsDistributor._setCompSupplySpeed(cErc20, supplyRewardPerBlock);
    rewardsDistributor._setCompBorrowSpeed(cErc20, borrowRewardPerBlocK);

    rewardsToken.mint(address(this), depositAmount);
    rewardsToken.mint(address(this), depositAmount);*/
  }

  function deposit() public {
    underlyingToken.mint(address(this), depositAmount);
    underlyingToken.approve(address(cErc20), depositAmount);
    cErc20.mint(depositAmount);
  }

  function supplyReward() public {
    deposit();
    vm.roll(1);
    rewardsDistributor.claimRewards(address(this));
    assertEq(rewardsToken.balanceOf(address(this)), supplyRewardPerBlock);
  }

  function testInit() public {
    vm.roll(1);
  }
}
