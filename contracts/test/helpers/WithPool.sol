// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { ComptrollerErrorReporter } from "../../compound/ErrorReporter.sol";
import { CErc20 } from "../../compound/CErc20.sol";
import { CToken } from "../../compound/CToken.sol";
import { WhitePaperInterestRateModel } from "../../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../../compound/Unitroller.sol";
import { Comptroller } from "../../compound/Comptroller.sol";
import { CErc20Delegate } from "../../compound/CErc20Delegate.sol";
import { CErc20Delegator } from "../../compound/CErc20Delegator.sol";
import { RewardsDistributorDelegate } from "../../compound/RewardsDistributorDelegate.sol";
import { RewardsDistributorDelegator } from "../../compound/RewardsDistributorDelegator.sol";
import { ComptrollerInterface } from "../../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../../FusePoolDirectory.sol";
import { MockPriceOracle } from "../../oracles/1337/MockPriceOracle.sol";

contract WithPool is Test {
  MockERC20 underlyingToken;
  CErc20 cErc20;
  CToken cToken;
  CErc20Delegate cErc20Delegate;

  Comptroller comptroller;
  WhitePaperInterestRateModel interestModel;

  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  address[] newImplementation;

  constructor() {
    setUpBaseContracts();
    setUpPoolAndMarket();
  }

  function setUpBaseContracts() public {
    underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1e16);
    fusePoolDirectory = new FusePoolDirectory();
    fusePoolDirectory.initialize(false, emptyAddresses);
    cErc20Delegate = new CErc20Delegate();
  }

  function setUpPoolAndMarket() public {
    MockPriceOracle priceOracle = new MockPriceOracle(10);
    emptyAddresses.push(address(0));
    Comptroller tempComptroller = new Comptroller(payable(fuseAdmin));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    (uint256 index, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      abi.encode(payable(address(fuseAdmin))),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(comptrollerAddress);

    newImplementation.push(address(cErc20Delegate));
    fuseAdmin._editCErc20DelegateWhitelist(emptyAddresses, newImplementation, falseBoolArray, trueBoolArray);
    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        ComptrollerInterface(comptrollerAddress),
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "CUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    cErc20 = CErc20(address(allMarkets[allMarkets.length - 1]));
    cToken = CToken(address(cErc20));
    markets = [address(cErc20)];
  }
}
