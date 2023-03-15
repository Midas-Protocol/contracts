// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
import { IConnext } from "@connext/interfaces/core/IConnext.sol";
import { IXReceiver } from "@connext/interfaces/core/IXReceiver.sol";

import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { CTokenInterface, CErc20Interface } from "../compound/CTokenInterfaces.sol";

/**
 * @title CrossMinter
 * @notice Mint CToken from the connext cross-chain transaction
 */
contract CrossMinter is IXReceiver {
  /**
   * @notice The Connext contract on this domain
   */
  IConnext public immutable connext;

  /**
   * @notice Contract which oversees inter-cToken operations
   */
  ComptrollerInterface public comptroller;

  constructor(address _connext, address _comptroller) {
    connext = IConnext(_connext);
    comptroller = ComptrollerInterface(_comptroller);
  }

  /**
   * @notice The receiver function as required by the IXReceiver interface.
   * @dev The Connext bridge contract will call this function.
   */
  function xReceive(
    bytes32 _transferId,
    uint256 _amount,
    address _asset,
    address _originSender,
    uint32 _origin,
    bytes memory _callData
  ) external returns (bytes memory) {
    // Because this call is *not* authenticated, the _originSender will be the Zero Address
    // Decode call data and get CToken address, Minter Address
    (address _cToken, address _minter) = abi.decode(_callData, (address, address));

    require(_minter != address(0), "Zero Minter!");
    require(_amount > 0, "Zero Mint amount!");

    // Check underlying asset
    CTokenInterface cToken = CTokenInterface(_cToken);
    require(_asset == cToken.underlying(), "!Underlying");

    // Check If this contract enterred market
    if (!comptroller.checkMembership(address(this), cToken)) {
      address[] memory cTokens = new address[](1);
      cTokens[0] = address(_cToken);

      // enter market
      comptroller.enterMarkets(cTokens);
    }

    // Approve underlying
    if (!cToken.isCEther()) {
      safeApprove(_asset, _cToken, _amount);
    }

    // Mint to this contract
    require(cToken.mint(_amount) == 0, "mint falied!");

    // Transfer CToken to minter
    cToken.transfer(_minter, cToken.balanceOf(address(this)));
  }

  /**
   * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
   */
  function safeApprove(IERC20Upgradeable token, address to, uint256 minAmount) private {
    uint256 allowance = token.allowance(address(this), to);

    if (allowance < minAmount) {
      if (allowance > 0) token.safeApprove(to, 0);
      token.safeApprove(to, type(uint256).max);
    }
  }

  /**
   * @notice This contract can receive gas to pay for nested xcall relayer fees.
   */
  receive() external payable {}

  fallback() external payable {}
}
