// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./external/compound/IComptroller.sol";
import "./external/compound/IPriceOracle.sol";
import "./external/compound/ICToken.sol";
import "./external/compound/ICErc20.sol";
import "./external/compound/IRewardsDistributor.sol";

import "./external/uniswap/IUniswapV2Pair.sol";

import "./FusePoolDirectory.sol";
import "./oracles/MasterPriceOracle.sol";

/**
 * @title FusePoolLens
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolLens returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.
 */
contract FusePoolLens is Initializable {
    /**
     * @notice Constructor to set the `FusePoolDirectory` contract object.
     */
    function initialize(FusePoolDirectory _directory, string memory _name, string memory _symbol) public initializer {
        require(address(_directory) != address(0), "FusePoolDirectory instance cannot be the zero address.");
        directory = _directory;
        name = _name;
        symbol = _symbol;
    }

    string public name;
    string public symbol;

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
    function getPublicPoolsWithData() external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, FusePoolData[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory publicPools) = directory.getPublicPools();
        (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(publicPools);
        return (indexes, publicPools, data, errored);
    }

    /**
     * @notice Returns arrays of all whitelisted public Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPublicPoolsByVerificationWithData(bool whitelistedAdmin) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, FusePoolData[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory publicPools) = directory.getPublicPoolsByVerification(whitelistedAdmin);
        (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(publicPools);
        return (indexes, publicPools, data, errored);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools created by `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, FusePoolData[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = directory.getPoolsByAccount(account);
        (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(accountPools);
        return (indexes, accountPools, data, errored);
    }

    /**
     * @notice Internal function returning arrays of requested Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsData(FusePoolDirectory.FusePool[] memory pools) internal returns (FusePoolData[] memory, bool[] memory) {
        FusePoolData[] memory data = new FusePoolData[](pools.length);
        bool[] memory errored = new bool[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            try this.getPoolSummary(IComptroller(pools[i].comptroller)) returns (uint256 _totalSupply, uint256 _totalBorrow, address[] memory _underlyingTokens, string[] memory _underlyingSymbols, bool _whitelistedAdmin) {
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
    function getPoolSummary(IComptroller comptroller) external returns (uint256, uint256, address[] memory, string[] memory, bool) {
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
            uint256 assetTotalSupply = cToken.getCash() + assetTotalBorrow - (cToken.totalReserves() + cToken.totalAdminFees() + cToken.totalFuseFees());
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            totalBorrow = totalBorrow + (assetTotalBorrow * underlyingPrice) / 1e18;
            totalSupply = totalSupply + (assetTotalSupply * underlyingPrice) / 1e18;

            if (cToken.isCEther()) {
                underlyingTokens[i] = address(0);
                underlyingSymbols[i] = "ETH";
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
    function getPoolAssetsWithData(IComptroller comptroller, ICToken[] memory cTokens, address user) internal returns (FusePoolAsset[] memory) {
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < cTokens.length; i++) {
            (bool isListed, ) = comptroller.markets(address(cTokens[i]));
            if (isListed) arrayLength++;
        }

        FusePoolAsset[] memory detailedAssets = new FusePoolAsset[](arrayLength);
        uint256 index = 0;
        IPriceOracle oracle = comptroller.oracle();

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
            asset.totalSupply = asset.liquidity + asset.totalBorrow - (cToken.totalReserves() + cToken.totalAdminFees() + cToken.totalFuseFees());
            asset.supplyBalance = cToken.balanceOfUnderlying(user);
            asset.borrowBalance = cToken.borrowBalanceStored(user); // We would use borrowBalanceCurrent but we already accrue interest above
            asset.membership = comptroller.checkMembership(user, cToken);
            asset.exchangeRate = cToken.exchangeRateStored(); // We would use exchangeRateCurrent but we already accrue interest above
            asset.underlyingPrice = oracle.getUnderlyingPrice(cToken);

            // Get oracle for this cToken
            asset.oracle = address(oracle);

            try MasterPriceOracle(asset.oracle).oracles(asset.underlyingToken) returns (IPriceOracle _oracle) {
                asset.oracle = address(_oracle);
            } catch { }

            // More cToken data
            asset.collateralFactor = collateralFactorMantissa;
            asset.reserveFactor = cToken.reserveFactorMantissa();
            asset.adminFee = cToken.adminFeeMantissa();
            asset.fuseFee = cToken.fuseFeeMantissa();
            asset.borrowGuardianPaused = comptroller.borrowGuardianPaused(address(cToken));

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
        // MKR is a DSToken and uses bytes32
        if (token == 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2) return ("Maker", "MKR");
        if (token == 0xB8c77482e45F1F44dE1745F52C74426C631bDD52) return ("BNB", "BNB");

        // Get name and symbol from token contract
        ERC20Upgradeable tokenContract = ERC20Upgradeable(token);
        string memory name = tokenContract.name();
        string memory symbol = tokenContract.symbol();

        // Check for Uniswap V2/SushiSwap pair
        try IUniswapV2Pair(token).token0() returns (address _token0) {
            bool isUniswapToken = keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Uniswap V2")) && keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("UNI-V2"));
            bool isSushiSwapToken = !isUniswapToken && keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("SushiSwap LP Token")) && keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("SLP"));

            if (isUniswapToken || isSushiSwapToken) {
                ERC20Upgradeable token0 = ERC20Upgradeable(_token0);
                ERC20Upgradeable token1 = ERC20Upgradeable(IUniswapV2Pair(token).token1());
                name = string(abi.encodePacked(isSushiSwapToken ? "SushiSwap " : "Uniswap ", token0.symbol(), "/", token1.symbol(), " LP"));
                symbol = string(abi.encodePacked(token0.symbol(), "-", token1.symbol()));
            }
        } catch { }

        return (name, symbol);
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
     * @notice Returns arrays of Fuse pool indexes and data supplied to by `account`.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getPoolsBySupplier(address account) public view returns (uint256[] memory, FusePoolDirectory.FusePool[] memory) {
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            IComptroller comptroller = IComptroller(pools[i].comptroller);

            try comptroller.suppliers(account) returns (bool isSupplier) {
                if (isSupplier) {
                    ICToken[] memory allMarkets = comptroller.getAllMarkets();

                    for (uint256 j = 0; j < allMarkets.length; j++) if (allMarkets[j].balanceOf(account) > 0) {
                        arrayLength++;
                        break;
                    }
                }
            } catch {}
        }

        uint256[] memory indexes = new uint256[](arrayLength);
        FusePoolDirectory.FusePool[] memory accountPools = new FusePoolDirectory.FusePool[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            IComptroller comptroller = IComptroller(pools[i].comptroller);

            try comptroller.suppliers(account) returns (bool isSupplier) {
                if (isSupplier) {
                    ICToken[] memory allMarkets = comptroller.getAllMarkets();

                    for (uint256 j = 0; j < allMarkets.length; j++) if (allMarkets[j].balanceOf(account) > 0) {
                        indexes[index] = i;
                        accountPools[index] = pools[i];
                        index++;
                        break;
                    }
                }
            } catch {}
        }

        return (indexes, accountPools);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools supplied to by `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsBySupplierWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, FusePoolData[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = getPoolsBySupplier(account);
        (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(accountPools);
        return (indexes, accountPools, data, errored);
    }

    /**
     * @notice Returns arrays of Fuse pool indexes and data with a whitelist containing `account`.
     * Note that the whitelist does not have to be enforced.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getWhitelistedPoolsByAccount(address account) public view returns (uint256[] memory, FusePoolDirectory.FusePool[] memory) {
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
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
    function getWhitelistedPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, FusePoolData[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = getWhitelistedPoolsByAccount(account);
        (FusePoolData[] memory data, bool[] memory errored) = getPoolsData(accountPools);
        return (indexes, accountPools, data, errored);
    }
}
