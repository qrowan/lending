// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {InterestRate} from "../constants/InterestRate.sol";
import {IConfig} from "./Config.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVault {
    function borrow(uint256 _borrowAmount, address _receiver) external;
    function repay(uint256 _repayAmount) external;
    function asset() external view returns (address);
}

contract Vault is ERC4626, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint constant NUMBER_OF_DEAD_SHARES = 1000;
    address constant DEAD_ADDRESS =
        address(0x000000000000000000000000000000000000dEaD);
    uint public constant interestRatePerSecond = InterestRate.INTEREST_RATE_15; // TODO: governance ?
    uint public lentAmountStored; // TODO: private
    uint public lastUpdated; // TODO: private
    address public config;
    mapping(address => bool) public isWhitelisted;

    constructor(
        address _asset,
        address _config
    )
        Ownable(msg.sender)
        ERC4626(IERC20(_asset))
        ERC20(
            string.concat("Vault ", IERC20Metadata(_asset).name()),
            string.concat("v", IERC20Metadata(_asset).symbol())
        )
    {
        config = _config;
        _mint(DEAD_ADDRESS, NUMBER_OF_DEAD_SHARES);
    }

    function setWhitelisted(
        address _contract,
        bool _isWhitelisted
    ) external onlyOwner {
        isWhitelisted[_contract] = _isWhitelisted;
    }

    modifier onlyWhitelisted(address _contract) {
        require(
            isWhitelisted[_contract],
            "Only whitelisted contract can call this function"
        );
        _;
    }

    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + lentAssets();
    }

    function lentAssets() public view returns (uint256) {
        uint duration = block.timestamp - lastUpdated;
        return
            InterestRate.calculatePrincipalPlusInterest(
                lentAmountStored,
                interestRatePerSecond,
                duration
            );
    }

    function _updateLentAmount(uint256 _amount, bool _add) private {
        lentAmountStored = _add
            ? lentAmountStored + _amount
            : lentAmountStored - _amount;
        lastUpdated = block.timestamp;
    }

    function borrow(
        uint256 _borrowAmount,
        address _receiver
    ) public nonReentrant onlyWhitelisted(msg.sender) {
        IERC20(asset()).safeTransfer(_receiver, _borrowAmount);
        _updateLentAmount(_borrowAmount, true);
    }

    function repay(
        uint256 _repayAmount
    ) public nonReentrant onlyWhitelisted(msg.sender) {
        IERC20(asset()).safeTransferFrom(
            msg.sender,
            address(this),
            _repayAmount
        );
        _updateLentAmount(_repayAmount, false);
    }
}
