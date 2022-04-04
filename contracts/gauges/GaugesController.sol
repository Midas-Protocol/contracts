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

  IERC20Upgradeable public mdsToken;
  VeMDSToken public veMdsToken;
  IComptroller public comptroller;
  mapping(address => address) public assetToGauge;
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) public stake;
  mapping(address => uint256) public totalVotesByGauge;
  mapping(address => mapping(address => uint256)) public votesByGaugeByAccount;

  function initialize(address _mdsTokenAddress, IComptroller _comptroller) public initializer {
    comptroller = _comptroller;
    mdsToken = IERC20Upgradeable(_mdsTokenAddress); // TODO typed contract param
  }

  function stake(uint256 amount) public {
    mdsToken.safeTransferFrom(msg.sender, address(this), amount);
    stakingStartedTime[msg.sender] = block.timestamp;
    stake[msg.sender] = amount;
  }

  // TODO integrate with FlywheelGaugeRewards

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

  function voteForGauge(address gaugeAddress, uint votes) public {
    // TODO delegation
    uint usedVP = veMdsToken.balanceOf(msg.sender);
    uint unlockedVP = votingPowerOf(msg.sender);
    uint usableVP = unlockedVP - usedVP;

    // TODO non-transferable?
    require(usableVP >= votes, "not enough voting power accumulated");

    veMdsToken.mint(msg.sender, votes);
    votesByGaugeByAccount[gaugeAddress][msg.sender] += votes;
    totalVotesByGauge[gaugeAddress] += votes;
  }

  function removeVotesForGauge(address gaugeAddress, uint votes) public {
    // TODO delegation
    uint vp = veMdsToken.balanceOf(msg.sender);

    // TODO verify gauge is registered
    require(votes <= votesByGaugeByAccount[gaugeAddress][msg.sender], "user has not allocated  as much votes to this gauge");

    veMdsToken.burn(msg.sender, votes);
    votesByGaugeByAccount[gaugeAddress][msg.sender] -= votes;
    totalVotesByGauge[gaugeAddress] -= votes;
  }

  function votingPowerOf(address account) public view returns (uint) {
    uint stakingStartedTime = gaugesController.stakingStartedTime(account);
    if (stakingStartedTime == 0) {
      return 0;
    } else {
      uint _stake = stake[account];
      uint hoursSinceStaked = (block.timestamp - stakingStartedTime) % 3600;
      if (hoursSinceStaked < 7143) { // 7143 * 0.014 = 100.002
        // percentage unlocked = hours since staked * 0.014
        return (_stake * hoursSinceStaked * 14) / 100000;
      } else {
        // 298 * 24 = 7152
        // during day 298 voting power becomes 100% of the staked MDS
        return _stake;
      }
    }
  }
}
