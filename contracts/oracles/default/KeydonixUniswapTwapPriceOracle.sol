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
import "./IKeydonixUniswapTwapPriceOracle.sol";

/**
 * @title KeydonixUniswapTwapPriceOracle
 * @notice Stores cumulative prices and returns TWAPs for assets on Uniswap V2 pairs.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author vminkov
 */
contract KeydonixUniswapTwapPriceOracle is
  Initializable,
  IPriceOracle,
  BasePriceOracle,
  UniswapOracle,
  IKeydonixUniswapTwapPriceOracle
{
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
  mapping(address => PartialProof) public partialProofs;


  struct PartialProof {
    bool constructed;
    UniswapOracle.ProofData proof;
  }

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
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Return 1e18 for ETH
    if (cToken.isCEther()) return 1e18;

    // Get underlying ERC20 token address
    address underlying = ICErc20(address(cToken)).underlying();

    // Get price, format, and return
    uint256 baseUnit = 10**uint256(ERC20Upgradeable(underlying).decimals());
    return (price(underlying) * 1e18) / baseUnit;
  }

  function verifyPrice(ICToken cToken, UniswapOracle.ProofData calldata proofData) public returns (uint256, uint256) {
    if (cToken.isCEther()) {
      return (1e18, block.number);
    }

    ICErc20 asErc20 = ICErc20(address(cToken));
    address underlying = asErc20.underlying();

    return verifyPriceUnderlying(underlying, proofData);
  }

  function verifyPriceUnderlying(address underlying, UniswapOracle.ProofData calldata proofData)
    public
    returns (uint256, uint256)
  {
    // Return 1e18 for wtoken
    if (underlying == wtoken) return (1e18, block.number);

    PriceVerification storage latestPriceVerification = priceVerifications[underlying];
    if (latestPriceVerification.blockNumber == block.number) {
      emit PriceAlreadyVerified(
        underlying,
        latestPriceVerification.price,
        latestPriceVerification.blockNumber
      );
      return (latestPriceVerification.price, latestPriceVerification.blockNumber);
    }

    // TODO fix race conditions across different blocks
    PartialProof storage partialProof = _getOrUpdatePartialProof(underlying, proofData);
    if (!partialProof.constructed) {
//      require(
//        latestPriceVerification.blockNumber != 0 &&
//        latestPriceVerification.blockNumber >= block.number - maxBlocksBack &&
//        latestPriceVerification.blockNumber <= block.number - minBlocksBack
//      , "no valid and fully constructed proof available");
      return (0, 0);
    } else {
//      partialProof.constructed = false;
//      partialProof.proof.block = "";
//      partialProof.proof.reserveAndTimestampProofNodesRlp = "";
//      partialProof.proof.priceAccumulatorProofNodesRlp = "";
//      partialProof.proof.accountProofNodesRlp = "";

      address pair = IUniswapV2Factory(uniswapV2Factory).getPair(underlying, denominationToken);
      (uint256 verifiedPrice, uint256 blockNumber) = getPrice(
        IUniswapV2Pair(pair),
        denominationToken,
        minBlocksBack,
        maxBlocksBack,
        partialProof.proof
      );

      if (blockNumber <= latestPriceVerification.blockNumber) {
        emit PriceAlreadyVerified(
          underlying,
          latestPriceVerification.price,
          latestPriceVerification.blockNumber
        );
        return (latestPriceVerification.price, latestPriceVerification.blockNumber);
      }

      priceVerifications[underlying] = PriceVerification(blockNumber, verifiedPrice);

      emit PriceVerified(
        underlying,
        verifiedPrice,
        blockNumber
      );

      return (verifiedPrice, blockNumber);
    }
  }

  function _getOrUpdatePartialProof(address underlying, UniswapOracle.ProofData calldata proofData)
    internal returns (PartialProof storage) {
    PartialProof storage partialProof = partialProofs[underlying];
    if (partialProof.constructed) {
      // the old proof should be replaced
      partialProof.proof = proofData;
    } else {
      if (proofData.block.length != 0) {
        partialProof.proof.block = proofData.block;
      }
      if (proofData.accountProofNodesRlp.length != 0) {
        partialProof.proof.accountProofNodesRlp = proofData.accountProofNodesRlp;
      }
      if (proofData.priceAccumulatorProofNodesRlp.length != 0) {
        partialProof.proof.priceAccumulatorProofNodesRlp = proofData.priceAccumulatorProofNodesRlp;
      }
      if (proofData.reserveAndTimestampProofNodesRlp.length != 0) {
        partialProof.proof.reserveAndTimestampProofNodesRlp = proofData.reserveAndTimestampProofNodesRlp;
      }
    }

    partialProof.constructed =
      partialProof.proof.block.length != 0 &&
      partialProof.proof.accountProofNodesRlp.length != 0 &&
      partialProof.proof.priceAccumulatorProofNodesRlp.length != 0 &&
      partialProof.proof.reserveAndTimestampProofNodesRlp.length != 0;

    return partialProof;
  }

  /**
   * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
   */
  function price(address underlying) public view override returns (uint256) {
    // Return 1e18 for wtoken
    if (underlying == wtoken) return 1e18;

    PriceVerification memory priceVerification = priceVerifications[underlying];
    if (
      priceVerification.blockNumber != 0 &&
      priceVerification.blockNumber >= block.number - maxBlocksBack &&
      priceVerification.blockNumber <= block.number - minBlocksBack
    ) {
      return priceVerification.price;
    } else {
      require(false, "No valid proof provided for the range [minBlocksBack; maxBlocksBack]");
    }
  }
}
