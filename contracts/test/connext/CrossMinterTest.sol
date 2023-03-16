// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../helpers/WithPool.sol";
import { BaseTest } from "../config/BaseTest.t.sol";
import "forge-std/Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { IComptroller } from "../../external/compound/IComptroller.sol";
import { FusePoolLensSecondary } from "../../FusePoolLensSecondary.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { CTokenInterface } from "../../compound/CTokenInterfaces.sol";
import { CrossMinter } from "../../connext/CrossMinter.sol";

contract MockAsset is MockERC20 {
  constructor() MockERC20("test", "test", 8) {}

  function deposit() external payable {}
}

contract CrossMinterTest is WithPool {
  struct LiquidationData {
    address[] cTokens;
    CTokenInterface[] allMarkets;
    MockAsset bnb;
    MockAsset mimo;
    MockAsset usdc;
  }

  CrossMinter crossMinter;
  address connext = address(0x1234);

  function afterForkSetUp() internal override {
    super.setUpWithPool(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      ERC20Upgradeable(ap.getAddress("wtoken"))
    );

    deal(address(underlyingToken), address(this), 100e18);
    setUpPool("bsc-test", false, 0.1e18, 1.1e18);
  }

  function testCrossMintOnBsc() public fork(BSC_MAINNET) {
    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fusePoolDirectory);

    LiquidationData memory vars;
    vm.roll(1);
    vars.bnb = MockAsset(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    vars.usdc = MockAsset(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    deployCErc20Delegate(address(vars.bnb), "BNB", "bnb", 0.9e18);
    deployCErc20Delegate(address(vars.usdc), "USDC", "usdc", 0.9e18);

    // TODO no need to upgrade after the next deploy
    upgradePool(address(comptroller));

    // create cross minter contract
    crossMinter = new CrossMinter(connext, address(comptroller), address(0));

    vars.allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    CErc20Delegate cBnbToken = CErc20Delegate(address(vars.allMarkets[0]));

    CErc20Delegate cUSDC = CErc20Delegate(address(vars.allMarkets[1]));

    vars.cTokens = new address[](1);
    vars.cTokens[0] = address(cBnbToken);

    address accountOne = address(1);
    address accountTwo = address(2);

    FusePoolLensSecondary secondary = new FusePoolLensSecondary();
    secondary.initialize(fusePoolDirectory);

    bytes32 transferId = bytes32(bytes("test"));
    address originSender = address(0);
    uint32 origin = 1;
    bytes memory _calldata;
    uint256 amount;

    // Account One Supply
    {
      emit log("Test BNB with account one - via connext");
      vm.startPrank(connext);

      // Connext transfer WBNB to minter contract
      amount = 1 ether;
      deal(address(vars.bnb), connext, amount);
      vars.bnb.transfer(address(crossMinter), amount);

      uint256 beforeTotal = cBnbToken.totalSupply();
      // Call xReceive
      _calldata = abi.encode(address(cBnbToken), accountOne);
      crossMinter.xReceive(transferId, amount, address(vars.bnb), originSender, origin, _calldata);

      // Validate
      uint256 newMinted = cBnbToken.totalSupply() - beforeTotal;
      assertEq(ICToken(address(cBnbToken)).balanceOf(accountOne), newMinted, "cbnb token not minted");
      assertEq(vars.bnb.balanceOf(connext), 0, "wbnb token not transfered!");

      vm.stopPrank();
    }
  }
}
