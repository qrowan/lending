// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract Oracle is Ownable2StepUpgradeable, PausableUpgradeable {
    using ECDSA for bytes32;
    mapping(address => ReferenceData) public referenceData;
    mapping(address => bool) public isKeeper;
    uint public constant PRECISION = 1e18;
    uint public requiredSignatures;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint _requiredSignatures) external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        requiredSignatures = _requiredSignatures;
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
        require(
            isKeeper[msg.sender],
            "Oracle: only keeper can call this function"
        );
        _;
    }

    function setHeartbeat(address _asset, uint _heartbeat) external onlyOwner {
        referenceData[_asset].heartbeat = _heartbeat;
    }

    function priceOf(address _asset) external whenNotPaused view returns (uint256) {
        require(
            block.timestamp - referenceData[_asset].timestamp <=
                referenceData[_asset].heartbeat,
            "Oracle: price not updated"
        );
        return referenceData[_asset].lastData;
    }

    function updatePrice(
        address _asset,
        uint256 _price,
        bytes[] memory _signatures
    ) external whenNotPaused onlyKeeper {
        require(
            _signatures.length >= requiredSignatures,
            "Oracle: not enough signatures"
        );
        bytes32 message = keccak256(abi.encodePacked(address(_asset), _price));
        validateSignatures(message, _signatures);
        referenceData[_asset].lastData = _price;
        referenceData[_asset].timestamp = block.timestamp;
    }

    function validateSignatures(
        bytes32 message,
        bytes[] memory signatures
    ) internal view {
        address[] memory seenSigners = new address[](signatures.length);

        for (uint i = 0; i < signatures.length; i++) {
            address signer = ECDSA.recover(message, signatures[i]);
            require(isKeeper[signer], "Oracle: invalid signer");
            for (uint j = 0; j < i; j++) {
                require(seenSigners[j] != signer, "Oracle: duplicate signer");
            }
            seenSigners[i] = signer;
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
