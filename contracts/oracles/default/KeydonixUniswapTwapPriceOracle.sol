// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import "../BasePriceOracle.sol";
import "../keydonix/UniswapOracle.sol";
import "../../external/uniswap/IUniswapV2Factory.sol";

/**
 * @title KeydonixUniswapTwapPriceOracle
 * @notice Stores cumulative prices and returns TWAPs for assets on Uniswap V2 pairs.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author vminkov
 */
contract KeydonixUniswapTwapPriceOracle is Initializable, IPriceOracle, BasePriceOracle, UniswapOracle {
    event PriceAlreadyVerified(address indexed token, uint256 price, uint256 block);
    event PriceVerified(address indexed token, uint256 price, uint256 block);

    /**
     * @dev wtoken token contract address.
     */
    address public wtoken;

    /**
     * @dev UniswapV2Factory contract address.
     */
    address public uniswapV2Factory;

    /**
     * @dev The token on which to base TWAPs (its price must be available via `msg.sender`).
     */
    address public denominationToken;

    /**
    * @dev the minimum blocks back for the price proof to be accepted;
    * used to take the mean of the current price and the past price
    */
    uint8 public minBlocksBack;

    /**
    * @dev the minimum blocks back for the price proof to be accepted;
    * used to take the mean of the current price and the past price
    */
    uint8 public maxBlocksBack;

    mapping(address => PriceVerification) public priceVerifications;

    struct PriceVerification {
        uint256 blockNumber;
        uint256 price;
    }

    /**
     * @dev Constructor that sets the UniswapV2Factory, denomination token and min/max blocks back.
     */
    function initialize(
        address _uniswapV2Factory,
        address _denominationToken,
        address _wtoken,
        uint8 _minBlocksBack,
        uint8 _maxBlocksBack
    ) external initializer {
        require(_uniswapV2Factory != address(0), "UniswapV2Factory not defined.");
        uniswapV2Factory = _uniswapV2Factory;
        wtoken = _wtoken;
        denominationToken = _denominationToken == address(0) ? address(wtoken) : _denominationToken;
        minBlocksBack = _minBlocksBack;
        maxBlocksBack = _maxBlocksBack;
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(ICToken cToken) external override view returns (uint) {
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying ERC20 token address
        address underlying = ICErc20(address(cToken)).underlying();

        // Get price, format, and return
        uint256 baseUnit = 10 ** uint256(ERC20Upgradeable(underlying).decimals());
        return (_price(underlying) * 1e18) / baseUnit;
    }

    function verifyPrice(ICToken cToken, ProofData memory proofData) public {
        address underlying = ICErc20(address(cToken)).underlying();
        PriceVerification storage latestPriceVerification = priceVerifications[underlying];
        if (latestPriceVerification.blockNumber == block.number) {
            emit PriceAlreadyVerified(underlying, latestPriceVerification.price, latestPriceVerification.blockNumber);
            return;
        }

        address pair = IUniswapV2Factory(uniswapV2Factory).getPair(underlying, denominationToken);
        (uint256 keydonixPrice, uint256 blockNumber) = getPrice(IUniswapV2Pair(pair), denominationToken, minBlocksBack, maxBlocksBack, proofData);
//        (uint256 keydonixPrice, uint256 blockNumber) = (123, block.number);

        if (blockNumber < latestPriceVerification.blockNumber) {
            emit PriceAlreadyVerified(underlying, latestPriceVerification.price, latestPriceVerification.blockNumber);
            return;
        }

        priceVerifications[underlying] = PriceVerification(
            blockNumber,
            keydonixPrice
        );

        emit PriceVerified(underlying, keydonixPrice, blockNumber);
    }

    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */
    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for wtoken
        if (underlying == wtoken) return 1e18;

        PriceVerification memory priceVerification = priceVerifications[underlying];
        if (priceVerification.blockNumber != 0 &&
            priceVerification.blockNumber >= block.number - maxBlocksBack
            && priceVerification.blockNumber <= block.number - minBlocksBack) {
            return priceVerification.price;
        } else {
            require(false, 'No valid proof provided for the range [minBlocksBack; maxBlocksBack]');
        }
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
