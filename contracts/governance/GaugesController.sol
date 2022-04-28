// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../external/compound/IComptroller.sol";
import "../external/compound/ICToken.sol";

import "solmate/tokens/ERC20.sol";
import "./VeMDSToken.sol";

contract GaugesController {
    VeMDSToken public veToken;
    address public dao;
    mapping(ERC20 => ICToken) gaugedAssetByStrategy;
    mapping(ERC20 => IComptroller) gaugedPoolByStrategy;

    constructor(VeMDSToken _veToken, address _dao) {
        veToken = _veToken;
        dao = _dao;
    }

    // TODO ability for the DAO address to be changed by the DAO

    modifier onlyDao() {
        require(msg.sender == dao, "only the DAO can call this method");
        _;
    }

    // method that only the DAO can call to add (whitelist) a pool for a gauge
    function addPoolGauge(IComptroller comptrollerToAdd) public onlyDao {
        // create LPToken , if not yet created
        // add to the gaugedPoolByStrategy mapping
//        veToken.addGauge(supplyLpToken);
        // better var name than borrowLpToken
//        veToken.addGauge(borrowLpToken);
    }

    // TODO adding the underlying requires an updating list of all comptrollers/pools where it is listed
    // method that only the DAO can call to add (whitelist) an asset for a gauge
    function addAssetGauge(ICToken cToken) public onlyDao {
        // TODO asset LP token as lens for the CToken?
        // add to the gaugedAssetByStrategy mapping
//        veToken.addGauge(supplyLpToken);
        // better var name than borrowLpToken
//        veToken.addGauge(borrowLpToken);
    }
}