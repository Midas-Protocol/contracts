// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../external/compound/IPriceOracle.sol";
import "../external/compound/ICToken.sol";
import "../external/compound/ICErc20.sol";
import "../external/compound/IComptroller.sol";

import "../external/chainlink/AggregatorV3Interface.sol";

/**
 * @title RecursivePriceOracle
 * @notice Returns prices from other cTokens (from Compound or from Fuse).
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract RecursivePriceOracle is IPriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Compound Comptroller address.
     */
    address public constant COMPOUND_COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    /**
     * @dev Cream Comptroller address.
     */
    address public constant CREAM_COMPTROLLER = 0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258;

    /**
     * @dev Chainlink ETH/USD price feed contract.
     */
    AggregatorV3Interface public constant ETH_USD_PRICE_FEED = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(ICToken cToken) external override view returns (uint) {
        // Get cToken's underlying cToken
        ICToken underlying = ICToken(ICErc20(address(cToken)).underlying());

        // Get Comptroller
        IComptroller comptroller = IComptroller(underlying.comptroller());

        // Check for Compound Comptroller
        if (address(comptroller) == COMPOUND_COMPTROLLER) {
            // If cETH, return cETH/ETH exchange rate
            if (compareStrings(underlying.symbol(), "cETH")) return underlying.exchangeRateStored();

            // Compound cErc20: cToken/token price * token/USD price / ETH/USD price = cToken/ETH price
            (, int256 usdPerEth, , , ) = ETH_USD_PRICE_FEED.latestRoundData();
            if (usdPerEth <= 0) return 0;
            return underlying.exchangeRateStored().mul(comptroller.oracle().getUnderlyingPrice(underlying)).div(uint256(usdPerEth).mul(1e10));
        }

        // If cETH, return cETH/ETH exchange rate
        if (address(comptroller) == CREAM_COMPTROLLER) {
            // Cream
            if (compareStrings(underlying.symbol(), "cETH")) return underlying.exchangeRateStored();
        } else if (underlying.isCEther()) {
            // Fuse
            return underlying.exchangeRateStored();
        }

        // Fuse cTokens: cToken/token price * token/ETH price = cToken/ETH price
        return underlying.exchangeRateStored().mul(comptroller.oracle().getUnderlyingPrice(underlying)).div(1e18);
    }

    /**
     * @dev Compares two strings.
     */
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
