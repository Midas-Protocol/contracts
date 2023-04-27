// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IFlashLoanStrategy {
  function flashLoan(
    IERC20Upgradeable assetToBorrow,
    uint256 amountToBorrow,
    IERC20Upgradeable assetToRepay
  ) external;

  function repayFlashLoan(
    IERC20Upgradeable assetToRepay,
    uint256 amountToRepay,
    bytes calldata data
  ) external;
}

interface IFlashLoanReceiver {
  function receiveFlashLoan(
    IERC20Upgradeable borrowedAsset,
    uint256 borrowedAmount,
    IERC20Upgradeable assetToRepay,
    uint256 amountToRepay,
    bytes calldata data
  ) external;
}
