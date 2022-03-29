// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./VeMDSToken.sol";
import "../compound/CToken.sol";
import "../external/compound/IComptroller.sol";

contract GaugesController is Initializable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable mdsToken;
  VeMDSToken veMdsToken;
  IComptroller comptroller;
  mapping(address => address) assetToGauge;

  function initialize(address _mdsTokenAddress, IComptroller _comptroller) public initializer {
    comptroller = _comptroller;
    mdsToken = IERC20Upgradeable(_mdsTokenAddress); // TODO typed contract param
  }

  function stake(uint256 amount) public {
    mdsToken.safeTransferFrom(msg.sender, address(this), amount);

    veMdsToken.mint(msg.sender, amount);
  }

  function getTotalVeSupply() public view returns (uint256) {
    // return the all-cross-chain supply
    // TODO cross-chain calls
    return veMdsToken.totalSupply();
  }

  function getTotalChainVeSupply() public view returns (uint256) {
    // return the supply for this chain only
    return veMdsToken.totalSupply();
  }

  function getTotalAssetVeSupply(CToken asset) public view returns (uint256) {
    (bool isListed, ) = comptroller.markets(address(asset));
    require(isListed == true, "comp market is not listed");

    address gauge = assetToGauge[address(asset)];

    return 0; // gauge.backingVeSupply();
  }

}
