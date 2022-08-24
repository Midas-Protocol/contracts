// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/PythPriceOracle.sol";
import "../../config/BaseTest.t.sol";
import { Pyth } from "pyth-neon/PythOracle.sol";

contract PythOraclesTest is BaseTest {
  PythPriceOracle oracle;
  Pyth pythOracle;

  function setUp() public {
    pythOracle = new Pyth();
    oracle = new PythPriceOracle(
      address(this),
      true,
      address(0),
      address(pythOracle),
      bytes32(bytes("7f57ca775216655022daa88e41c380529211cde01a1517735dbcf30e4a02bdaa")),
      MasterPriceOracle(address(0)),
      address(0)
    );
    oracle = PythPriceOracle(ap.getAddress("PythPriceOracle"));
  }

  function testPriceFeed(address testedTokenAddress, bytes32 feedId) internal returns (uint256 price) {}

  function testwETHPrice() public shouldRun(forChains(NEON_DEVNET)) {
    address wETH = 0x65976a250187cb1D21b7e3693aCF102d61c86177;
    string memory wETH_PRICE_FEED = "EdVCmQ9FSPcVe5YySXDPCRmc8aDQLKJ9xvYBMZPie1Vw";

    assert(testPriceFeed(wETH, bytes32(bytes(wETH_PRICE_FEED))) > 0);
  }
}
