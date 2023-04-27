// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IFlashLoanStrategy.sol";
import "../external/solidly/IRouter.sol";
import "../external/solidly/IPair.sol";

contract SolidlyFlashLoanStrategy is IFlashLoanStrategy {
  IRouter public router; // this cant work with delegatecall

  constructor(IRouter _router) {
    router = _router;
  }

  function flashLoan(
    IERC20Upgradeable assetToBorrow,
    uint256 amountToBorrow,
    IERC20Upgradeable assetToRepay
  ) external {
    bool stable; // TODO - check first for a stable, then for a volatile?
    address pairAddress = router.pairFor(address(assetToBorrow), address(assetToRepay), stable);
    require(pairAddress != address(0), "!pair not found");
    IPair pair = IPair(pairAddress);

    uint256 amount0Out = address(assetToBorrow) == pair.token0() ? amountToBorrow : 0;
    uint256 amount1Out = address(assetToBorrow) == pair.token1() ? amountToBorrow : 0;

    uint256 amountToRepay; // TODO

    pair.swap(amount0Out, amount1Out, address(this), abi.encode(assetToRepay, amountToRepay, pair));
  }

  function hook(
    address,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {
    (IERC20Upgradeable assetToRepay, uint256 amountToRepay, IPair pair) = abi.decode(
      data,
      (IERC20Upgradeable, uint256, IPair)
    );
    //IPair pair = IPair(msg.sender);

    // TODO delegatecall?
    IFlashLoanReceiver(address(this)).receiveFlashLoan(
      IERC20Upgradeable(amount0 > 0 ? pair.token0() : pair.token1()),
      amount0 > 0 ? amount0 : amount1,
      assetToRepay,
      amountToRepay,
      data
    );
  }

  function repayFlashLoan(
    IERC20Upgradeable assetToRepay,
    uint256 amountToRepay,
    bytes calldata data
  ) external {
    (, , address pair) = abi.decode(data, (address, uint256, address));
    assetToRepay.transfer(pair, amountToRepay);
  }
}
