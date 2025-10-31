// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InterestRate} from "@constants/InterestRate.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultGovernor} from "src/deprecated/v1/governance/VaultGovernor.sol";

interface IVault {
    function borrow(uint256 _borrowAmount, address _receiver) external;
    function repay(uint256 _repayAmount) external;
    function asset() external view returns (address);
}

contract Vault is ERC4626, ERC20Votes, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant NUMBER_OF_DEAD_SHARES = 1000;
    address constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
    uint256 public interestRatePerSecond = InterestRate.INTEREST_RATE_15;
    uint256 public lentAmountStored;
    uint256 public lastUpdated;
    address public config;
    mapping(address => bool) public isWhitelisted;
    address public governor;

    constructor(address _asset, address _config)
        Ownable(msg.sender)
        ERC4626(IERC20(_asset))
        ERC20(
            string.concat("Vault ", IERC20Metadata(_asset).name()), string.concat("v", IERC20Metadata(_asset).symbol())
        )
        EIP712(string.concat("Vault-", Strings.toHexString(_asset)), "1")
    {
        config = _config;
        _mint(DEAD_ADDRESS, NUMBER_OF_DEAD_SHARES);
        governor = address(new VaultGovernor(address(this)));
    }

    modifier onlyGovernanceOrOwner() {
        _onlyGovernanceOrOwner();
        _;
    }

    function _onlyGovernanceOrOwner() internal view {
        if (totalSupply() == NUMBER_OF_DEAD_SHARES) {
            require(msg.sender == owner(), "Only owner can call this function");
        } else {
            require(msg.sender == governor, "Only governance can call this function");
        }
    }

    function setWhitelisted(address _contract, bool _isWhitelisted) external onlyGovernanceOrOwner {
        isWhitelisted[_contract] = _isWhitelisted;
    }

    function setInterestRate(uint256 _interestRatePerSecond) external onlyGovernanceOrOwner {
        // TODO: should be delayed. or restricted with some conditions.
        lentAmountStored = lentAssets();
        lastUpdated = block.timestamp;
        interestRatePerSecond = _interestRatePerSecond;
    }

    modifier onlyWhitelisted(address _contract) {
        _onlyWhitelisted(_contract);
        _;
    }

    function _onlyWhitelisted(address _contract) internal view {
        require(isWhitelisted[_contract], "Only whitelisted contract can call this function");
    }

    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + lentAssets();
    }

    function lentAssets() public view returns (uint256) {
        uint256 duration = block.timestamp - lastUpdated;
        return InterestRate.calculatePrincipalPlusInterest(lentAmountStored, interestRatePerSecond, duration);
    }

    function _updateLentAmount(uint256 _amount, bool _add) private {
        uint256 _lentAssets = lentAssets();
        lentAmountStored = _add ? _lentAssets + _amount : _lentAssets - _amount;
        lastUpdated = block.timestamp;
    }

    function borrow(uint256 _borrowAmount, address _receiver) public nonReentrant onlyWhitelisted(msg.sender) {
        IERC20(asset()).safeTransfer(_receiver, _borrowAmount);
        _updateLentAmount(_borrowAmount, true);
    }

    function repay(uint256 _repayAmount) public nonReentrant onlyWhitelisted(msg.sender) {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), _repayAmount);
        _updateLentAmount(_repayAmount, false);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.number);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function decimals() public view override(ERC20, ERC4626) returns (uint8) {
        return super.decimals();
    }
}
