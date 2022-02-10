// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {IStrategy} from "./IStrategy.sol";

contract MockAutofarmV2 {
  struct UserInfo {
    uint256 shares; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  struct PoolInfo {
    ERC20 want; // Address of the want token.
    uint256 allocPoint; // How many allocation points assigned to this pool. AUTO to distribute per block.
    uint256 lastRewardBlock; // Last block number that AUTO distribution occurs.
    uint256 accAUTOPerShare; // Accumulated AUTO per share, times 1e12. See below.
    address strat; // Strategy address that will auto compound want tokens
  }

  PoolInfo[] public poolInfo; // Info of each pool.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
  uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

  constructor() {}

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  function add(
    ERC20 _want,
    uint256 _allocPoint,
    address _strat
  ) public {
    poolInfo.push(
      PoolInfo({
        want: _want,
        allocPoint: _allocPoint,
        lastRewardBlock: block.timestamp,
        accAUTOPerShare: 0,
        strat: _strat
      })
    );
  }

  function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];

    uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
    uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
    if (sharesTotal == 0) {
      return 0;
    }
    return (user.shares * wantLockedTotal) / sharesTotal;
  }

  // Want tokens moved from user -> AUTOFarm (AUTO allocation) -> Strat (compounding)
  function deposit(uint256 _pid, uint256 _wantAmt) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (user.shares > 0) {
      //   uint256 pending = user.shares.mul(pool.accAUTOPerShare).div(1e12).sub(user.rewardDebt);
      //   if (pending > 0) {
      //      safeAUTOTransfer(msg.sender, pending);
      //   }
    }
    if (_wantAmt > 0) {
      ERC20(pool.want).transferFrom(address(msg.sender), address(this), _wantAmt);

      ERC20(pool.want).approve(pool.strat, _wantAmt);
      uint256 sharesAdded = IStrategy(pool.strat).deposit(msg.sender, _wantAmt);
      user.shares = user.shares + sharesAdded;
    }
    user.rewardDebt = (user.shares * pool.accAUTOPerShare) / 1e12;
  }

  function withdraw(uint256 _pid, uint256 _wantAmt) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
    uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

    require(user.shares > 0, "user.shares is 0");
    require(sharesTotal > 0, "sharesTotal is 0");

    // Withdraw pending AUTO
    // uint256 pending = user.shares.mul(pool.accAUTOPerShare).div(1e12).sub(user.rewardDebt);
    // if (pending > 0) {
    //   safeAUTOTransfer(msg.sender, pending);
    // }

    // Withdraw want tokens
    uint256 amount = (user.shares * wantLockedTotal) / sharesTotal;
    if (_wantAmt > amount) {
      _wantAmt = amount;
    }
    if (_wantAmt > 0) {
      uint256 sharesRemoved = IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

      if (sharesRemoved > user.shares) {
        user.shares = 0;
      } else {
        user.shares = user.shares - sharesRemoved;
      }

      uint256 wantBal = ERC20(pool.want).balanceOf(address(this));
      if (wantBal < _wantAmt) {
        _wantAmt = wantBal;
      }
      pool.want.transfer(address(msg.sender), _wantAmt);
    }
    user.rewardDebt = (user.shares * pool.accAUTOPerShare) / 1e12;
  }
}
