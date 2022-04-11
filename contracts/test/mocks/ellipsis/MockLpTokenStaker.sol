// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20Mintable {
  function mint(address _to, uint256 _value) external;

  function minter() external view returns (address);
}

interface IStableSwap {
  function withdraw_admin_fees() external;
}

// based on the Sushi MasterChef
// https://github.com/sushiswap/sushiswap/blob/master/contracts/MasterChef.sol
contract MockLpTokenStaker is ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 depositAmount; // The amount of tokens deposited into the contract.
    uint256 adjustedAmount; // The user's effective balance after boosting, used to calculate emission rates.
    uint256 rewardDebt;
    uint256 claimable;
  }
  // Info of each pool.
  struct PoolInfo {
    uint256 adjustedSupply;
    uint256 rewardsPerSecond;
    uint256 lastRewardTime; // Last second that reward distribution occurs.
    uint256 accRewardPerShare; // Accumulated rewards per share, times 1e18. See below.
  }

  uint256 public immutable maxMintableTokens;
  uint256 public mintedTokens;

  // Info of each pool.
  address[] public registeredTokens;
  mapping(address => PoolInfo) public poolInfo;

  // token => user => Info of each user that stakes LP tokens.
  mapping(address => mapping(address => UserInfo)) public userInfo;
  // The timestamp when reward mining starts.
  uint256 public immutable startTime;

  // account earning rewards => receiver of rewards for this account
  // if receiver is set to address(0), rewards are paid to the earner
  // this is used to aid 3rd party contract integrations
  mapping(address => address) public claimReceiver;

  // when set to true, other accounts cannot call
  // `deposit` or `claim` on behalf of an account
  mapping(address => bool) public blockThirdPartyActions;

  // token => timestamp of last admin fee claim for the related pool
  // admin fees are claimed once per day when a user claims pending
  // rewards for the lp token
  mapping(address => uint256) public lastFeeClaim;

  IERC20Mintable public immutable rewardToken;

  uint192 rewardsStream = 0.5e18;

  event Deposit(address indexed user, address indexed token, uint256 amount);
  event Withdraw(address indexed user, address indexed token, uint256 amount);
  event EmergencyWithdraw(address indexed token, address indexed user, uint256 amount);
  event ClaimedReward(address indexed caller, address indexed claimer, address indexed receiver, uint256 amount);
  event FeeClaimSuccess(address pool);
  event FeeClaimRevert(address pool);

  constructor(IERC20Mintable _rewardToken, uint256 _maxMintable) {
    startTime = block.timestamp;
    rewardToken = _rewardToken;
    maxMintableTokens = _maxMintable;
  }

  /**
        @notice The current number of stakeable LP tokens
     */
  function poolLength() external view returns (uint256) {
    return registeredTokens.length;
  }

  /**
        @notice Add a new token that may be staked within this contract
        @dev Called by `IncentiveVoting` after a successful token approval vote
     */
  function addPool(address _token) external returns (bool) {
    require(poolInfo[_token].lastRewardTime == 0);
    registeredTokens.push(_token);
    poolInfo[_token].lastRewardTime = block.timestamp;
    return true;
  }

  /**
        @notice Set the claim receiver address for the caller
        @dev When the claim receiver is not == address(0), all
             emission claims are transferred to this address
        @param _receiver Claim receiver address
     */
  function setClaimReceiver(address _receiver) external {
    claimReceiver[msg.sender] = _receiver;
  }

  /**
        @notice Allow or block third-party calls to deposit, withdraw
                or claim rewards on behalf of the caller
     */
  function setBlockThirdPartyActions(bool _block) external {
    blockThirdPartyActions[msg.sender] = _block;
  }

  /**
        @notice Get the current number of unclaimed rewards for a user on one or more tokens
        @param _user User to query pending rewards for
        @param _tokens Array of token addresses to query
        @return uint256[] Unclaimed rewards
     */
  function claimableReward(address _user, address[] calldata _tokens) external returns (uint256[] memory) {
    uint256[] memory claimable = new uint256[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
      address token = _tokens[i];
      PoolInfo storage pool = poolInfo[token];
      UserInfo storage user = userInfo[token][_user];
      (uint256 accRewardPerShare, ) = _getRewardData(token);
      accRewardPerShare += pool.accRewardPerShare;
      claimable[i] = user.claimable + (user.adjustedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
    }
    return claimable;
  }

  // Get updated reward data for the given token
  function _getRewardData(address _token) internal returns (uint256 accRewardPerShare, uint256 rewardsPerSecond) {
    PoolInfo storage pool = poolInfo[_token];
    uint256 lpSupply = pool.adjustedSupply;
    uint256 start = startTime;
    uint256 currentWeek = (block.timestamp - start) / 604800;

    if (lpSupply == 0) {
      return (0, rewardsStream);
    }

    uint256 lastRewardTime = pool.lastRewardTime;
    // uint256 rewardWeek = (lastRewardTime - start) / 604800;
    rewardsPerSecond = pool.rewardsPerSecond;
    uint256 reward = 1;
    uint256 duration;
    /*if (rewardWeek < currentWeek) {
      while (rewardWeek < currentWeek) {
        uint256 nextRewardTime = (rewardWeek + 1) * 604800 + start;
        duration = nextRewardTime - lastRewardTime;
        reward = reward + duration * rewardsPerSecond;
        rewardWeek += 1;
        rewardsPerSecond = 10;
        lastRewardTime = nextRewardTime;
      }
    }*/
    duration = block.timestamp - lastRewardTime;
    reward = reward + duration * rewardsPerSecond;
    return ((reward * 1e18) / lpSupply, rewardsPerSecond);
  }

  // Update reward variables of the given pool to be up-to-date.
  function _updatePool(address _token) internal returns (uint256 accRewardPerShare) {
    PoolInfo storage pool = poolInfo[_token];
    uint256 lastRewardTime = pool.lastRewardTime;
    if (block.timestamp <= lastRewardTime) {
      return pool.accRewardPerShare;
    }
    (accRewardPerShare, pool.rewardsPerSecond) = _getRewardData(_token);
    pool.lastRewardTime = block.timestamp;
    if (accRewardPerShare == 0) return pool.accRewardPerShare;
    accRewardPerShare = accRewardPerShare + pool.accRewardPerShare;
    pool.accRewardPerShare = accRewardPerShare;
    return accRewardPerShare;
  }

  // calculate adjusted balance and total supply, used for boost
  // boost calculations are modeled after veCRV, with a max boost of 2.5x
  function _updateLiquidityLimits(
    address _user,
    address _token,
    uint256 _depositAmount,
    uint256 _accRewardPerShare
  ) internal {
    uint256 adjustedAmount = _depositAmount;
    UserInfo storage user = userInfo[_token][_user];
    uint256 newAdjustedSupply = poolInfo[_token].adjustedSupply - user.adjustedAmount;
    user.adjustedAmount = _depositAmount;
    poolInfo[_token].adjustedSupply = newAdjustedSupply + adjustedAmount;
    user.rewardDebt = (adjustedAmount * _accRewardPerShare) / 1e18;
  }

  /**
        @notice Deposit LP tokens into the contract
        @dev Also updates the receiver's current boost
        @param _token LP token address to deposit.
        @param _amount Amount of tokens to deposit.
        @param _claimRewards If true, also claim rewards earned on the token.
        @return uint256 Claimed reward amount
     */
  function deposit(
    address _token,
    uint256 _amount,
    bool _claimRewards
  ) external nonReentrant returns (uint256) {
    require(_amount > 0, "Cannot deposit zero");
    uint256 accRewardPerShare = _updatePool(_token);
    UserInfo storage user = userInfo[_token][msg.sender];
    uint256 pending;
    if (user.adjustedAmount > 0) {
      pending = (user.adjustedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
      if (_claimRewards) {
        pending += user.claimable;
        user.claimable = 0;
        pending = _mintRewards(msg.sender, pending);
      } else if (pending > 0) {
        user.claimable += pending;
        pending = 0;
      }
    }
    IERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);
    uint256 depositAmount = user.depositAmount + _amount;
    user.depositAmount = depositAmount;
    _updateLiquidityLimits(msg.sender, _token, depositAmount, accRewardPerShare);
    emit Deposit(msg.sender, _token, _amount);
    return pending;
  }

  /**
        @notice Withdraw LP tokens from the contract
        @dev Also updates the caller's current boost
        @param _token LP token address to withdraw.
        @param _amount Amount of tokens to withdraw.
        @param _claimRewards If true, also claim rewards earned on the token.
        @return uint256 Claimed reward amount
     */
  function withdraw(
    address _token,
    uint256 _amount,
    bool _claimRewards
  ) external nonReentrant returns (uint256) {
    require(_amount > 0, "Cannot withdraw zero");
    uint256 accRewardPerShare = _updatePool(_token);
    UserInfo storage user = userInfo[_token][msg.sender];
    uint256 depositAmount = user.depositAmount;
    require(depositAmount >= _amount, "withdraw: not good");

    uint256 pending = (user.adjustedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
    if (_claimRewards) {
      pending += user.claimable;
      user.claimable = 0;
      pending = _mintRewards(msg.sender, pending);
    } else if (pending > 0) {
      user.claimable += pending;
      pending = 0;
    }

    depositAmount -= _amount;
    user.depositAmount = depositAmount;
    _updateLiquidityLimits(msg.sender, _token, depositAmount, accRewardPerShare);
    IERC20(_token).safeTransfer(msg.sender, _amount);
    emit Withdraw(msg.sender, _token, _amount);
    return pending;
  }

  /**
        @notice Withdraw a user's complete deposited balance of an LP token
                without updating rewards calculations.
        @dev Should be used only in an emergency when there is an error in
             the reward math that prevents a normal withdrawal.
        @param _token LP token address to withdraw.
     */
  function emergencyWithdraw(address _token) external nonReentrant {
    UserInfo storage user = userInfo[_token][msg.sender];
    poolInfo[_token].adjustedSupply -= user.adjustedAmount;

    uint256 amount = user.depositAmount;
    delete userInfo[_token][msg.sender];
    IERC20(_token).safeTransfer(address(msg.sender), amount);
    emit EmergencyWithdraw(_token, msg.sender, amount);
  }

  /**
        @notice Claim pending rewards for one or more tokens for a user.
        @dev Also updates the claimer's boost.
        @param _user Address to claim rewards for. Reverts if the caller is not the
                     claimer and the claimer has blocked third-party actions.
        @param _tokens Array of LP token addresses to claim for.
        @return uint256 Claimed reward amount
     */
  function claim(address _user, address[] calldata _tokens) external returns (uint256) {
    if (msg.sender != _user) {
      require(!blockThirdPartyActions[_user], "Cannot claim on behalf of this account");
    }

    // calculate claimable amount
    uint256 pending;
    for (uint256 i = 0; i < _tokens.length; i++) {
      address token = _tokens[i];
      uint256 accRewardPerShare = _updatePool(token);
      UserInfo storage user = userInfo[token][_user];
      uint256 rewardDebt = (user.adjustedAmount * accRewardPerShare) / 1e18;
      pending += user.claimable + rewardDebt - user.rewardDebt;
      user.claimable = 0;
      _updateLiquidityLimits(_user, token, user.depositAmount, accRewardPerShare);

      // claim admin fees for each pool once per day
      if (lastFeeClaim[token] + 86400 < block.timestamp) {
        address pool = IERC20Mintable(token).minter();
        try IStableSwap(pool).withdraw_admin_fees() {
          emit FeeClaimSuccess(pool);
        } catch {
          emit FeeClaimRevert(pool);
        }
        lastFeeClaim[token] = block.timestamp;
      }
    }
    return _mintRewards(_user, pending);
  }

  function _mintRewards(address _user, uint256 _amount) internal returns (uint256) {
    uint256 minted = mintedTokens;
    if (minted + _amount > maxMintableTokens) {
      _amount = maxMintableTokens - minted;
    }
    if (_amount > 0) {
      mintedTokens = minted + _amount;
      address receiver = claimReceiver[_user];
      if (receiver == address(0)) receiver = _user;
      rewardToken.mint(receiver, _amount);
      emit ClaimedReward(msg.sender, _user, receiver, _amount);
    }
    return _amount;
  }

  /**
        @notice Update a user's boost for one or more deposited tokens
        @param _user Address of the user to update boosts for
        @param _tokens Array of LP tokens to update boost for
     */
  function updateUserBoosts(address _user, address[] calldata _tokens) external {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address token = _tokens[i];
      uint256 accRewardPerShare = _updatePool(token);
      UserInfo storage user = userInfo[token][_user];
      if (user.adjustedAmount > 0) {
        uint256 pending = (user.adjustedAmount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) {
          user.claimable += pending;
        }
      }
      _updateLiquidityLimits(_user, token, user.depositAmount, accRewardPerShare);
    }
  }
}
