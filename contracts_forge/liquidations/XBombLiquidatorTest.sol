// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../contracts/external/bomb/IXBomb.sol";
import "../../contracts/liquidators/XBombLiquidator.sol";
import "../../contracts/oracles/default/UniswapTwapPriceOracleV2.sol";

contract XBombLiquidatorTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  // the Pancake BOMB/xBOMB pair
  address holder = 0x6aE0Fb5D98911cF5AF6A8CE0AeCE426227d41103;
  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  address bombTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3; // BOMB

  function setUp() public {
    // impersonate the holder
    vm.startPrank(holder);
  }

  function testOraclePrice() public {
    // pancake WBTC/BOMB pair
    address pairAddress = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6;
    // uniswap v2 twap oracle root address
    address twapOracleRootAddress = 0x7263C40E0CD50a5a10549F5B7BF010D89F94c3c7;
    // uniswap v2 factory address
    address factoryAddress = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address wbtc = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    UniswapTwapPriceOracleV2Root twapOracleRoot = UniswapTwapPriceOracleV2Root(twapOracleRootAddress);
    // trigger a twap price update
    address[] memory pairs = new address[](1);
    pairs[0] = pairAddress;
    twapOracleRoot.update(pairs);

    assertTrue(twapOracleRoot.price(bombTokenAddress, wbtc, factoryAddress) > 0);
  }

  function testRedeem() public {
    XBombLiquidator liquidator = new XBombLiquidator();

    // make sure we're testing with at least some tokens
    uint256 balance = xbombToken.balanceOf(holder);
    assertTrue(balance > 0);

    // fund the liquidator so it can redeem the tokens
    xbombToken.transfer(address(liquidator), balance);
    // redeem the underlying reward token
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(xbombToken)),
      balance,
      ""
    );

    assertEq(address(outputToken), bombTokenAddress);
    assertEq(outputAmount, xbombToken.toREWARD(balance));
  }
}
