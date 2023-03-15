// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
import { IConnext } from "@connext-interfaces/core/IConnext.sol";
import { IXReceiver } from "@connext-interfaces/core/IXReceiver.sol";
import { SafeERC20Upgradeable, IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { ICToken, ICErc20 } from "../external/compound/ICErc20.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";

import { ProposedOwnable } from "./ProposedOwnable.sol";

/**
 * @title CrossMinter
 * @notice Mint CToken from the connext cross-chain transaction
 */
contract CrossMinter is ProposedOwnable, IXReceiver {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @notice The Connext contract on this domain
   */
  IConnext public immutable connext;

  /**
   * @notice Contract which oversees inter-cToken operations
   */
  IComptroller public comptroller;

  constructor(address _connext, address _comptroller, address _king) {
    connext = IConnext(_connext);
    comptroller = IComptroller(_comptroller);
    _setOwner(_king);
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
    require(msg.sender == address(connext), "!connext");

    // Because this call is *not* authenticated, the _originSender will be the Zero Address
    // Decode call data and get CToken address, Minter Address
    (address _cToken, address _minter) = abi.decode(_callData, (address, address));

    require(_minter != address(0), "Zero Minter!");
    require(_amount > 0, "Zero Mint amount!");

    // Check underlying asset
    ICToken cToken = ICToken(_cToken);

    // Check If this contract enterred market
    if (!comptroller.checkMembership(address(this), cToken)) {
      address[] memory cTokens = new address[](1);
      cTokens[0] = address(_cToken);

      // enter market
      comptroller.enterMarkets(cTokens);
    }

    // Approve underlying
    if (!cToken.isCEther()) {
      safeApprove(IERC20Upgradeable(_asset), _cToken, _amount);
    } else {
      require(_asset == ICErc20(_cToken).underlying(), "!Underlying");
    }

    // Mint to this contract
    require(cToken.mint(_amount) == 0, "mint falied!");

    // Transfer CToken to minter
    CTokenInterface(_cToken).asCTokenExtensionInterface().transfer(_minter, cToken.balanceOf(address(this)));
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
   * @notice This sweep is used to rescue any funds that might get trapped in the contract due
   * to a failure in the `xReceive` user path.
   */
  function sweepToken(IERC20Upgradeable token, uint256 amount) public onlyOwner {
    token.transfer(_owner, amount);
  }

  /**
   * @notice This contract can receive gas to pay for nested xcall relayer fees.
   */
  receive() external payable {}

  fallback() external payable {}
}
