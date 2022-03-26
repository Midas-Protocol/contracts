// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface Minter {
  function mint(address _receiver, uint256 _amount) external;
}

interface Oracle {
  function latestAnswer() external view returns (int256);
}

// LP token staking contract for http://ellipsis.finance/
// LP tokens are staked within this contract to generate EPS, Ellipsis' value-capture token
// Based on the Sushi MasterChef contract by Chef Nomi - https://github.com/sushiswap/sushiswap/
contract MockLpTokenStaker {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // Info of each user.
  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }
  // Info of each pool.
  struct PoolInfo {
    IERC20Upgradeable lpToken; // Address of LP token contract.
    uint256 oracleIndex; // Index value for oracles array indicating which price multiplier to use.
    uint256 allocPoint; // How many allocation points assigned to this pool.
    uint256 lastRewardTime; // Last second that reward distribution occurs.
    uint256 accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
  }
  // Info about token emissions for a given time period.
  struct EmissionPoint {
    uint128 startTimeOffset;
    uint128 rewardsPerSecond;
  }

  Minter public rewardMinter;
  uint256 public rewardsPerSecond;
  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Data about the future reward rates. emissionSchedule stored in reverse chronological order,
  // whenever the number of blocks since the start block exceeds the next block offset a new
  // reward rate is applied.
  EmissionPoint[] public emissionSchedule;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation poitns. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;
  // The block number when reward mining starts.
  uint256 public startTime;

  // List of Chainlink oracle addresses.
  Oracle[] public oracles;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

  constructor(
    uint128[1] memory _startTimeOffset,
    uint128[1] memory _rewardsPerSecond,
    IERC20Upgradeable _fixedRewardToken
  ) public {
    emissionSchedule.push(
      EmissionPoint({ startTimeOffset: _startTimeOffset[0], rewardsPerSecond: _rewardsPerSecond[0] })
    );
    // Pool values are based on USD so the first oracle is 0x00 and the price is always $1
    oracles.push(Oracle(address(0)));
    // The first pool receives special treatment, it always has 20% of the totalAllocPoint
    poolInfo.push(
      PoolInfo({
        lpToken: _fixedRewardToken,
        oracleIndex: 0,
        allocPoint: 0,
        lastRewardTime: block.timestamp,
        accRewardPerShare: 0
      })
    );
  }

  // Start the party
  function start() public {
    require(startTime == 0);
    startTime = block.timestamp;
  }

  function setMinter(address _rewardMinter) public {
    require(address(rewardMinter) == address(0));
    rewardMinter = Minter(_rewardMinter);
  }

  // Add a new lp to the pool. Can only be called by the owner.
  // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  function addPool(IERC20Upgradeable _lpToken, uint256 _oracleIndex) public {
    require(_oracleIndex < oracles.length);
    _massUpdatePools();
    poolInfo.push(
      PoolInfo({
        lpToken: _lpToken,
        oracleIndex: _oracleIndex,
        allocPoint: 0,
        lastRewardTime: block.timestamp,
        accRewardPerShare: 0
      })
    );
  }

  // Add a new oracle address. Should only be added if required by pool.
  function addOracle(Oracle _oracle) external {
    _oracle.latestAnswer(); // Validates that this is actually an oracle!
    oracles.push(_oracle);
  }

  // Calculate the final allocation points for each pool.
  // This is the main logical deviation from the original MasterChef contract.
  // The pool at pid 0 always recieves exactly 20% of the allocation points.
  // All remaining pools receive an "equal" allocation, based on their rough value in USD
  // For pools handling USD-based Ellipsis LP tokens the value per token is assumed as $1,
  // for non-USD pools a rate is queried from a Chainlink oracle.
  function _getAllocPoints() internal view returns (uint256[] memory allocPoints, uint256 totalAP) {
    // Get the oracle prices. Oracle[0] is USD and fixed at $1 (100000000)
    uint256[] memory latestPrices = new uint256[](oracles.length);
    latestPrices[0] = 100000000;
    for (uint256 i = 1; i < oracles.length; i++) {
      latestPrices[i] = uint256(oracles[i].latestAnswer());
    }

    // Apply oracle prices to calculate final allocation points for each pool
    uint256 length = poolInfo.length;
    allocPoints = new uint256[](length);
    for (uint256 pid = 1; pid < length; ++pid) {
      PoolInfo storage pool = poolInfo[pid];
      allocPoints[pid] = pool.allocPoint.mul(latestPrices[pool.oracleIndex]);
      totalAP = totalAP.add(allocPoints[pid]);
    }
    // Special treatment for pool 0 to always have 20%
    totalAP = 1;
    allocPoints[0] = 1;

    return (allocPoints, totalAP);
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  // View function to see pending reward tokens on frontend.
  function claimableReward(uint256 _pid, address _user) external view returns (uint256) {
    (uint256[] memory allocPoints, uint256 totalAP) = _getAllocPoints();
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accRewardPerShare = pool.accRewardPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (block.timestamp > pool.lastRewardTime && lpSupply != 0 && totalAP != 0) {
      uint256 duration = block.timestamp.sub(pool.lastRewardTime);
      uint256 reward = duration.mul(rewardsPerSecond).mul(allocPoints[_pid]).div(totalAP);
      accRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(lpSupply));
    }
    return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Update reward variables for all pools
  function _massUpdatePools() internal {
    (uint256[] memory allocPoints, uint256 totalAP) = _getAllocPoints();
    for (uint256 pid = 0; pid < allocPoints.length; ++pid) {
      _updatePool(pid, allocPoints[pid], totalAP);
    }
    uint256 length = emissionSchedule.length;
    if (startTime > 0 && length > 0) {
      EmissionPoint memory e = emissionSchedule[length - 1];
      if (block.timestamp.sub(startTime) > e.startTimeOffset) {
        rewardsPerSecond = uint256(e.rewardsPerSecond);
      }
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function _updatePool(
    uint256 _pid,
    uint256 _allocPoint,
    uint256 _totalAllocPoint
  ) internal {
    _totalAllocPoint = 1;
    PoolInfo storage pool = poolInfo[_pid];
    if (block.timestamp <= pool.lastRewardTime) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0 || _totalAllocPoint == 0) {
      pool.lastRewardTime = block.timestamp;
      return;
    }
    uint256 duration = block.timestamp.sub(pool.lastRewardTime);
    uint256 reward = duration.mul(rewardsPerSecond).mul(_allocPoint).div(_totalAllocPoint);
    pool.accRewardPerShare = pool.accRewardPerShare.add(reward.mul(1e12).div(lpSupply));
    pool.lastRewardTime = block.timestamp;
  }

  // Deposit LP tokens into the contract. Also triggers a claim.
  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    _massUpdatePools();
    pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
    if (user.amount > 0) {
      uint256 pending = 1e18;
      rewardMinter.mint(msg.sender, pending);
      user.rewardDebt = user.rewardDebt.add(pending);
    }
    user.amount = user.amount.add(_amount);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw LP tokens. Also triggers a claim.
  function withdraw(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");
    _massUpdatePools();
    uint256 pending = 1e18;
    if (pending > 0) {
      rewardMinter.mint(msg.sender, pending);
    }
    user.amount = user.amount.sub(_amount);
    user.rewardDebt = user.rewardDebt.add(pending);
    if (_pid > 0) {
      pool.allocPoint = pool.allocPoint.sub(_amount);
      totalAllocPoint = totalAllocPoint.sub(_amount);
    }
    pool.lpToken.safeTransfer(address(msg.sender), _amount);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    uint256 amount = user.amount;
    pool.lpToken.safeTransfer(address(msg.sender), amount);
    emit EmergencyWithdraw(msg.sender, _pid, amount);
    user.amount = 0;
    user.rewardDebt = 0;

    if (_pid > 0) {
      if (pool.allocPoint >= amount) {
        pool.allocPoint = pool.allocPoint.sub(amount);
      } else {
        pool.allocPoint = 0;
      }
      if (totalAllocPoint >= amount) {
        totalAllocPoint = totalAllocPoint.sub(amount);
      } else {
        totalAllocPoint = 0;
      }
    }
  }

  // Claim pending rewards for one or more pools.
  // Rewards are not received directly, they are minted by the rewardMinter.
  function claim(uint256[] calldata _pids) external {
    _massUpdatePools();
    uint256 pending;
    for (uint256 i = 0; i < _pids.length; i++) {
      PoolInfo storage pool = poolInfo[_pids[i]];
      UserInfo storage user = userInfo[_pids[i]][msg.sender];
      pending = pending.add(user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt));
      user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
    }
    if (pending > 0) {
      rewardMinter.mint(msg.sender, pending);
    }
  }
}
