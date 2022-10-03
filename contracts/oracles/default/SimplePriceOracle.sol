// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../compound/PriceOracle.sol";
import "../../compound/CErc20.sol";

contract SimplePriceOracle is PriceOracle {
  mapping(address => uint256) prices;
  event PricePosted(
    address asset,
    uint256 previousPriceMantissa,
    uint256 requestedPriceMantissa,
    uint256 newPriceMantissa
  );

  function getUnderlyingPrice(CTokenInterface cToken) public view override returns (uint256) {
    if (compareStrings(cToken.symbol(), "cETH")) {
      return 1e18;
    } else {
      return prices[address(CErc20(address(cToken)).underlying())];
    }
  }

  function setUnderlyingPrice(CToken cToken, uint256 underlyingPriceMantissa) public {
    address asset = address(CErc20(address(cToken)).underlying());
    emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
    prices[asset] = underlyingPriceMantissa;
  }

  function setDirectPrice(address asset, uint256 price) public {
    emit PricePosted(asset, prices[asset], price, price);
    prices[asset] = price;
  }

  function price(address underlying) external view returns (uint256) {
    return prices[address(underlying)];
  }

  // v1 price oracle interface for use as backing of proxy
  function assetPrices(address asset) external view returns (uint256) {
    return prices[asset];
  }

  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }
}
