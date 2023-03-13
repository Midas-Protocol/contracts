// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./MidasERC4626.sol";

import "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";

  struct AdapterConfig {
  IERC4626Upgradeable adapter;
  uint64 allocation;
}

// TODO reentrancy guard?
contract OptimizedERC4626 is MidasERC4626 {
  constructor() {
    _disableInitializers();
  }

  function initialize(ERC20Upgradeable _asset) public initializer {
    __MidasER4626_init(_asset);

    performanceFee = 0;
    quitPeriod = 3 days;
  }

  function totalAssets() public view override returns (uint256) {
    return _asset().balanceOf(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    // TODO rebalance on deposit to offload the gas costs to the user
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {}

  AdapterConfig[10] public adapters;
  AdapterConfig[10] public proposedAdapters;

  uint8 public adapterCount;
  uint8 public proposedAdapterCount;

  uint256 public proposedAdapterTime;
  event NewAdaptersProposed(AdapterConfig[10] newAdapter, uint8 adapterCount, uint256 timestamp);
  event ChangedAdapters(
    AdapterConfig[10] oldAdapter,
    uint8 oldAdapterCount,
    AdapterConfig[10] newAdapter,
    uint8 newAdapterCount
  );

  error InvalidConfig();
  error InvalidAsset();
  error InvalidAdapter();
  error NotPassedQuitPeriod(uint256 quitPeriod);

  modifier takeFees() {
    //    uint256 managementFee = accruedManagementFee();
    //    uint256 totalFee = managementFee + accruedPerformanceFee();
    //    uint256 currentAssets = totalAssets();
    //    uint256 shareValue = convertToAssets(1e18);
    //
    //    if (shareValue > highWaterMark) highWaterMark = shareValue;
    //
    //    if (totalFee > 0 && currentAssets > 0) {
    //      uint256 supply = totalSupply();
    //      uint256 feeInShare = supply == 0
    //      ? totalFee
    //      : totalFee.mulDiv(supply, currentAssets - totalFee, Math.Rounding.Down);
    //      _mint(feeRecipient, feeInShare);
    //    }
    //
    //    feesUpdatedAt = block.timestamp;

    _;
  }

  function changeFees() external {
//    if (proposedFeeTime == 0 || block.timestamp < proposedFeeTime + quitPeriod) revert NotPassedQuitPeriod(quitPeriod);
//
//    emit ChangedFees(fees, proposedFees);
//
//    fees = proposedFees;
//    feesUpdatedAt = block.timestamp;
//
//    delete proposedFees;
//    delete proposedFeeTime;
  }

  function proposeAdapters(AdapterConfig[10] calldata newAdapters, uint8 newAdapterCount) external onlyOwner {
    _verifyAdapterConfig(newAdapters, newAdapterCount);

    for (uint8 i; i < newAdapterCount; i++) {
      proposedAdapters[i] = newAdapters[i];
    }

    proposedAdapterCount = newAdapterCount;

    proposedAdapterTime = block.timestamp;

    emit NewAdaptersProposed(newAdapters, proposedAdapterCount, block.timestamp);
  }

  function _verifyAdapterConfig(AdapterConfig[10] calldata newAdapters, uint8 adapterCount_) internal view {
    if (adapterCount_ == 0 || adapterCount_ > 10) revert InvalidConfig();

    uint256 totalAllocation;
    for (uint8 i; i < adapterCount_; i++) {
      if (newAdapters[i].adapter.asset() != asset()) revert InvalidAsset();

      uint256 allocation = uint256(newAdapters[i].allocation);
      if (allocation == 0) revert InvalidConfig();

      totalAllocation += allocation;
    }
    if (totalAllocation != 1e18) revert InvalidConfig();
  }

  function changeAdapters() external takeFees {
    if (proposedAdapterTime == 0 || block.timestamp < proposedAdapterTime + quitPeriod)
      revert NotPassedQuitPeriod(quitPeriod);
    //
    //    for (uint8 i; i < adapterCount; i++) {
    //      adapters[i].adapter.redeem(adapters[i].adapter.balanceOf(address(this)), address(this), address(this));
    //
    //      IERC20(asset()).approve(address(adapters[i].adapter), 0);
    //    }
    //
    //    emit ChangedAdapters(adapters, adapterCount, proposedAdapters, proposedAdapterCount);
    //
    //    adapters = proposedAdapters;
    //    adapterCount = proposedAdapterCount;
    //
    //    uint256 totalAssets_ = IERC20(asset()).balanceOf(address(this));
    //
    //    for (uint8 i; i < adapterCount; i++) {
    //      IERC20(asset()).approve(address(adapters[i].adapter), type(uint256).max);
    //
    //      adapters[i].adapter.deposit(
    //        totalAssets_.mulDiv(uint256(adapters[i].allocation), 1e18, Math.Rounding.Down),
    //        address(this)
    //      );
    //    }
    //
    //    delete proposedAdapters;
    //    delete proposedAdapterCount;
    //    delete proposedAdapterTime;
  }

  /*------------------------------------------------------------
                            RAGE QUIT LOGIC
    ------------------------------------------------------------*/

  uint256 public quitPeriod;

  event QuitPeriodSet(uint256 quitPeriod);

  error InvalidQuitPeriod();

  /**
   * @notice Set a quitPeriod for rage quitting after new adapter or fees are proposed. Caller must be Owner.
   * @param _quitPeriod Time to rage quit after proposal.
   */
  function setQuitPeriod(uint256 _quitPeriod) external onlyOwner {
//    if (block.timestamp < proposedAdapterTime + quitPeriod || block.timestamp < proposedFeeTime + quitPeriod)
//      revert NotPassedQuitPeriod(quitPeriod);
//    if (_quitPeriod < 1 days || _quitPeriod > 7 days) revert InvalidQuitPeriod();
//
//    quitPeriod = _quitPeriod;
//
//    emit QuitPeriodSet(quitPeriod);
  }
}
