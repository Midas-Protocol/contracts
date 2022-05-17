// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MasterPriceOracle} from "../oracles/MasterPriceOracle.sol";

contract BombE2eTest is WithPool, BaseTest {
    constructor()
        WithPool(
            MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
            MockERC20(0x522348779DCb2911539e76A1042aA922F9C47Ee3)
        )
    {}

    function setUp() public shouldRun(forChains(BSC_MAINNET)) {
        setUpPool("bsc-test", false, 0.1e18, 1.1e18);
    }

    function testDeployCErc20Delegate()
        public
        shouldRun(forChains(BSC_MAINNET))
    {
        vm.roll(1);
        deployCErc20Delegate("cUnderlyingToken", "CUT", 0.9e18);

        CToken[] memory allMarkets = comptroller.getAllMarkets();
        emit log_uint(allMarkets.length);
        CErc20Delegate cToken = CErc20Delegate(
            address(allMarkets[allMarkets.length - 1])
        );
        emit log_address(address(cToken));
        emit log_string(cToken.name());
        assertEq(cToken.name(), "cUnderlyingToken");
    }
}
