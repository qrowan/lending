// SPDX-License-address constant Identifier = UNLICENSE;
pragma solidity ^0.8.3;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestUtils is Test {
    uint256 internal _setupSnapshotId;

    function _charge(address token, address _user, uint256 amount) internal {
        if (token == address(0)) {
            deal(_user, amount);
        } else {
            deal(token, _user, amount);
        }
    }

    function _timeElapse(uint256 timeDelta) internal {
        vm.warp(block.timestamp + timeDelta);
        vm.roll(block.number + timeDelta);
    }

    function reset() internal {
        vm.revertTo(_setupSnapshotId);
        // revertTo "deletes the given snapshot, as well as any snapshots taken after"
        _setupSnapshotId = vm.snapshot();
    }

    function fromUnit(uint256 amount, uint256 unit, uint256 digit) internal pure returns (string memory result) {
        if (amount - amount / (10 ** (unit - digit)) * (10 ** (unit - digit)) >= (10 ** (unit - digit) / 2)) {
            amount += (10 ** (unit - digit) / 2);
        }
        string memory amountToString = Strings.toString(amount);
        uint256 length = bytes(amountToString).length;
        if (length > unit) {
            string memory integer = _substring(amountToString, 0, length - unit);
            string memory float = _substring(amountToString, length - unit, length - unit + digit);
            result = string(abi.encodePacked(integer, ".", float));
        } else {
            string memory integer = "0";
            string memory float = "";
            for (uint256 i; i < unit - length; i++) {
                float = string(abi.encodePacked(float, "0"));
            }
            float = string(abi.encodePacked(float, amountToString));
            float = _substring(float, 0, digit);
            result = string(abi.encodePacked(integer, ".", float));
        }
    }

    function fromUnit(uint256 amount) internal pure returns (string memory result) {
        if (amount - amount / (10 ** 14) * (10 ** 14) >= (10 ** 14 / 2)) {
            amount += (10 ** 14 / 2);
        }
        string memory amountToString = Strings.toString(amount);
        uint256 length = bytes(amountToString).length;
        if (length > 18) {
            string memory integer = _substring(amountToString, 0, length - 18);
            string memory float = _substring(amountToString, length - 18, length - 18 + 4);
            result = string(abi.encodePacked(integer, ".", float));
        } else {
            string memory integer = "0";
            string memory float = "";
            for (uint256 i; i < 18 - length; i++) {
                float = string(abi.encodePacked(float, "0"));
            }
            float = string(abi.encodePacked(float, amountToString));
            float = _substring(float, 0, 4);
            result = string(abi.encodePacked(integer, ".", float));
        }
    }

    function _substring(string memory str, uint256 startIndex, uint256 endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function balance(address account, address token) internal view returns (uint256) {
        if (token == address(0)) {
            return address(account).balance;
        } else {
            return IERC20Metadata(token).balanceOf(account);
        }
    }

    function decimals(address token) internal view returns (uint256) {
        uint256 decimal = token == address(0) ? 18 : IERC20Metadata(token).decimals();
        return decimal;
    }

    function symbol(address token) internal view returns (string memory) {
        string memory _symbol = token == address(0) ? "KLAY" : IERC20Metadata(token).symbol();
        return _symbol;
    }

    function _makeProxy(ProxyAdmin _proxyAdmin, address _implementation, bytes memory _data)
        internal
        returns (address payable)
    {
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(_implementation), address(_proxyAdmin), _data);

        return payable(address(proxy));
    }

    function _upgradeProxy(ProxyAdmin _proxyAdmin, address proxy, address _implementation) internal {
        ProxyAdmin(_proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), _implementation, new bytes(0));
    }

    function isLeapYear(uint16 year) private pure returns (bool) {
        if (year % 4 == 0) {
            if (year % 100 == 0) {
                return year % 400 == 0;
            } else {
                return true;
            }
        }
        return false;
    }

    function getDaysInMonth(uint8 month, uint16 year) private pure returns (uint8) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (month == 2) {
            return isLeapYear(year) ? 29 : 28;
        }
        revert("Invalid month");
    }

    function uintToString(uint256 num) public pure returns (string memory) {
        return Strings.toString(num);
    }

    // @dev Get timestamp from year, month, day, hour
    // @param year Year
    // @param month Month
    // @param day Day
    // @param hour Hour
    // @return Timestamp
    function getTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) public pure returns (uint40) {
        require(year >= 1970, "Year must be after 1970");
        require(month >= 1 && month <= 12, "Invalid month");
        require(day >= 1 && day <= getDaysInMonth(month, year), "Invalid day");
        require(hour < 24, "Invalid hour");

        uint16 totalDays;
        for (uint16 i = 1970; i < year; i++) {
            totalDays += isLeapYear(i) ? 366 : 365;
        }

        for (uint8 i = 1; i < month; i++) {
            totalDays += getDaysInMonth(i, year);
        }
        totalDays += day - 1;

        return uint40(totalDays) * 24 * 60 * 60 + hour * 3600;
    }

    function getDate(uint40 _timestamp) public pure returns (uint16 year, uint8 month, uint8 day, uint8 hour) {
        year = 1970;
        uint256 timestamp = uint256(_timestamp);

        while (timestamp >= (isLeapYear(year) ? LEAP_YEAR_SECONDS : SECONDS_PER_YEAR)) {
            timestamp -= isLeapYear(year) ? LEAP_YEAR_SECONDS : SECONDS_PER_YEAR;
            year++;
        }

        for (month = 1; month <= 12; month++) {
            uint256 daysInMonth = getDaysInMonth(month, year) * SECONDS_PER_DAY;
            if (timestamp < daysInMonth) {
                break;
            }
            timestamp -= daysInMonth;
        }

        day = uint8(timestamp / SECONDS_PER_DAY) + 1;
        timestamp %= SECONDS_PER_DAY;
        hour = uint8(timestamp / SECONDS_PER_HOUR);
    }

    function roundDown(uint256 num, uint256 precision) public pure returns (uint256) {
        return num / precision * precision;
    }

    uint256 constant SECONDS_PER_HOUR = 60 * 60;
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 constant SECONDS_PER_YEAR = 365 * SECONDS_PER_DAY;
    uint256 constant LEAP_YEAR_SECONDS = 366 * SECONDS_PER_DAY;
}
