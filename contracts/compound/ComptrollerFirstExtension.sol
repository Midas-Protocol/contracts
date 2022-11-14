// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../midas/ComptrollerExtension.sol";
import { ComptrollerErrorReporter } from "../compound/ErrorReporter.sol";

contract ComptrollerFirstExtension is ComptrollerExtension, ComptrollerErrorReporter {
  /// @notice Emitted when supply cap for a cToken is changed
  event NewSupplyCap(CTokenInterface indexed cToken, uint256 newSupplyCap);

  /// @notice Emitted when borrow cap for a cToken is changed
  event NewBorrowCap(CTokenInterface indexed cToken, uint256 newBorrowCap);

  /// @notice Emitted when borrow cap guardian is changed
  event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

  /// @notice Emitted when pause guardian is changed
  event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

  /// @notice Emitted when an action is paused globally
  event ActionPaused(string action, bool pauseState);

  /// @notice Emitted when an action is paused on a market
  event MarketActionPaused(CTokenInterface cToken, string action, bool pauseState);

  /**
   * @notice Returns true if the accruing flyhwheel was found and replaced
   * @dev Adds a flywheel to the non-accruing list and if already in the accruing, removes it from that list
   * @param flywheelAddress The address of the flywheel to add to the non-accruing
   */
  function addNonAccruingFlywheel(address flywheelAddress) external returns (bool) {
    require(hasAdminRights(), "!admin");
    require(flywheelAddress != address(0), "!flywheel");

    for (uint256 i = 0; i < nonAccruingRewardsDistributors.length; i++) {
      require(flywheelAddress != nonAccruingRewardsDistributors[i], "!alreadyadded");
    }

    // add it to the non-accruing
    nonAccruingRewardsDistributors.push(flywheelAddress);

    // remove it from the accruing
    for (uint256 i = 0; i < rewardsDistributors.length; i++) {
      if (flywheelAddress == rewardsDistributors[i]) {
        rewardsDistributors[i] = rewardsDistributors[rewardsDistributors.length - 1];
        rewardsDistributors.pop();
        return true;
      }
    }

    return false;
  }

  /**
   * @notice Set the given supply caps for the given cToken markets. Supplying that brings total underlying supply to or above supply cap will revert.
   * @dev Admin or borrowCapGuardian function to set the supply caps. A supply cap of 0 corresponds to unlimited supplying.
   * @param cTokens The addresses of the markets (tokens) to change the supply caps for
   * @param newSupplyCaps The new supply cap values in underlying to be set. A value of 0 corresponds to unlimited supplying.
   */
  function _setMarketSupplyCaps(CTokenInterface[] calldata cTokens, uint256[] calldata newSupplyCaps) external {
    require(msg.sender == admin || msg.sender == borrowCapGuardian, "!admin");

    uint256 numMarkets = cTokens.length;
    uint256 numSupplyCaps = newSupplyCaps.length;

    require(numMarkets != 0 && numMarkets == numSupplyCaps, "!input");

    for (uint256 i = 0; i < numMarkets; i++) {
      supplyCaps[address(cTokens[i])] = newSupplyCaps[i];
      emit NewSupplyCap(cTokens[i], newSupplyCaps[i]);
    }
  }

  /**
   * @notice Set the given borrow caps for the given cToken markets. Borrowing that brings total borrows to or above borrow cap will revert.
   * @dev Admin or borrowCapGuardian function to set the borrow caps. A borrow cap of 0 corresponds to unlimited borrowing.
   * @param cTokens The addresses of the markets (tokens) to change the borrow caps for
   * @param newBorrowCaps The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.
   */
  function _setMarketBorrowCaps(CTokenInterface[] calldata cTokens, uint256[] calldata newBorrowCaps) external {
    require(msg.sender == admin || msg.sender == borrowCapGuardian, "!admin");

    uint256 numMarkets = cTokens.length;
    uint256 numBorrowCaps = newBorrowCaps.length;

    require(numMarkets != 0 && numMarkets == numBorrowCaps, "!input");

    for (uint256 i = 0; i < numMarkets; i++) {
      borrowCaps[address(cTokens[i])] = newBorrowCaps[i];
      emit NewBorrowCap(cTokens[i], newBorrowCaps[i]);
    }
  }

  /**
   * @notice Admin function to change the Borrow Cap Guardian
   * @param newBorrowCapGuardian The address of the new Borrow Cap Guardian
   */
  function _setBorrowCapGuardian(address newBorrowCapGuardian) external {
    require(msg.sender == admin, "!admin");

    // Save current value for inclusion in log
    address oldBorrowCapGuardian = borrowCapGuardian;

    // Store borrowCapGuardian with value newBorrowCapGuardian
    borrowCapGuardian = newBorrowCapGuardian;

    // Emit NewBorrowCapGuardian(OldBorrowCapGuardian, NewBorrowCapGuardian)
    emit NewBorrowCapGuardian(oldBorrowCapGuardian, newBorrowCapGuardian);
  }

  /**
   * @notice Admin function to change the Pause Guardian
   * @param newPauseGuardian The address of the new Pause Guardian
   * @return uint 0=success, otherwise a failure. (See enum Error for details)
   */
  function _setPauseGuardian(address newPauseGuardian) public returns (uint256) {
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_PAUSE_GUARDIAN_OWNER_CHECK);
    }

    // Save current value for inclusion in log
    address oldPauseGuardian = pauseGuardian;

    // Store pauseGuardian with value newPauseGuardian
    pauseGuardian = newPauseGuardian;

    // Emit NewPauseGuardian(OldPauseGuardian, NewPauseGuardian)
    emit NewPauseGuardian(oldPauseGuardian, pauseGuardian);

    return uint256(Error.NO_ERROR);
  }

  function _setMintPaused(CTokenInterface cToken, bool state) public returns (bool) {
    require(markets[address(cToken)].isListed, "!market");
    require(msg.sender == pauseGuardian || hasAdminRights(), "!gaurdian");
    require(hasAdminRights() || state == true, "!admin");

    mintGuardianPaused[address(cToken)] = state;
    emit MarketActionPaused(cToken, "Mint", state);
    return state;
  }

  function _setBorrowPaused(CTokenInterface cToken, bool state) public returns (bool) {
    require(markets[address(cToken)].isListed, "!market");
    require(msg.sender == pauseGuardian || hasAdminRights(), "!guardian");
    require(hasAdminRights() || state == true, "!admin");

    borrowGuardianPaused[address(cToken)] = state;
    emit MarketActionPaused(cToken, "Borrow", state);
    return state;
  }

  function _setTransferPaused(bool state) public returns (bool) {
    require(msg.sender == pauseGuardian || hasAdminRights(), "!guardian");
    require(hasAdminRights() || state == true, "!admin");

    transferGuardianPaused = state;
    emit ActionPaused("Transfer", state);
    return state;
  }

  function _setSeizePaused(bool state) public returns (bool) {
    require(msg.sender == pauseGuardian || hasAdminRights(), "!guardian");
    require(hasAdminRights() || state == true, "!admin");

    seizeGuardianPaused = state;
    emit ActionPaused("Seize", state);
    return state;
  }

  // a dummy fn to test if the extension works
  function getFirstMarketSymbol() public view returns (string memory) {
    return allMarkets[0].symbol();
  }

  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 i = 0;
    bytes4[] memory functionSelectors = new bytes4[](9);
    functionSelectors[i++] = this.addNonAccruingFlywheel.selector;
    functionSelectors[i++] = this._setMarketSupplyCaps.selector;
    functionSelectors[i++] = this._setMarketBorrowCaps.selector;
    functionSelectors[i++] = this._setBorrowCapGuardian.selector;
    functionSelectors[i++] = this._setPauseGuardian.selector;
    functionSelectors[i++] = this._setMintPaused.selector;
    functionSelectors[i++] = this._setBorrowPaused.selector;
    functionSelectors[i++] = this._setTransferPaused.selector;
    functionSelectors[i++] = this.getFirstMarketSymbol.selector;
    return functionSelectors;
  }
}
