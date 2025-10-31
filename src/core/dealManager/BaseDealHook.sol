// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IDealHook} from "../../interfaces/IAggregatedInterfaces.sol";

abstract contract BaseDealHook is IDealHook {
    address public immutable DEAL_HOOK_FACTORY;
    string private _name;

    constructor(address _dealHookFactory, string memory __name) {
        DEAL_HOOK_FACTORY = _dealHookFactory;
        _name = __name;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function onDealCreated(Deal memory dealAfter) external virtual {}

    function onDealCollateralWithdrawn(Deal memory dealAfter) external virtual {}

    function onDealRepaid(Deal memory deal) external virtual {}

    function onDealLiquidated(Deal memory dealBefore, Deal memory dealAfter) external virtual {}
}
