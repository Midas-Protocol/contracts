pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXBomb is IERC20 {
  function reward() external view returns (IERC20);

  function leave(uint256 _share) external;

  function enter(uint256 _amount) external;

  function getExchangeRate() external view returns (uint256);

  function toREWARD(uint256 stakedAmount) external view returns (uint256 rewardAmount);

  function toSTAKED(uint256 rewardAmount) external view returns (uint256 stakedAmount);
}
