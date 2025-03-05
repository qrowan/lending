// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vault is ERC4626Upgradeable, Ownable2StepUpgradeable {
    uint constant NUMBER_OF_DEAD_SHARES = 1000;
    address constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _asset) external initializer {
        __ERC4626_init(IERC20(_asset));
        _mint(DEAD_ADDRESS, NUMBER_OF_DEAD_SHARES);
        __ERC20_init(
            string.concat("Vault ", IERC20Metadata(_asset).name()),
            string.concat("VAULT ", IERC20Metadata(_asset).symbol())
            );
        __Ownable2Step_init();
    }
}
