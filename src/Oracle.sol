// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
contract Oracle is Ownable2StepUpgradeable, PausableUpgradeable {
    mapping(address => ReferenceData) public referenceData;
    mapping(address => bool) public isKeeper;
    uint public constant PRECISION = 1e18;
    
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
    }

    struct ReferenceData {
        uint lastData;
        uint timestamp;
        uint heartbeat;
    }

    function setKeeper(address _keeper, bool _isKeeper) external onlyOwner {
        isKeeper[_keeper] = _isKeeper;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Oracle: only keeper can call this function");
        _;
    }

    function setHeartbeat(address _asset, uint _heartbeat) external onlyOwner {
        referenceData[_asset].heartbeat = _heartbeat;
    }


    function priceOf(address _asset) external view returns (uint256) {
        require(block.timestamp - referenceData[_asset].timestamp <= referenceData[_asset].heartbeat, "Oracle: price not updated");
        return referenceData[_asset].lastData;
    }

    function updatePrice(address _asset, uint256 _price) external onlyKeeper {
        referenceData[_asset].lastData = _price;
        referenceData[_asset].timestamp = block.timestamp;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

}
