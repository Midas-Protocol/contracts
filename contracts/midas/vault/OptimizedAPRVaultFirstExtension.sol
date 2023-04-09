// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../DiamondExtension.sol";
import "./OptimizedAPRVaultExtension.sol";
import { OptimizedVaultsRegistry } from "./OptimizedVaultsRegistry.sol";
import { MidasFlywheel } from "../strategies/flywheel/MidasFlywheel.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { FlywheelCore } from "flywheel/FlywheelCore.sol";

import { SafeERC20Upgradeable as SafeERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { MathUpgradeable as Math } from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

contract OptimizedAPRVaultFirstExtension is OptimizedAPRVaultExtension {
  using SafeERC20 for IERC20;
  using Math for uint256;

  event RewardDestinationUpdate(address indexed newDestination);
  event EmergencyExitActivated();

  constructor() {
    _disableInitializers();
  }

  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 17;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.initialize.selector;
    functionSelectors[--fnsCount] = this.accruedManagementFee.selector;
    functionSelectors[--fnsCount] = this.accruedPerformanceFee.selector;
    functionSelectors[--fnsCount] = this.takeManagementAndPerformanceFees.selector;
    functionSelectors[--fnsCount] = this.proposeFees.selector;
    functionSelectors[--fnsCount] = this.changeFees.selector;
    functionSelectors[--fnsCount] = this.setFeeRecipient.selector;
    functionSelectors[--fnsCount] = this.proposeAdapters.selector;
    functionSelectors[--fnsCount] = this.changeAdapters.selector;
    functionSelectors[--fnsCount] = this.setQuitPeriod.selector;
    functionSelectors[--fnsCount] = this.setEmergencyExit.selector;
    functionSelectors[--fnsCount] = this.claimRewards.selector;
    functionSelectors[--fnsCount] = this.getAllFlywheels.selector;
    functionSelectors[--fnsCount] = this.addRewardToken.selector;
    functionSelectors[--fnsCount] = this.DOMAIN_SEPARATOR.selector;
    functionSelectors[--fnsCount] = this.permit.selector;
    functionSelectors[--fnsCount] = this.upgradeVault.selector;

    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function upgradeVault() public onlyOwner {
    address[] memory currentExtensions = LibDiamond.listExtensions();
    for (uint256 i = 0; i < currentExtensions.length; i++) {
      LibDiamond.removeExtension(DiamondExtension(currentExtensions[i]));
    }

    OptimizedAPRVaultExtension[] memory latestExtensions = registry.getLatestVaultExtensions(address(this));
    for (uint256 i = 0; i < latestExtensions.length; i++) {
      LibDiamond.addExtension(latestExtensions[i]);
    }
  }

  function initialize(bytes calldata data) public initializer {
    require(msg.sender == address(this), "!not self call");

    (
      IERC20 asset_,
      AdapterConfig[10] memory adapters_,
      uint8 adaptersCount_,
      VaultFees memory fees_,
      address feeRecipient_,
      uint256 depositLimit_,
      address owner_,
      OptimizedVaultsRegistry registry_,
      address flywheelLogic_
    ) = abi.decode(data, (IERC20, AdapterConfig[10], uint8, VaultFees, address, uint256, address, OptimizedVaultsRegistry, address));

    if (address(asset_) == address(0)) revert AssetInvalid();
    __ERC4626_init(asset_);

    _name = string(bytes.concat("Midas Optimized ", bytes(IERC20Metadata(address(asset_)).name()), " Vault"));
    _symbol = string(bytes.concat("mo-", bytes(IERC20Metadata(address(asset_)).symbol())));
    _decimals = IERC20Metadata(address(asset_)).decimals() + DECIMAL_OFFSET; // Asset decimals + decimal offset to combat inflation attacks

    depositLimit = depositLimit_;
    registry = registry_;
    flywheelLogic = flywheelLogic_;
    INITIAL_CHAIN_ID = block.chainid;
    INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    feesUpdatedAt = block.timestamp;
    highWaterMark = 1e9;
    quitPeriod = 3 days;

    // vault fees
    if (fees_.deposit >= 1e18 || fees_.withdrawal >= 1e18 || fees_.management >= 1e18 || fees_.performance >= 1e18)
      revert InvalidVaultFees();
    fees = fees_;

    // fee recipient
    if (feeRecipient_ == address(0)) revert InvalidFeeRecipient();
    feeRecipient = feeRecipient_;

    // adapters config
    _verifyAdapterConfig(adapters_, adaptersCount_);
    adaptersCount = adaptersCount_;
    for (uint8 i; i < adaptersCount_; i++) {
      adapters[i] = adapters_[i];
      asset_.approve(address(adapters_[i].adapter), type(uint256).max);
    }
  }

  /*------------------------------------------------------------
                            EIP-2612 LOGIC
    ------------------------------------------------------------*/

  error PermitDeadlineExpired(uint256 deadline);
  error InvalidSigner(address signer);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual {
    if (deadline < block.timestamp) revert PermitDeadlineExpired(deadline);

    // Unchecked because the only math done is incrementing
    // the owner's nonce which cannot realistically overflow.
    unchecked {
      address recoveredAddress = ecrecover(
        keccak256(
          abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR(),
            keccak256(
              abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline
              )
            )
          )
        ),
        v,
        r,
        s
      );

      if (recoveredAddress == address(0) || recoveredAddress != owner) revert InvalidSigner(recoveredAddress);

      _approve(recoveredAddress, spender, value);
    }
  }

  function computeDomainSeparator() internal view virtual returns (bytes32) {
    return
      keccak256(
        abi.encode(
          keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
          keccak256(bytes(_name)),
          keccak256("1"),
          block.chainid,
          address(this)
        )
      );
  }

  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
  }

  /*------------------------------------------------------------
                      FEE ACCOUNTING LOGIC
  ------------------------------------------------------------*/

  /**
   * @notice Management fee that has accrued since last fee harvest.
   * @return Accrued management fee in underlying `asset` token.
   * @dev Management fee is annualized per minute, based on 525,600 minutes per year. Total assets are calculated using
   *  the average of their current value and the value at the previous fee harvest checkpoint. This method is similar to
   *  calculating a definite integral using the trapezoid rule.
   */
  function accruedManagementFee() public view returns (uint256) {
    uint256 managementFee = fees.management;
    return
      managementFee > 0
        ? managementFee.mulDiv(
          totalAssets() * (block.timestamp - feesUpdatedAt),
          SECONDS_PER_YEAR,
          Math.Rounding.Down
        ) / 1e18
        : 0;
  }

  /**
   * @notice Performance fee that has accrued since last fee harvest.
   * @return Accrued performance fee in underlying `asset` token.
   * @dev Performance fee is based on a high water mark value. If vault share value has increased above the
   *   HWM in a fee period, issue fee shares to the vault equal to the performance fee.
   */
  function accruedPerformanceFee() public view returns (uint256) {
    uint256 highWaterMark_ = highWaterMark;
    uint256 shareValue = convertToAssets(1e18);
    uint256 performanceFee = fees.performance;

    return
      performanceFee > 0 && shareValue > highWaterMark_
        ? performanceFee.mulDiv((shareValue - highWaterMark_) * totalSupply(), 1e36, Math.Rounding.Down)
        : 0;
  }

  /*------------------------------------------------------------
                            FEE LOGIC
    ------------------------------------------------------------*/

  error InsufficientWithdrawalAmount(uint256 amount);

  /// @notice Minimal function to call `takeFees` modifier.
  function takeManagementAndPerformanceFees() external takeFees {}

  /// @notice Collect management and performance fees and update vault share high water mark.
  modifier takeFees() {
    uint256 managementFee = accruedManagementFee();
    uint256 totalFee = managementFee + accruedPerformanceFee();
    uint256 currentAssets = totalAssets();
    uint256 shareValue = convertToAssets(1e18);

    if (shareValue > highWaterMark) highWaterMark = shareValue;

    if (totalFee > 0 && currentAssets > 0) {
      uint256 supply = totalSupply();
      uint256 feeInShare = supply == 0
        ? totalFee
        : totalFee.mulDiv(supply, currentAssets - totalFee, Math.Rounding.Down);
      _mint(feeRecipient, feeInShare);
    }

    feesUpdatedAt = block.timestamp;

    _;
  }

  /*------------------------------------------------------------
                        FEE MANAGEMENT LOGIC
    ------------------------------------------------------------*/

  event NewFeesProposed(VaultFees newFees, uint256 timestamp);
  event ChangedFees(VaultFees oldFees, VaultFees newFees);
  event FeeRecipientUpdated(address oldFeeRecipient, address newFeeRecipient);

  /**
   * @notice Propose new fees for this vault. Caller must be owner.
   * @param newFees Fees for depositing, withdrawal, management and performance in 1e18.
   * @dev Fees can be 0 but never 1e18 (1e18 = 100%, 1e14 = 1 BPS)
   */
  function proposeFees(VaultFees calldata newFees) external onlyOwner {
    if (
      newFees.deposit >= 1e18 || newFees.withdrawal >= 1e18 || newFees.management >= 1e18 || newFees.performance >= 1e18
    ) revert InvalidVaultFees();

    proposedFees = newFees;
    proposedFeeTime = block.timestamp;

    emit NewFeesProposed(newFees, block.timestamp);
  }

  /// @notice Change fees to the previously proposed fees after the quit period has passed.
  function changeFees() external {
    if (proposedFeeTime == 0 || block.timestamp < proposedFeeTime + quitPeriod) revert NotPassedQuitPeriod();

    emit ChangedFees(fees, proposedFees);

    fees = proposedFees;
    feesUpdatedAt = block.timestamp;

    delete proposedFees;
    delete proposedFeeTime;
  }

  /**
   * @notice Change `feeRecipient`. Caller must be Owner.
   * @param _feeRecipient The new fee recipient.
   * @dev Accrued fees wont be transferred to the new feeRecipient.
   */
  function setFeeRecipient(address _feeRecipient) external onlyOwner {
    if (_feeRecipient == address(0)) revert InvalidFeeRecipient();

    emit FeeRecipientUpdated(feeRecipient, _feeRecipient);

    feeRecipient = _feeRecipient;
  }

  /*------------------------------------------------------------
                            ADAPTER LOGIC
    ------------------------------------------------------------*/

  event NewAdaptersProposed(AdapterConfig[10] newAdapter, uint8 adaptersCount, uint256 timestamp);
  event ChangedAdapters(
    AdapterConfig[10] oldAdapter,
    uint8 oldAdaptersCount,
    AdapterConfig[10] newAdapter,
    uint8 newAdaptersCount
  );

  /**
   * @notice Propose a new adapter for this vault. Caller must be Owner.
   * @param newAdapters A new ERC4626 that should be used as a yield adapter for this asset.
   * @param newAdaptersCount Amount of new adapters.
   */
  function proposeAdapters(AdapterConfig[10] calldata newAdapters, uint8 newAdaptersCount) external onlyOwner {
    _verifyAdapterConfig(newAdapters, newAdaptersCount);

    for (uint8 i; i < newAdaptersCount; i++) {
      proposedAdapters[i] = newAdapters[i];
    }

    proposedAdaptersCount = newAdaptersCount;

    proposedAdapterTime = block.timestamp;

    emit NewAdaptersProposed(newAdapters, proposedAdaptersCount, block.timestamp);
  }

  /**
   * @notice Set a new Adapter for this Vault after the quit period has passed.
   * @dev This migration function will remove all assets from the old Vault and move them into the new vault
   * @dev Additionally it will zero old allowances and set new ones
   * @dev Last we update HWM and assetsCheckpoint for fees to make sure they adjust to the new adapter
   */
  function changeAdapters() external takeFees {
    if (proposedAdapterTime == 0 || block.timestamp < proposedAdapterTime + quitPeriod) revert NotPassedQuitPeriod();

    for (uint8 i; i < adaptersCount; i++) {
      adapters[i].adapter.redeem(adapters[i].adapter.balanceOf(address(this)), address(this), address(this));

      IERC20(asset()).approve(address(adapters[i].adapter), 0);
    }

    emit ChangedAdapters(adapters, adaptersCount, proposedAdapters, proposedAdaptersCount);

    adapters = proposedAdapters;
    adaptersCount = proposedAdaptersCount;

    uint256 cashAssets_ = IERC20(asset()).balanceOf(address(this));

    for (uint8 i; i < adaptersCount; i++) {
      IERC20(asset()).approve(address(adapters[i].adapter), type(uint256).max);

      adapters[i].adapter.deposit(
        cashAssets_.mulDiv(uint256(adapters[i].allocation), 1e18, Math.Rounding.Down),
        address(this)
      );
    }

    delete proposedAdapters;
    delete proposedAdaptersCount;
    delete proposedAdapterTime;
  }

  /*------------------------------------------------------------
                            RAGE QUIT LOGIC
    ------------------------------------------------------------*/

  event QuitPeriodSet(uint256 quitPeriod);

  error InvalidQuitPeriod();

  /**
   * @notice Set a quitPeriod for rage quitting after new adapter or fees are proposed. Caller must be Owner.
   * @param _quitPeriod Time to rage quit after proposal.
   */
  function setQuitPeriod(uint256 _quitPeriod) external onlyOwner {
    if (block.timestamp < proposedAdapterTime + quitPeriod || block.timestamp < proposedFeeTime + quitPeriod)
      revert NotPassedQuitPeriod();
    if (_quitPeriod < 1 days || _quitPeriod > 7 days) revert InvalidQuitPeriod();

    quitPeriod = _quitPeriod;

    emit QuitPeriodSet(quitPeriod);
  }

  function setEmergencyExit() external {
    require(msg.sender == owner() || msg.sender == address(registry), "not registry or owner");

    for (uint256 i; i < adaptersCount; ++i) {
      adapters[i].adapter.withdrawAll();
    }

    emergencyExit = true;
    _pause();

    emit EmergencyExitActivated();
  }

  /// @notice claim all token rewards
  function claimRewards() public {
    for (uint256 i; i < adaptersCount; ++i) {
      adapters[i].adapter.claimRewards();
    }
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    super._afterTokenTransfer(from, to, amount);
    for (uint256 i; i < rewardTokens.length; ++i) {
      flywheelForRewardToken[rewardTokens[i]].accrue(ERC20(address(this)), from, to);
    }
  }

  function getAllFlywheels() external view returns (MidasFlywheel[] memory allFlywheels) {
    allFlywheels = new MidasFlywheel[](rewardTokens.length);
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      allFlywheels[i] = flywheelForRewardToken[rewardTokens[i]];
    }
  }

  function addRewardToken(IERC20 token_) public {
    require(msg.sender == owner() || msg.sender == address(this), "!owner or self");
    require(address(flywheelForRewardToken[token_]) == address(0), "already added");

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(flywheelLogic, address(registry), "");
    MidasFlywheel newFlywheel = MidasFlywheel(address(proxy));

    newFlywheel.initialize(
      ERC20(address(token_)),
      IFlywheelRewards(address(this)),
      IFlywheelBooster(address(0)),
      address(this)
    );
    FuseFlywheelDynamicRewards rewardsContract = new FuseFlywheelDynamicRewards(
      FlywheelCore(address(newFlywheel)),
      1 days
    );
    newFlywheel.setFlywheelRewards(rewardsContract);
    token_.approve(address(rewardsContract), type(uint256).max);
    newFlywheel.updateFeeSettings(0, address(this));
    // TODO accept owner
    newFlywheel._setPendingOwner(owner());

    // lets the vault shareholders accrue
    newFlywheel.addStrategyForRewards(ERC20(address(this)));
    flywheelForRewardToken[token_] = newFlywheel;
    rewardTokens.push(token_);
  }
}
