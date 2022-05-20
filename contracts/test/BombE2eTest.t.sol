// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";
import "forge-std/Test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FuseFlywheelDynamicRewards} from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ICToken} from "../external/compound/ICToken.sol";
import {MasterPriceOracle} from "../oracles/MasterPriceOracle.sol";

interface MockXBomb {
    function getExchangeRate() external returns (uint256);
}

contract BombE2eTest is WithPool, BaseTest {
    using stdStorage for StdStorage;

    constructor()
        WithPool(
            MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
            MockERC20(0x522348779DCb2911539e76A1042aA922F9C47Ee3)
        )
    {}

    function setUp() public shouldRun(forChains(BSC_MAINNET)) {
        vm.prank(0xcd6cD62F11F9417FBD44dc0a44F891fd3E869234);
        underlyingToken.mint(address(this), 100e18);
        setUpPool("bsc-test", false, 0.1e18, 1.1e18);
    }

    function testDeployCErc20Delegate()
        public
        shouldRun(forChains(BSC_MAINNET))
    {
        vm.roll(1);
        deployCErc20Delegate("cUnderlyingToken", "CUT", 0.9e18);

        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CErc20Delegate cToken = CErc20Delegate(
            address(allMarkets[allMarkets.length - 1])
        );
        assertEq(cToken.name(), "cUnderlyingToken");
        underlyingToken.approve(address(cToken), 1e36);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);

        vm.roll(1);
        cToken.mint(10e18);
        assertEq(cToken.totalSupply(), 10e18 * 5);
        assertEq(underlyingToken.balanceOf(address(cToken)), 10e18);

        cToken.borrow(1000);
        assertEq(cToken.totalBorrows(), 1000);
        assertEq(
            underlyingToken.balanceOf(address(this)),
            100e18 - 10e18 + 1000
        );
    }

    function testCErc20Liquidation() public shouldRun(forChains(BSC_MAINNET)) {
        vm.roll(1);
        deployCErc20Delegate("cUnderlyingToken", "CUT", 0.9e18);
        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CErc20Delegate cToken = CErc20Delegate(
            address(allMarkets[allMarkets.length - 1])
        );
        underlyingToken.approve(address(cToken), 1e36);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);

        vm.roll(1);
        cToken.mint(10e18);
        cToken.borrow(1000);
        IPriceOracle oracle = priceOracle.oracles(
            0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c
        );
        emit log_address(address(oracle));
        uint256 price = priceOracle.price(address(underlyingToken));
        emit log_uint(price);
        UniswapTwapPriceOracleV2Root twapOracleRoot = UniswapTwapPriceOracleV2Root(
                0x315b23e85E1ad004A466f3C89544794Ef3392179
            );

        twapOracleRoot.update(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6);
        uint256 updatedPrice = priceOracle.price(address(underlyingToken));
        uint256 price0 = IUniswapV2Pair(
            0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6
        ).price0CumulativeLast();
        uint256 price1 = IUniswapV2Pair(
            0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6
        ).price1CumulativeLast();
        // uint256 slot = stdstore
        //     .target(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6)
        //     .sig("price0CumulativeLast()")
        //     .find();
        // emit log_uint(slot);
        // emit log_uint(price0);
        // emit log_uint(price1);

        // uint256 price = oracle.getUnderlyingPrice(ICToken(address(cToken)));
        // emit log_uint(updatedPrice);
    }

    function testDeployCErc20PluginDelegate()
        public
        shouldRun(forChains(BSC_MAINNET))
    {
        MockERC4626 erc4626 = MockERC4626(
            0x92C6C8278509A69f5d601Eea1E6273F304311bFe
        );

        vm.roll(1);
        deployCErc20PluginDelegate(erc4626, 0.9e18);

        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CErc20PluginDelegate cToken = CErc20PluginDelegate(
            address(allMarkets[allMarkets.length - 1])
        );

        cToken._setImplementationSafe(
            address(cErc20PluginDelegate),
            false,
            abi.encode(address(erc4626))
        );
        assertEq(address(cToken.plugin()), address(erc4626));

        underlyingToken.approve(address(cToken), 1e36);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);
        vm.roll(1);

        cToken.mint(10e18);
        assertEq(cToken.totalSupply(), 10e18 * 5);
        uint256 exchangeRate = MockXBomb(
            0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b
        ).getExchangeRate();
        uint256 balance = erc4626.balanceOf(address(cToken));
        uint256 convertedRate = (balance * exchangeRate) / 1e18;
        uint256 offset = 10;
        assertGt(convertedRate, 10e18 - offset);
        vm.roll(1);

        cToken.borrow(1000);
        assertEq(cToken.totalBorrows(), 1000);
        // assertEq(underlyingToken.balanceOf(address(erc4626)), 10e18 - 1000);
        balance = erc4626.balanceOf(address(cToken));
        convertedRate = (balance * exchangeRate) / 1e18;
        assertGt(convertedRate, 10e18 - 1000 - offset);
        assertEq(
            underlyingToken.balanceOf(address(this)),
            100e18 - 10e18 + 1000
        );
    }

    function testDeployCErc20PluginRewardsDelegate()
        public
        shouldRun(forChains(BSC_MAINNET))
    {
        MockERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
        FuseFlywheelDynamicRewards rewards;
        FuseFlywheelCore flywheel = new FuseFlywheelCore(
            underlyingToken,
            IFlywheelRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );
        rewards = new FuseFlywheelDynamicRewards(flywheel, 1);
        flywheel.setFlywheelRewards(rewards);

        MockERC4626Dynamic mockERC4626Dynamic = new MockERC4626Dynamic(
            ERC20(address(underlyingToken)),
            FlywheelCore(address(flywheel))
        );

        ERC20 marketKey = ERC20(address(mockERC4626Dynamic));
        flywheel.addStrategyForRewards(marketKey);

        vm.roll(1);
        deployCErc20PluginRewardsDelegate(mockERC4626Dynamic, flywheel, 0.9e18);

        CToken[] memory allMarkets = comptroller.getAllMarkets();
        CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(
            address(allMarkets[allMarkets.length - 1])
        );

        cToken._setImplementationSafe(
            address(cErc20PluginRewardsDelegate),
            false,
            abi.encode(
                address(mockERC4626Dynamic),
                address(flywheel),
                address(underlyingToken)
            )
        );
        assertEq(address(cToken.plugin()), address(mockERC4626Dynamic));
        assertEq(
            underlyingToken.allowance(
                address(cToken),
                address(mockERC4626Dynamic)
            ),
            type(uint256).max
        );
        assertEq(
            underlyingToken.allowance(address(cToken), address(flywheel)),
            0
        );

        cToken.approve(address(rewardToken), address(flywheel));
        assertEq(
            rewardToken.allowance(address(cToken), address(flywheel)),
            type(uint256).max
        );

        underlyingToken.approve(address(cToken), 1e36);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.enterMarkets(cTokens);
        vm.roll(1);

        cToken.mint(10000000);
        assertEq(cToken.totalSupply(), 10000000 * 5);
        assertEq(mockERC4626Dynamic.balanceOf(address(cToken)), 10000000);
        assertEq(
            underlyingToken.balanceOf(address(mockERC4626Dynamic)),
            10000000
        );
        vm.roll(1);

        cToken.borrow(1000);
        assertEq(cToken.totalBorrows(), 1000);
        assertEq(
            underlyingToken.balanceOf(address(mockERC4626Dynamic)),
            10000000 - 1000
        );
        assertEq(
            mockERC4626Dynamic.balanceOf(address(cToken)),
            10000000 - 1000
        );
        assertEq(
            underlyingToken.balanceOf(address(this)),
            100e18 - 10000000 + 1000
        );
    }
}
