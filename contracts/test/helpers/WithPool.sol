// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";

import { ComptrollerErrorReporter } from "../../compound/ErrorReporter.sol";
import { CErc20 } from "../../compound/CErc20.sol";
import { CToken } from "../../compound/CToken.sol";
import { WhitePaperInterestRateModel } from "../../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../../compound/Unitroller.sol";
import { Comptroller } from "../../compound/Comptroller.sol";
import { CErc20PluginDelegate } from "../../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { CErc20Delegate } from "../../compound/CErc20Delegate.sol";
import { CErc20Delegator } from "../../compound/CErc20Delegator.sol";
import { RewardsDistributorDelegate } from "../../compound/RewardsDistributorDelegate.sol";
import { RewardsDistributorDelegator } from "../../compound/RewardsDistributorDelegator.sol";
import { ComptrollerInterface } from "../../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../../FusePoolDirectory.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { MockERC4626 } from "../../midas/strategies/MockERC4626.sol";
import { FuseSafeLiquidator } from "../../FuseSafeLiquidator.sol";
import { MockERC4626Dynamic } from "../../midas/strategies/MockERC4626Dynamic.sol";
import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { FusePoolLens } from "../../FusePoolLens.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract WithPool {
  ERC20Upgradeable public underlyingToken;
  CErc20 cErc20;
  CToken cToken;
  CErc20Delegate cErc20Delegate;

  CErc20PluginDelegate cErc20PluginDelegate;
  CErc20PluginRewardsDelegate cErc20PluginRewardsDelegate;

  Comptroller comptroller;
  WhitePaperInterestRateModel interestModel;

  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;
  FuseSafeLiquidator liquidator;
  MasterPriceOracle priceOracle;
  FusePoolLens poolLens;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  bool[] t;
  bool[] f;
  address[] newImplementation;
  address[] oldCErC20Implementations;
  address[] newCErc20Implementations;
  address[] hardcodedAddresses;
  string[] hardcodedNames;

  event log_address1(address add);

  function setUpWithPool(MasterPriceOracle _masterPriceOracle, ERC20Upgradeable _underlyingToken) public {
    priceOracle = _masterPriceOracle;
    underlyingToken = _underlyingToken;
    setUpBaseContracts();
    setUpWhiteList();
    // setUpPoolAndMarket();
  }

  function setUpWhiteList() public {
    cErc20PluginDelegate = new CErc20PluginDelegate();
    cErc20PluginRewardsDelegate = new CErc20PluginRewardsDelegate();
    cErc20Delegate = new CErc20Delegate();

    for (uint256 i = 0; i < 7; i++) {
      t.push(true);
      f.push(false);
    }

    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(0));
    oldCErC20Implementations.push(address(cErc20Delegate));
    oldCErC20Implementations.push(address(cErc20Delegate));
    oldCErC20Implementations.push(address(cErc20PluginDelegate));
    oldCErC20Implementations.push(address(cErc20PluginRewardsDelegate));

    newCErc20Implementations.push(address(cErc20Delegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));
    newCErc20Implementations.push(address(cErc20PluginDelegate));
    newCErc20Implementations.push(address(cErc20PluginRewardsDelegate));

    fuseAdmin._editCErc20DelegateWhitelist(oldCErC20Implementations, newCErc20Implementations, f, t);
  }

  function setUpBaseContracts() public {
    interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1e16);
    fusePoolDirectory = new FusePoolDirectory();
    fusePoolDirectory.initialize(false, emptyAddresses);

    poolLens = new FusePoolLens();
    emit log_address1(address(poolLens));
    poolLens.initialize(
      fusePoolDirectory,
      "Pool",
      "lens",
      hardcodedAddresses,
      hardcodedNames,
      hardcodedNames,
      hardcodedNames,
      hardcodedNames,
      hardcodedNames
    );
  }

  function setUpPool(
    string memory name,
    bool enforceWhitelist,
    uint256 closeFactor,
    uint256 liquidationIncentive
  ) public {
    emptyAddresses.push(address(0));
    newUnitroller.push(address(new Comptroller(payable(fuseAdmin))));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);

    (, address comptrollerAddress) = fusePoolDirectory.deployPool(
      name,
      newUnitroller[0],
      abi.encode(payable(address(fuseAdmin))),
      enforceWhitelist,
      closeFactor,
      liquidationIncentive,
      address(priceOracle)
    );
    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(payable(comptrollerAddress));
  }

  function deployCErc20Delegate(
    address _underlyingToken,
    bytes memory name,
    bytes memory symbol,
    uint256 _collateralFactorMantissa
  ) public {
    comptroller._deployMarket(
      false,
      abi.encode(
        _underlyingToken,
        ComptrollerInterface(address(comptroller)),
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        name,
        symbol,
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      _collateralFactorMantissa
    );
  }

  function deployCErc20PluginDelegate(address _erc4626, uint256 _collateralFactorMantissa) public {
    whitelistPlugin(_erc4626, _erc4626);

    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        ComptrollerInterface(address(comptroller)),
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginDelegate),
        abi.encode(_erc4626),
        uint256(1),
        uint256(0)
      ),
      _collateralFactorMantissa
    );
  }

  function deployCErc20PluginRewardsDelegate(address _mockERC4626Dynamic, uint256 _collateralFactorMantissa) public {
    whitelistPlugin(_mockERC4626Dynamic, _mockERC4626Dynamic);

    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        ComptrollerInterface(address(comptroller)),
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "cUnderlyingToken",
        "CUT",
        address(cErc20PluginRewardsDelegate),
        abi.encode(_mockERC4626Dynamic),
        uint256(1),
        uint256(0)
      ),
      _collateralFactorMantissa
    );
  }

  function whitelistPlugin(address oldImpl, address newImpl) public {
    address[] memory oldCErC20Implementations = new address[](1);
    address[] memory newCErc20Implementations = new address[](1);
    bool[] memory arrayOfTrue = new bool[](1);

    oldCErC20Implementations[0] = address(oldImpl);
    newCErc20Implementations[0] = address(newImpl);
    arrayOfTrue[0] = true;

    fuseAdmin._editPluginImplementationWhitelist(oldCErC20Implementations, newCErc20Implementations, arrayOfTrue);
  }
}
