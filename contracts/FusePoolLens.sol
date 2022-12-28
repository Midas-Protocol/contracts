// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "./external/compound/IComptroller.sol";
import "./external/compound/IPriceOracle.sol";
import "./oracles/BasePriceOracle.sol";
import "./external/compound/ICToken.sol";
import "./external/compound/ICErc20.sol";
import "./external/compound/IRewardsDistributor.sol";

import "./external/uniswap/IUniswapV2Pair.sol";

import "./FusePoolDirectory.sol";
import "./oracles/MasterPriceOracle.sol";
import "./oracles/default/IKeydonixUniswapTwapPriceOracle.sol";

/**
 * @title FusePoolLens
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolLens returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.
 */
contract FusePoolLens is Initializable {
  /**
   * @notice Initialize the `FusePoolDirectory` contract object.
   * @param _directory The FusePoolDirectory
   * @param _name Name for the nativeToken
   * @param _symbol Symbol for the nativeToken
   * @param _hardcodedAddresses Underlying token addresses for a token like maker which are DSToken and/or use bytes32 for `symbol`
   * @param _hardcodedNames Harcoded name for these tokens
   * @param _hardcodedSymbols Harcoded symbol for these tokens
   * @param _uniswapLPTokenNames Harcoded names for underlying uniswap LpToken
   * @param _uniswapLPTokenSymbols Harcoded symbols for underlying uniswap LpToken
   * @param _uniswapLPTokenDisplayNames Harcoded display names for underlying uniswap LpToken
   */
  function initialize(
    FusePoolDirectory _directory,
    string memory _name,
    string memory _symbol,
    address[] memory _hardcodedAddresses,
    string[] memory _hardcodedNames,
    string[] memory _hardcodedSymbols,
    string[] memory _uniswapLPTokenNames,
    string[] memory _uniswapLPTokenSymbols,
    string[] memory _uniswapLPTokenDisplayNames
  ) public initializer {
    require(address(_directory) != address(0), "FusePoolDirectory instance cannot be the zero address.");
    require(
      _hardcodedAddresses.length == _hardcodedNames.length && _hardcodedAddresses.length == _hardcodedSymbols.length,
      "Hardcoded addresses lengths not equal."
    );
    require(
      _uniswapLPTokenNames.length == _uniswapLPTokenSymbols.length &&
        _uniswapLPTokenNames.length == _uniswapLPTokenDisplayNames.length,
      "Uniswap LP token names lengths not equal."
    );

    directory = _directory;
    name = _name;
    symbol = _symbol;
    for (uint256 i = 0; i < _hardcodedAddresses.length; i++) {
      hardcoded[_hardcodedAddresses[i]] = TokenData({ name: _hardcodedNames[i], symbol: _hardcodedSymbols[i] });
    }

    for (uint256 i = 0; i < _uniswapLPTokenNames.length; i++) {
      uniswapData.push(
        UniswapData({
          name: _uniswapLPTokenNames[i],
          symbol: _uniswapLPTokenSymbols[i],
          displayName: _uniswapLPTokenDisplayNames[i]
        })
      );
    }
  }

  string public name;
  string public symbol;

  struct TokenData {
    string name;
    string symbol;
  }
  mapping(address => TokenData) hardcoded;

  struct UniswapData {
    string name; // ie "Uniswap V2" or "SushiSwap LP Token"
    string symbol; // ie "UNI-V2" or "SLP"
    string displayName; // ie "SushiSwap" or "Uniswap"
  }
  UniswapData[] uniswapData;

  /**
   * @notice `FusePoolDirectory` contract object.
   */
  FusePoolDirectory public directory;

  /**
   * @dev Struct for Fuse pool summary data.
   */
  struct FusePoolData {
    uint256 totalSupply;
    uint256 totalBorrow;
    address[] underlyingTokens;
    string[] underlyingSymbols;
    bool whitelistedAdmin;
  }

  /**
   * @notice Returns arrays of all public Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getPublicPoolsWithData()
    external
    returns (
      uint256[] memory,
      FusePoolDirectory.FusePool[] memory,
      FusePoolData[] memory,
      bool[] memory
    )
  {
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory publicPools) = directory.getPublicPools();
    (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(publicPools);
    return (indexes, publicPools, data, errored);
  }

  /**
   * @notice Returns arrays of all whitelisted public Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getPublicPoolsByVerificationWithData(bool whitelistedAdmin)
    external
    returns (
      uint256[] memory,
      FusePoolDirectory.FusePool[] memory,
      FusePoolData[] memory,
      bool[] memory
    )
  {
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory publicPools) = directory
      .getPublicPoolsByVerification(whitelistedAdmin);
    (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(publicPools);
    return (indexes, publicPools, data, errored);
  }

  /**
   * @notice Returns arrays of the indexes of Fuse pools created by `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getPoolsByAccountWithData(address account)
    external
    returns (
      uint256[] memory,
      FusePoolDirectory.FusePool[] memory,
      FusePoolData[] memory,
      bool[] memory
    )
  {
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = directory.getPoolsByAccount(account);
    (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(accountPools);
    return (indexes, accountPools, data, errored);
  }

  /**
   * @notice Returns arrays of the indexes of Fuse pools used by `user`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getPoolsOfUserWithData(address user)
    external
    returns (
      uint256[] memory,
      FusePoolDirectory.FusePool[] memory,
      FusePoolData[] memory,
      bool[] memory
    )
  {
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory userPools) = directory.getPoolsOfUser(user);
    (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(userPools);
    return (indexes, userPools, data, errored);
  }

  /**
   * @notice Internal function returning arrays of requested Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getPoolsData(FusePoolDirectory.FusePool[] memory pools)
    internal
    returns (FusePoolData[] memory, bool[] memory)
  {
    FusePoolData[] memory data = new FusePoolData[](pools.length);
    bool[] memory errored = new bool[](pools.length);

    for (uint256 i = 0; i < pools.length; i++) {
      try this.getPoolSummary(IComptroller(pools[i].comptroller)) returns (
        uint256 _totalSupply,
        uint256 _totalBorrow,
        address[] memory _underlyingTokens,
        string[] memory _underlyingSymbols,
        bool _whitelistedAdmin
      ) {
        data[i] = FusePoolData(_totalSupply, _totalBorrow, _underlyingTokens, _underlyingSymbols, _whitelistedAdmin);
      } catch {
        errored[i] = true;
      }
    }

    return (data, errored);
  }

  /**
   * @notice Returns total supply balance (in ETH), total borrow balance (in ETH), underlying token addresses, and underlying token symbols of a Fuse pool.
   */
  function getPoolSummary(IComptroller comptroller)
    external
    returns (
      uint256,
      uint256,
      address[] memory,
      string[] memory,
      bool
    )
  {
    uint256 totalBorrow = 0;
    uint256 totalSupply = 0;
    ICToken[] memory cTokens = comptroller.getAllMarkets();
    address[] memory underlyingTokens = new address[](cTokens.length);
    string[] memory underlyingSymbols = new string[](cTokens.length);
    IPriceOracle oracle = comptroller.oracle();

    for (uint256 i = 0; i < cTokens.length; i++) {
      ICToken cToken = cTokens[i];
      (bool isListed, ) = comptroller.markets(address(cToken));
      if (!isListed) continue;
      uint256 assetTotalBorrow = cToken.totalBorrowsCurrent();
      uint256 assetTotalSupply = cToken.getCash() +
        assetTotalBorrow -
        (cToken.totalReserves() + cToken.totalAdminFees() + cToken.totalFuseFees());
      uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
      totalBorrow = totalBorrow + (assetTotalBorrow * underlyingPrice) / 1e18;
      totalSupply = totalSupply + (assetTotalSupply * underlyingPrice) / 1e18;

      if (cToken.isCEther()) {
        underlyingTokens[i] = address(0);
        underlyingSymbols[i] = symbol;
      } else {
        underlyingTokens[i] = ICErc20(address(cToken)).underlying();
        (, underlyingSymbols[i]) = getTokenNameAndSymbol(underlyingTokens[i]);
      }
    }

    bool whitelistedAdmin = directory.adminWhitelist(comptroller.admin());
    return (totalSupply, totalBorrow, underlyingTokens, underlyingSymbols, whitelistedAdmin);
  }

  /**
   * @dev Struct for a Fuse pool asset.
   */
  struct FusePoolAsset {
    address cToken;
    address underlyingToken;
    string underlyingName;
    string underlyingSymbol;
    uint256 underlyingDecimals;
    uint256 underlyingBalance;
    uint256 supplyRatePerBlock;
    uint256 borrowRatePerBlock;
    uint256 totalSupply;
    uint256 totalBorrow;
    uint256 supplyBalance;
    uint256 borrowBalance;
    uint256 liquidity;
    bool membership;
    uint256 exchangeRate; // Price of cTokens in terms of underlying tokens
    uint256 underlyingPrice; // Price of underlying tokens in ETH (scaled by 1e18)
    address oracle;
    uint256 collateralFactor;
    uint256 reserveFactor;
    uint256 adminFee;
    uint256 fuseFee;
    bool borrowGuardianPaused;
    bool mintGuardianPaused;
  }

  /**
   * @notice Returns data on the specified assets of the specified Fuse pool.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   * @param comptroller The Comptroller proxy contract address of the Fuse pool.
   * @param cTokens The cToken contract addresses of the assets to query.
   * @param user The user for which to get account data.
   * @return An array of Fuse pool assets.
   */
  function getPoolAssetsWithData(
    IComptroller comptroller,
    ICToken[] memory cTokens,
    address user
  ) internal returns (FusePoolAsset[] memory) {
    uint256 arrayLength = 0;

    for (uint256 i = 0; i < cTokens.length; i++) {
      (bool isListed, ) = comptroller.markets(address(cTokens[i]));
      if (isListed) arrayLength++;
    }

    FusePoolAsset[] memory detailedAssets = new FusePoolAsset[](arrayLength);
    uint256 index = 0;
    BasePriceOracle oracle = BasePriceOracle(address(comptroller.oracle()));

    for (uint256 i = 0; i < cTokens.length; i++) {
      // Check if market is listed and get collateral factor
      (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(address(cTokens[i]));
      if (!isListed) continue;

      // Start adding data to FusePoolAsset
      FusePoolAsset memory asset;
      ICToken cToken = cTokens[i];
      asset.cToken = address(cToken);

      // Get underlying asset data
      if (cToken.isCEther()) {
        asset.underlyingName = name;
        asset.underlyingSymbol = symbol;
        asset.underlyingDecimals = 18;
        asset.underlyingBalance = user.balance;
      } else {
        asset.underlyingToken = ICErc20(address(cToken)).underlying();
        ERC20Upgradeable underlying = ERC20Upgradeable(asset.underlyingToken);
        (asset.underlyingName, asset.underlyingSymbol) = getTokenNameAndSymbol(asset.underlyingToken);
        asset.underlyingDecimals = underlying.decimals();
        asset.underlyingBalance = underlying.balanceOf(user);
      }

      // Get cToken data
      asset.supplyRatePerBlock = cToken.supplyRatePerBlock();
      asset.borrowRatePerBlock = cToken.borrowRatePerBlock();
      asset.liquidity = cToken.getCash();
      asset.totalBorrow = cToken.totalBorrowsCurrent();
      asset.totalSupply =
        asset.liquidity +
        asset.totalBorrow -
        (cToken.totalReserves() + cToken.totalAdminFees() + cToken.totalFuseFees());
      asset.supplyBalance = cToken.balanceOfUnderlying(user);
      asset.borrowBalance = cToken.borrowBalanceStored(user); // We would use borrowBalanceCurrent but we already accrue interest above
      asset.membership = comptroller.checkMembership(user, cToken);
      asset.exchangeRate = cToken.exchangeRateStored(); // We would use exchangeRateCurrent but we already accrue interest above
      asset.underlyingPrice = oracle.price(asset.underlyingToken);

      // Get oracle for this cToken
      asset.oracle = address(oracle);

      try MasterPriceOracle(asset.oracle).oracles(asset.underlyingToken) returns (IPriceOracle _oracle) {
        asset.oracle = address(_oracle);
      } catch {}

      // More cToken data
      asset.collateralFactor = collateralFactorMantissa;
      asset.reserveFactor = cToken.reserveFactorMantissa();
      asset.adminFee = cToken.adminFeeMantissa();
      asset.fuseFee = cToken.fuseFeeMantissa();
      asset.borrowGuardianPaused = comptroller.borrowGuardianPaused(address(cToken));
      asset.mintGuardianPaused = comptroller.mintGuardianPaused(address(cToken));

      // Add to assets array and increment index
      detailedAssets[index] = asset;
      index++;
    }

    return (detailedAssets);
  }

  /**
   * @notice Returns the `name` and `symbol` of `token`.
   * Supports Uniswap V2 and SushiSwap LP tokens as well as MKR.
   * @param token An ERC20 token contract object.
   * @return The `name` and `symbol`.
   */
  function getTokenNameAndSymbol(address token) internal view returns (string memory, string memory) {
    // i.e. MKR is a DSToken and uses bytes32
    if (bytes(hardcoded[token].symbol).length != 0) {
      return (hardcoded[token].name, hardcoded[token].symbol);
    }

    // Get name and symbol from token contract
    ERC20Upgradeable tokenContract = ERC20Upgradeable(token);
    string memory _name = tokenContract.name();
    string memory _symbol = tokenContract.symbol();

    // Check for Uniswap V2/SushiSwap pair
    // for (uint256 i = 0; i < uniswapData.length; i++) {
    //   try IUniswapV2Pair(token).token0() returns (address _token0) {
    //     UniswapData memory ud = uniswapData[i];
    //     bool isUniswapToken = keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked(ud.name)) &&
    //       keccak256(abi.encodePacked(_symbol)) == keccak256(abi.encodePacked(ud.symbol));

    //     if (isUniswapToken) {
    //       ERC20Upgradeable token0 = ERC20Upgradeable(_token0);
    //       ERC20Upgradeable token1 = ERC20Upgradeable(IUniswapV2Pair(token).token1());
    //       _name = string(abi.encodePacked(ud.displayName, " ", token0.symbol(), "/", token1.symbol(), " LP")); // add space
    //       _symbol = string(abi.encodePacked(token0.symbol(), "-", token1.symbol()));
    //       return (_name, _symbol);
    //     }
    //   } catch {}
    // }

    return (_name, _symbol);
  }

  /**
   * @notice Returns the assets of the specified Fuse pool.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   * @param comptroller The Comptroller proxy contract of the Fuse pool.
   * @return An array of Fuse pool assets.
   */
  function getPoolAssetsWithData(IComptroller comptroller) external returns (FusePoolAsset[] memory) {
    return getPoolAssetsWithData(comptroller, comptroller.getAllMarkets(), msg.sender);
  }

  /**
   * @dev Struct for a Fuse pool user.
   */
  struct FusePoolUser {
    address account;
    uint256 totalBorrow;
    uint256 totalCollateral;
    uint256 health;
  }

  /**
   * @notice Returns arrays of FusePoolAsset for a specific user
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   */
  function getPoolAssetsByUser(IComptroller comptroller, address user) public returns (FusePoolAsset[] memory) {
    FusePoolAsset[] memory assets = getPoolAssetsWithData(comptroller, comptroller.getAssetsIn(user), user);
    return assets;
  }

  /**
   * @notice Returns arrays of Fuse pool indexes and data with a whitelist containing `account`.
   * Note that the whitelist does not have to be enforced.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   */
  function getWhitelistedPoolsByAccount(address account)
    public
    view
    returns (uint256[] memory, FusePoolDirectory.FusePool[] memory)
  {
    (, FusePoolDirectory.FusePool[] memory pools) = directory.getActivePools();
    uint256 arrayLength = 0;

    for (uint256 i = 0; i < pools.length; i++) {
      IComptroller comptroller = IComptroller(pools[i].comptroller);

      if (comptroller.whitelist(account)) arrayLength++;
    }

    uint256[] memory indexes = new uint256[](arrayLength);
    FusePoolDirectory.FusePool[] memory accountPools = new FusePoolDirectory.FusePool[](arrayLength);
    uint256 index = 0;

    for (uint256 i = 0; i < pools.length; i++) {
      IComptroller comptroller = IComptroller(pools[i].comptroller);

      if (comptroller.whitelist(account)) {
        indexes[index] = i;
        accountPools[index] = pools[i];
        index++;
        break;
      }
    }

    return (indexes, accountPools);
  }

  /**
   * @notice Returns arrays of the indexes of Fuse pools with a whitelist containing `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
   * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
   * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
   */
  function getWhitelistedPoolsByAccountWithData(address account)
    external
    returns (
      uint256[] memory,
      FusePoolDirectory.FusePool[] memory,
      FusePoolData[] memory,
      bool[] memory
    )
  {
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = getWhitelistedPoolsByAccount(
      account
    );
    (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(accountPools);
    return (indexes, accountPools, data, errored);
  }

  /**
   * @notice Verify that the price of `underlying` of the given cToken matches KeydonixUniswapTwapPriceOracle
   * @param cToken The cToken which price we want to verify
   * @param proofData UniswapOracle.ProofData
   */
  function verifyPrice(ICToken cToken, UniswapOracle.ProofData calldata proofData) public returns (uint256, uint256) {
    IPriceOracle oracle = IComptroller(cToken.comptroller()).oracle();
    return IKeydonixUniswapTwapPriceOracle(address(oracle)).verifyPrice(cToken, proofData);
  }
}
