// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/external/QueryAccount.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "pyth-sdk-solidity/PythStructs.sol";

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/consumers/best-practices for how to consume prices safely.
/// @author Pyth Data Association
contract Pyth {
    using BytesLib for bytes;

    /// @notice Returns the current price and confidence interval.
    /// @dev Reverts if the current price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the current price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getCurrentPrice(bytes32 id) external returns (PythStructs.Price memory price) {
        PythStructs.PriceFeed memory priceFeed = queryPriceFeed(id);

        require(priceFeed.status == PythStructs.PriceStatus.TRADING, "current price unavailable");

        price.price = priceFeed.price;
        price.conf = priceFeed.conf;
        price.expo = priceFeed.expo;
        return price;
    }

    /// @notice Returns the exponential moving average price and confidence interval.
    /// @dev Reverts if the current exponential moving average price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the current price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(bytes32 id) external returns (PythStructs.Price memory price) {
        PythStructs.PriceFeed memory priceFeed = queryPriceFeed(id);

        price.price = priceFeed.emaPrice;
        price.conf = priceFeed.emaConf;
        price.expo = priceFeed.expo;
        return price;
    }

    /// @notice Returns the most recent previous price with a status of Trading, with the time when this was published.
    /// @dev This may be a price from arbitrarily far in the past: it is important that you check the publish time before using the price.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    /// @return publishTime - the UNIX timestamp of when this price was computed.
    function getPrevPriceUnsafe(bytes32 id) external returns (PythStructs.Price memory price, uint64 publishTime) {
        PythStructs.PriceFeed memory priceFeed = queryPriceFeed(id);

        price.price = priceFeed.prevPrice;
        price.conf = priceFeed.prevConf;
        price.expo = priceFeed.expo;
        return (price, priceFeed.prevPublishTime);
    }

    function queryPriceFeed(bytes32 id) public returns (PythStructs.PriceFeed memory) {
        uint64 priceAccountDataLen = 244;
        uint256 addr = uint256(id);

        require(QueryAccount.cache(addr, 0, priceAccountDataLen), "failed to update cache");

        (bool success, bytes memory accData) = QueryAccount.data(addr, 0, priceAccountDataLen);
        require(success, "failed to query account data");

        return parseSolanaPriceAccountData(id, accData);
    }

    function parseSolanaPriceAccountData(bytes32 id, bytes memory data) public pure returns (PythStructs.PriceFeed memory priceFeed) {
        priceFeed.id = id;

        uint256 offset = 0;

        // Skip: magic (4) + ver (4) + atype (4) + size (4) + ptype (4)
        offset += 20;

        priceFeed.expo = readLittleEndianSigned32(data.toUint32(offset));
        offset += 4;

        priceFeed.maxNumPublishers = readLittleEndianUnsigned32(data.toUint32(offset));
        offset += 4;

        priceFeed.numPublishers = readLittleEndianUnsigned32(data.toUint32(offset));
        offset += 4;

        // Skip: last_slot (8) + valid_slot (8)
        offset += 16;

        priceFeed.emaPrice = readLittleEndianSigned64(data.toUint64(offset));
        offset += 8;

        // Skip: twap.numer_ (8) + twap.denom_ (8)
        offset += 16;

        priceFeed.emaConf = readLittleEndianUnsigned64(data.toUint64(offset));
        offset += 8;

        // Skip: twac.numer_ (8) + twac.denom_ (8)
        offset += 16;

        priceFeed.publishTime = readLittleEndianUnsigned64(data.toUint64(offset));
        offset += 8;

        // Skip: min_pub (1) + drv2_ (1) + drv3_ (2) + drv4_ (4)
        offset += 8;

        priceFeed.productId = bytes32(data.slice(offset, 32));
        offset += 32;

        // Skip: next_ (32) + prev_slot_ (8)
        offset += 40;

        priceFeed.prevPrice = readLittleEndianSigned64(data.toUint64(offset));
        offset += 8;

        priceFeed.prevConf = readLittleEndianUnsigned64(data.toUint64(offset));
        offset += 8;

        priceFeed.prevPublishTime = readLittleEndianUnsigned64(data.toUint64(offset));
        offset += 8;

        priceFeed.price = readLittleEndianSigned64(data.toUint64(offset));
        offset += 8;

        priceFeed.conf = readLittleEndianUnsigned64(data.toUint64(offset));
        offset += 8;

        priceFeed.status = PythStructs.PriceStatus(readLittleEndianUnsigned32(data.toUint32(offset)));
    }

    // Little Endian helpers

    function readLittleEndianSigned64(uint64 input) internal pure returns (int64) {
        uint64 val = input;
        val = ((val << 8) & 0xFF00FF00FF00FF00) | ((val >> 8) & 0x00FF00FF00FF00FF);
        val = ((val << 16) & 0xFFFF0000FFFF0000) | ((val >> 16) & 0x0000FFFF0000FFFF);
        return int64((val << 32) | ((val >> 32) & 0xFFFFFFFF));
    }

    function readLittleEndianUnsigned64(uint64 input) internal pure returns (uint64 val) {
        val = input;
        val = ((val << 8) & 0xFF00FF00FF00FF00) | ((val >> 8) & 0x00FF00FF00FF00FF);
        val = ((val << 16) & 0xFFFF0000FFFF0000) | ((val >> 16) & 0x0000FFFF0000FFFF);
        val = (val << 32) | (val >> 32);
    }

    function readLittleEndianSigned32(uint32 input) internal pure returns (int32) {
        uint32 val = input;
        val = ((val & 0xFF00FF00) >> 8) |
        ((val & 0x00FF00FF) << 8);
        return int32((val << 16) | ((val >> 16) & 0xFFFF));
    }

    function readLittleEndianUnsigned32(uint32 input) internal pure returns (uint32 val) {
        val = input;
        val = ((val & 0xFF00FF00) >> 8) |
        ((val & 0x00FF00FF) << 8);
        val = (val << 16) | (val >> 16);
    }
}
