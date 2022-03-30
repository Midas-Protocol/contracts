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
  mapping(address => uint256) public votingPowerSpentByAccount;
  mapping(address => uint256) public votesAccumulatedByGauge;
  mapping(address => mapping(address => uint256)) public votesByGaugeByAccount;
  uint256 totalVotes;

  function initialize(address _mdsTokenAddress, IComptroller _comptroller) public initializer {
    comptroller = _comptroller;
    mdsToken = IERC20Upgradeable(_mdsTokenAddress); // TODO typed contract param
  }

  function stake(uint256 amount) public {
    mdsToken.safeTransferFrom(msg.sender, address(this), amount);
    stakingStartedTime[msg.sender] = block.timestamp;
    veMdsToken.mint(msg.sender, amount);
  }

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
    uint vp = veMdsToken.votingPowerOf(msg.sender);

    // TODO verify gauge is registered
    require(votes <= vp - votingPowerSpentByAccount[msg.sender], "not enough voting power for this");

    votingPowerSpentByAccount[msg.sender] += votes;
    votesByGaugeByAccount[gaugeAddress][msg.sender] += votes;
    votesAccumulatedByGauge[gaugeAddress] += votes;
    totalVotes += votes;
  }

  function removeVotesForGauge(address gaugeAddress, uint votes) public {
    // TODO delegation
    uint vp = veMdsToken.votingPowerOf(msg.sender);

    // TODO verify gauge is registered
    require(votes <= votesByGaugeByAccount[gaugeAddress][msg.sender], "user has allocated less votes to this gauge");

    votingPowerSpentByAccount[msg.sender] -= votes;
    votesByGaugeByAccount[gaugeAddress][msg.sender] -= votes;
    votesAccumulatedByGauge[gaugeAddress] -= votes;
    totalVotes -= votes;
  }
}
