// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "forge-std/Test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";

import {ComptrollerErrorReporter} from "../../compound/ErrorReporter.sol";
import {CErc20} from "../../compound/CErc20.sol";
import {CToken} from "../../compound/CToken.sol";
import {WhitePaperInterestRateModel} from "../../compound/WhitePaperInterestRateModel.sol";
import {Unitroller} from "../../compound/Unitroller.sol";
import {Comptroller} from "../../compound/Comptroller.sol";
import {CErc20PluginDelegate} from "../../compound/CErc20PluginDelegate.sol";
import {CErc20PluginRewardsDelegate} from "../../compound/CErc20PluginRewardsDelegate.sol";
import {CErc20Delegate} from "../../compound/CErc20Delegate.sol";
import {CErc20Delegator} from "../../compound/CErc20Delegator.sol";
import {RewardsDistributorDelegate} from "../../compound/RewardsDistributorDelegate.sol";
import {RewardsDistributorDelegator} from "../../compound/RewardsDistributorDelegator.sol";
import {ComptrollerInterface} from "../../compound/ComptrollerInterface.sol";
import {InterestRateModel} from "../../compound/InterestRateModel.sol";
import {FuseFeeDistributor} from "../../FuseFeeDistributor.sol";
import {FusePoolDirectory} from "../../FusePoolDirectory.sol";
import {MockPriceOracle} from "../../oracles/1337/MockPriceOracle.sol";
import {MasterPriceOracle} from "../../oracles/MasterPriceOracle.sol";
import {MockERC4626} from "../../compound/strategies/MockERC4626.sol";
import {FuseSafeLiquidator} from "../../FuseSafeLiquidator.sol";
import {MockERC4626Dynamic} from "../../compound/strategies/MockERC4626Dynamic.sol";
import {ERC4626} from "../../utils/ERC4626.sol";

contract WithPool {
    MockERC20 underlyingToken;
    CErc20 cErc20;
    CToken cToken;
    CErc20Delegate cErc20Delegate;

    CErc20PluginDelegate cErc20PluginDelegate;
    CErc20PluginRewardsDelegate cErc20PluginRewardsDelegate;

    Comptroller comptroller;
    Comptroller comptroller1;
    WhitePaperInterestRateModel interestModel;

    FuseFeeDistributor fuseAdmin;
    FusePoolDirectory fusePoolDirectory;
    FuseSafeLiquidator liquidator;
    MasterPriceOracle priceOracle;

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

    constructor(
        MasterPriceOracle _masterPriceOracle,
        MockERC20 _underlyingToken
    ) {
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

        fuseAdmin._editCErc20DelegateWhitelist(
            oldCErC20Implementations,
            newCErc20Implementations,
            f,
            t
        );
    }

    function setUpBaseContracts() public {
        // underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
        interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);
        fuseAdmin = new FuseFeeDistributor();
        fuseAdmin.initialize(1e16);
        fusePoolDirectory = new FusePoolDirectory();
        fusePoolDirectory.initialize(false, emptyAddresses);
        // priceOracle = new MockPriceOracle(10);
    }

    function setUpPool(
        string memory name,
        bool enforceWhitelist,
        uint256 closeFactor,
        uint256 liquidationIncentive
    ) public {
        emptyAddresses.push(address(0));
        Comptroller tempComtroller = new Comptroller(payable(fuseAdmin));
        newUnitroller.push(address(tempComtroller));
        trueBoolArray.push(true);
        falseBoolArray.push(false);
        fuseAdmin._editComptrollerImplementationWhitelist(
            emptyAddresses,
            newUnitroller,
            trueBoolArray
        );

        (uint256 index, address comptrollerAddress) = fusePoolDirectory
            .deployPool(
                name,
                address(tempComtroller),
                abi.encode(payable(address(fuseAdmin))),
                enforceWhitelist,
                closeFactor,
                liquidationIncentive,
                address(priceOracle)
            );
        Unitroller(payable(comptrollerAddress))._acceptAdmin();
        comptroller = Comptroller(comptrollerAddress);
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

    function deployCErc20PluginDelegate(
        ERC4626 _erc4626,
        uint256 _collateralFactorMantissa
    ) public {
        comptroller._deployMarket(
            false,
            abi.encode(
                address(underlyingToken),
                ComptrollerInterface(address(comptroller)),
                payable(address(fuseAdmin)),
                InterestRateModel(address(interestModel)),
                "cUnderlyingToken",
                "CUT",
                address(cErc20Delegate),
                abi.encode(address(_erc4626)),
                uint256(1),
                uint256(0)
            ),
            _collateralFactorMantissa
        );
    }

    function deployCErc20PluginRewardsDelegate(
        ERC4626 _mockERC4626Dynamic,
        FuseFlywheelCore _flywheel,
        uint256 _collateralFactorMantissa
    ) public {
        comptroller._deployMarket(
            false,
            abi.encode(
                address(underlyingToken),
                ComptrollerInterface(address(comptroller)),
                payable(address(fuseAdmin)),
                InterestRateModel(address(interestModel)),
                "cUnderlyingToken",
                "CUT",
                address(cErc20Delegate),
                abi.encode(
                    address(_mockERC4626Dynamic),
                    address(_flywheel),
                    address(underlyingToken)
                ),
                uint256(1),
                uint256(0)
            ),
            _collateralFactorMantissa
        );
    }
}
