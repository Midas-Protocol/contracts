pragma solidity ^0.5.16;

import "./IFuseFeeDistributor.sol";

contract FuseFeeDistributor is IFuseFeeDistributor {
    function minBorrowEth() external view returns (uint256) {
        return 0;
    }
    function maxSupplyEth() external view returns (uint256) {
      return 0;
    }
    function maxUtilizationRate() external view returns (uint256) {
      return 0;
    }
    function interestFeeRate() external view returns (uint256) {
      return 0;
    }
    function comptrollerImplementationWhitelist(address oldImplementation, address newImplementation) external view returns (bool) {
      return true;
    }
    function cErc20DelegateWhitelist(address oldImplementation, address newImplementation, bool allowResign) external view returns (bool) {
      return true;
    }
    function cEtherDelegateWhitelist(address oldImplementation, address newImplementation, bool allowResign) external view returns (bool) {
      return true;
    }
    function latestComptrollerImplementation(address oldImplementation) external view returns (address) {
      return address(0);
    }
    function latestCErc20Delegate(address oldImplementation) external view returns (address cErc20Delegate, bool allowResign, bytes memory becomeImplementationData) {
      return (address(0), true, "0x");
    }
    function latestCEtherDelegate(address oldImplementation) external view returns (address cEtherDelegate, bool allowResign, bytes memory becomeImplementationData) {
      return (address(0), true, "0x");
    }
    function deployCEther(bytes calldata constructorData) external returns (address) {
      return address(0);
    }
    function deployCErc20(bytes calldata constructorData) external returns (address) {
      return address(0);
    }
    function () external payable {}
}
