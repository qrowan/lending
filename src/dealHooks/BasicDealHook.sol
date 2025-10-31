// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDealHook} from "../core/dealManager/BaseDealHook.sol";
import {IOracle} from "src/oracle/IOracle.sol";

contract BasicDealHook is BaseDealHook {
    uint256 public constant BASE = 10000; // 100%
    uint256 public constant INITIAL_MARGIN = 4000; // 40%
    uint256 public constant MAINTENANCE_MARGIN = 6000; // 60%
    address public immutable CORE;
    address public immutable ORACLE;
    uint256 public constant MAX_BONUS_RATE = 500; // 5%

    constructor(address _dealHookFactory, string memory __name, address _core, address _oracle)
        BaseDealHook(_dealHookFactory, __name)
    {
        CORE = _core;
        ORACLE = _oracle;
    }

    error OnlyCore();
    error MarginShouldBeDecreased();
    error OnlyUnderInitialMargin();
    error OnlyOverMaintenanceMargin();
    error BonusRateTooHigh();

    modifier onlyCore() {
        _onlyCore();
        _;
    }

    function _onlyCore() internal view {
        if (msg.sender != CORE) revert OnlyCore();
    }

    function onDealCreated(Deal memory dealAfter) external view override onlyCore {
        uint256 marginAfter = getMargin(dealAfter);
        if (marginAfter > INITIAL_MARGIN) revert OnlyUnderInitialMargin();
    }

    function onDealCollateralWithdrawn(Deal memory dealAfter) external view override onlyCore {
        uint256 marginAfter = getMargin(dealAfter);
        if (marginAfter > INITIAL_MARGIN) revert OnlyUnderInitialMargin();
    }

    function onDealRepaid(Deal memory deal) external view override onlyCore {}

    function onDealLiquidated(Deal memory dealBefore, Deal memory dealAfter) external view override onlyCore {
        // Liquidation is only allowed when margin exceeds maintenance threshold
        uint256 marginBefore = getMargin(dealBefore);
        if (marginBefore < MAINTENANCE_MARGIN) revert OnlyOverMaintenanceMargin();

        // Must result in margin reduction
        uint256 marginAfter = getMargin(dealAfter);
        if (marginAfter >= marginBefore) revert MarginShouldBeDecreased();

        // Bonus capped at max rate
        uint256 bonus = getCollateralValue(dealAfter) - getCollateralValue(dealBefore);
        uint256 repaid = getBorrowValue(dealBefore) - getBorrowValue(dealAfter);
        uint256 bonusRate = BASE * (bonus - repaid) / repaid;
        if (bonusRate > MAX_BONUS_RATE) revert BonusRateTooHigh();
    }

    function getCollateralValue(Deal memory deal) internal view returns (uint256) {
        return IOracle(ORACLE).priceOf(deal.collateralToken) * deal.collateralAmount;
    }

    function getBorrowValue(Deal memory deal) internal view returns (uint256) {
        return IOracle(ORACLE).priceOf(deal.borrowToken) * deal.borrowAmount;
    }

    function getMargin(Deal memory deal) internal view returns (uint256) {
        return BASE * getCollateralValue(deal) / getBorrowValue(deal);
    }
}
