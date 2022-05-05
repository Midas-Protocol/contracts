pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract MockLpDepositor is Ownable {
  using SafeERC20 for IERC20;

  IERC20 public EPX;
  MockERC20 public DDD;
  MockERC20 public lpToken;

  // user -> pool -> deposit amount
  mapping(address => mapping(address => uint256)) public userBalances;
  // pool -> total deposit amount
  mapping(address => uint256) public totalBalances;

  event Deposit(address indexed caller, address indexed receiver, address indexed token, uint256 amount);
  event Withdraw(address indexed caller, address indexed receiver, address indexed token, uint256 amount);
  event Claimed(
    address indexed caller,
    address indexed receiver,
    address[] tokens,
    uint256 epxAmount,
    uint256 dddAmount
  );

  constructor(
    IERC20 _EPX,
    MockERC20 _DDD,
    MockERC20 _lpToken
  ) {
    EPX = _EPX;
    DDD = _DDD;
    lpToken = _lpToken;
  }

  function deposit(
    address _user,
    address _token,
    uint256 _amount
  ) external {
    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    uint256 balance = userBalances[_user][_token];
    uint256 total = totalBalances[_token];

    userBalances[_user][_token] = balance + _amount;
    totalBalances[_token] = total + _amount;

    MockERC20(lpToken).mint(_user, _amount);
    emit Deposit(msg.sender, _user, _token, _amount);
  }

  function withdraw(
    address _receiver,
    address _token,
    uint256 _amount
  ) external {
    uint256 balance = userBalances[msg.sender][_token];
    uint256 total = totalBalances[_token];
    require(balance >= _amount, "Insufficient balance");

    userBalances[msg.sender][_token] = balance - _amount;
    totalBalances[_token] = total - _amount;

    MockERC20(lpToken).burn(msg.sender, _amount);

    emit Withdraw(msg.sender, _receiver, _token, _amount);
  }

  /**
        @notice Claim pending EPX and DDD rewards
        @param _receiver Account to send claimed rewards to
        @param _tokens List of LP tokens to claim for
        @param _maxBondAmount Maximum amount of claimed EPX to convert to bonded dEPX.
                              Converting to bonded dEPX earns a multiplier on DDD rewards.
     */
  function claim(
    address _receiver,
    address[] calldata _tokens,
    uint256 _maxBondAmount
  ) external {
    _maxBondAmount;

    EPX.mint(_receiver, 1e18);
    DDD.mint(_receiver, 1e18);

    emit Claimed(msg.sender, _receiver, _tokens, 1e18, 1e18);
  }
}
