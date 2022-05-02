// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IBoringERC20 {
  function mint(address to, uint256 amount) external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function safeTransferFrom(
    address sender,
    address receiver,
    uint256 amount
  ) external;

  function safeTransfer(address receiver, uint256 amount) external;

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  /// @notice EIP 2612
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}

interface IMultipleRewards {
  function onBeamReward(
    uint256 pid,
    address user,
    uint256 newLpAmount
  ) external;

  function pendingTokens(uint256 pid, address user) external view returns (uint256 pending);

  function rewardToken() external view returns (IBoringERC20);

  function poolRewardsPerSec(uint256 pid) external view returns (uint256);
}

contract MockVault {
  IBoringERC20 public beam;

  uint256 public beamPerSec;
  uint256 public beamSharePercent;
  uint256 public startTimestamp;
  uint256 public totalBeamInPools;
  uint256 private constant ACC_TOKEN_PRECISION = 1e12;
  uint256 public totalAllocPoint;
  uint256 public totalLockedUpRewards;

  address public beamShareAddress;
  address public feeAddress;

  uint16 public constant MAXIMUM_DEPOSIT_FEE_RATE = 1000;
  uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

  // Info of each pool.
  struct PoolInfo {
    IBoringERC20 lpToken; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. Beam to distribute per block.
    uint256 lastRewardTimestamp; // Last block number that Beam distribution occurs.
    uint256 accBeamPerShare; // Accumulated Beam per share, times 1e18. See below.
    uint16 depositFeeBP; // Deposit fee in basis points
    uint256 harvestInterval; // Harvest interval in seconds
    uint256 totalLp; // Total token in Pool
    IMultipleRewards[] rewarders; // Array of rewarder contract for pools with incentives
  }

  PoolInfo[] public poolInfo;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    uint256 rewardLockedUp; // Reward locked up.
    uint256 nextHarvestUntil; // When can the user harvest again.
  }

  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  constructor(
    IBoringERC20 _beam,
    uint256 _beamPerSec,
    address _beamShareAddress,
    uint256 _beamSharePercent,
    address _feeAddress
  ) {
    startTimestamp = block.timestamp + (60 * 60 * 24 * 365);
    feeAddress = _feeAddress;
    beamPerSec = _beamPerSec;
    beam = _beam;
    beamPerSec = _beamPerSec;
    beamShareAddress = _beamShareAddress;
    beamSharePercent = _beamSharePercent;
  }

  // Internal method for _updatePool
  function _updatePool(uint256 _pid) internal {
    PoolInfo storage pool = poolInfo[_pid];

    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }

    uint256 lpSupply = pool.totalLp;

    if (lpSupply == 0 || pool.allocPoint == 0) {
      pool.lastRewardTimestamp = block.timestamp;
      return;
    }

    uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;

    uint256 beamReward = ((multiplier * beamPerSec) * pool.allocPoint) / totalAllocPoint;

    uint256 total = 1000;
    uint256 lpPercent = total - beamSharePercent;

    beam.mint(beamShareAddress, (beamReward * beamSharePercent) / total);
    beam.mint(address(this), (beamReward * lpPercent) / total);

    pool.accBeamPerShare += (beamReward * ACC_TOKEN_PRECISION * lpPercent) / pool.totalLp / total;

    pool.lastRewardTimestamp = block.timestamp;
  }

  function _deposit(uint256 _pid, uint256 _amount) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    _updatePool(_pid);

    payOrLockupPendingBeam(_pid);

    if (_amount > 0) {
      uint256 beforeDeposit = pool.lpToken.balanceOf(address(this));
      uint256 beforeDeposit1 = pool.lpToken.balanceOf(msg.sender);
      uint256 allowance = pool.lpToken.allowance(msg.sender, address(this));
      pool.lpToken.transferFrom(msg.sender, address(this), _amount);
      uint256 afterDeposit = pool.lpToken.balanceOf(address(this));

      _amount = afterDeposit - beforeDeposit;

      if (pool.depositFeeBP > 0) {
        uint256 depositFee = (_amount * pool.depositFeeBP) / 10000;
        pool.lpToken.safeTransfer(feeAddress, depositFee);

        _amount = _amount - depositFee;
      }

      user.amount += _amount;

      if (address(pool.lpToken) == address(beam)) {
        totalBeamInPools += _amount;
      }
    }
    user.rewardDebt = (user.amount * pool.accBeamPerShare) / ACC_TOKEN_PRECISION;

    for (uint256 rewarderId = 0; rewarderId < pool.rewarders.length; ++rewarderId) {
      pool.rewarders[rewarderId].onBeamReward(_pid, msg.sender, user.amount);
    }

    if (_amount > 0) {
      pool.totalLp += _amount;
    }
  }

  // Internal method for massUpdatePools
  function _massUpdatePools() internal {
    for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
      _updatePool(pid);
    }
  }

  function add(
    uint256 _allocPoint,
    IBoringERC20 _lpToken,
    uint16 _depositFeeBP,
    uint256 _harvestInterval,
    IMultipleRewards[] calldata _rewarders
  ) public {
    require(_rewarders.length <= 10, "add: too many rewarders");
    require(_depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE, "add: deposit fee too high");
    require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, "add: invalid harvest interval");
    for (uint256 rewarderId = 0; rewarderId < _rewarders.length; ++rewarderId) {
      require(Address.isContract(address(_rewarders[rewarderId])), "add: rewarder must be contract");
    }

    _massUpdatePools();

    uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;

    totalAllocPoint += _allocPoint;

    poolInfo.push(
      PoolInfo({
        lpToken: _lpToken,
        allocPoint: _allocPoint,
        lastRewardTimestamp: lastRewardTimestamp,
        accBeamPerShare: 0,
        depositFeeBP: _depositFeeBP,
        harvestInterval: _harvestInterval,
        totalLp: 0,
        rewarders: _rewarders
      })
    );
  }

  function canHarvest(uint256 _pid, address _user) public view returns (bool) {
    UserInfo storage user = userInfo[_pid][_user];
    return block.timestamp >= startTimestamp && block.timestamp >= user.nextHarvestUntil;
  }

  function safeBeamTransfer(address _to, uint256 _amount) internal {
    if (beam.balanceOf(address(this)) > totalBeamInPools) {
      //beamBal = total Beam in BeamChef - total Beam in Beam pools, this will make sure that BeamDistributor never transfer rewards from deposited Beam pools
      uint256 beamBal = beam.balanceOf(address(this)) - totalBeamInPools;
      if (_amount >= beamBal) {
        beam.safeTransfer(_to, beamBal);
      } else if (_amount > 0) {
        beam.safeTransfer(_to, _amount);
      }
    }
  }

  function payOrLockupPendingBeam(uint256 _pid) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (user.nextHarvestUntil == 0 && block.timestamp >= startTimestamp) {
      user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
    }

    uint256 pending = ((user.amount * pool.accBeamPerShare) / ACC_TOKEN_PRECISION) - user.rewardDebt;

    if (canHarvest(_pid, msg.sender)) {
      if (pending > 0 || user.rewardLockedUp > 0) {
        uint256 pendingRewards = pending + user.rewardLockedUp;

        // reset lockup
        totalLockedUpRewards -= user.rewardLockedUp;
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = block.timestamp + pool.harvestInterval;

        // send rewards
        safeBeamTransfer(msg.sender, pendingRewards);
      }
    } else if (pending > 0) {
      totalLockedUpRewards += pending;
      user.rewardLockedUp += pending;
    }
  }

  function deposit(uint256 _pid, uint256 _amount) public {
    _deposit(_pid, _amount);
  }

  function withdraw(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    //this will make sure that user can only withdraw from his pool
    require(user.amount >= _amount, "withdraw: user amount not enough");

    //cannot withdraw more than pool's balance
    require(pool.totalLp >= _amount, "withdraw: pool total not enough");

    _updatePool(_pid);

    payOrLockupPendingBeam(_pid);

    if (_amount > 0) {
      user.amount -= _amount;
      if (address(pool.lpToken) == address(beam)) {
        totalBeamInPools -= _amount;
      }
      pool.lpToken.transfer(msg.sender, _amount);
    }

    user.rewardDebt = (user.amount * pool.accBeamPerShare) / ACC_TOKEN_PRECISION;

    for (uint256 rewarderId = 0; rewarderId < pool.rewarders.length; ++rewarderId) {
      pool.rewarders[rewarderId].onBeamReward(_pid, msg.sender, user.amount);
    }

    if (_amount > 0) {
      pool.totalLp -= _amount;
    }
  }
}
