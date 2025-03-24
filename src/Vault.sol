// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IntrestRate} from "./constants/IntrestRate.sol";
import {ICore} from "./Core.sol";

interface IVault {
    function borrow(uint256 _borrowAmount, address _receiver) external;
}

contract Vault is ERC4626Upgradeable, Ownable2StepUpgradeable {
    uint constant NUMBER_OF_DEAD_SHARES = 1000;
    address constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint public constant interestRatePerSecond = IntrestRate.INTEREST_RATE_15;
    uint public lentAmountStored; // TODO: private
    uint public lastUpdated; // TODO: private
    address public core;
    constructor() {
        _disableInitializers();
    }

    function initialize(address _asset, address _core) external initializer {
        __ERC4626_init(IERC20(_asset));
        _mint(DEAD_ADDRESS, NUMBER_OF_DEAD_SHARES);
        __ERC20_init(
            string.concat("Vault ", IERC20Metadata(_asset).name()),
            string.concat("VAULT ", IERC20Metadata(_asset).symbol())
            );
        __Ownable_init(msg.sender);
        core = _core;
    }

    modifier onlyPosition(address _position) {
        require(ICore(core).isPosition(_position), "Only position can call this function");
        _;
    }

    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + lentAssets();
    }

    function lentAssets() public view returns (uint256) {
        uint duration = block.timestamp - lastUpdated;
        return IntrestRate.calculatePrincipalPlusInterest(lentAmountStored, interestRatePerSecond, duration);
    }

    function updateLentAmount(uint256 _amount, bool _add) private {
        lentAmountStored = _add ? lentAmountStored + _amount : lentAmountStored - _amount;
        lastUpdated = block.timestamp;
    }

    function borrow(uint256 _borrowAmount, address _receiver) public onlyPosition(msg.sender) {
        IERC20(asset()).transfer(_receiver, _borrowAmount);
        updateLentAmount(_borrowAmount, true);
    }
}
