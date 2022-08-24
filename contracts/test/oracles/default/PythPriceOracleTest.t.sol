// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/PythPriceOracle.sol";
import "../../config/BaseTest.t.sol";

contract PythOraclesTest is BaseTest {
  PythPriceOracle oracle;

  function setUp() public {
    oracle = PythPriceOracle(ap.getAddress("PythPriceOracle"));
  }

  function testPriceFeed(address testedTokenAddress, bytes32 feedId) internal returns (uint256 price) {}

  function testJBRLPrice() public shouldRun(forChains(NEON_DEVNET)) {
    address wETH = 0x65976a250187cb1D21b7e3693aCF102d61c86177;
    string memory wETH_PRICE_FEED = "EdVCmQ9FSPcVe5YySXDPCRmc8aDQLKJ9xvYBMZPie1Vw";

    assert(testPriceFeed(wETH, bytes32(bytes(wETH_PRICE_FEED))) > 0);
  }
}
