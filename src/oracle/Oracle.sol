// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

struct PriceMessage {
    address asset;
    uint256 price;
    uint256 chainId;
    uint256 timestamp;
    bytes signature;
}

contract Oracle is Ownable2Step, Pausable, EIP712 {
    using ECDSA for bytes32;
    using Arrays for uint256[];

    // EIP-712 type hash for PriceMessage
    bytes32 private constant PRICE_MESSAGE_TYPEHASH =
        keccak256("PriceMessage(address asset,uint256 price,uint256 chainId,uint256 timestamp)");

    mapping(address => ReferenceData) public referenceData;
    mapping(address => bool) public isKeeper;
    uint256 public constant PRECISION = 1e18;
    uint256 public requiredSignatures;
    uint256 public priceDuration = 10 seconds;

    error OnlyKeeper();

    constructor(uint256 _requiredSignatures) Ownable(msg.sender) EIP712("RowanFi Oracle", "1") {
        requiredSignatures = _requiredSignatures;
    }

    struct ReferenceData {
        uint256 lastData;
        uint256 timestamp;
        uint256 heartbeat;
    }

    function setKeeper(address _keeper, bool _isKeeper) external onlyOwner {
        isKeeper[_keeper] = _isKeeper;
    }

    modifier onlyKeeper() {
        _onlyKeeper();
        _;
    }

    function _onlyKeeper() internal view {
        if (!isKeeper[msg.sender]) {
            revert OnlyKeeper();
        }
    }

    function setHeartbeat(address _asset, uint256 _heartbeat) external onlyOwner {
        referenceData[_asset].heartbeat = _heartbeat;
    }

    function priceOf(address _asset) external view whenNotPaused returns (uint256) {
        require(
            block.timestamp - referenceData[_asset].timestamp <= referenceData[_asset].heartbeat,
            "Oracle: price not updated"
        );
        return referenceData[_asset].lastData;
    }

    function updatePrice(address _asset, PriceMessage[] memory _priceMessages) external whenNotPaused onlyKeeper {
        require(_priceMessages.length >= requiredSignatures, "Oracle: not enough signatures");
        address[] memory seenSigners = new address[](_priceMessages.length);
        uint256[] memory priceOpinions = new uint256[](_priceMessages.length);
        for (uint256 i = 0; i < _priceMessages.length; i++) {
            seenSigners[i] = validateSignatures(_asset, _priceMessages[i]);
            priceOpinions[i] = _priceMessages[i].price;
        }
        validateSigners(seenSigners);
        uint256 medianPrice = median(priceOpinions);
        referenceData[_asset].lastData = medianPrice;
        referenceData[_asset].timestamp = block.timestamp;
    }

    function validateSignatures(address _asset, PriceMessage memory _priceMessages) internal view returns (address) {
        // Create EIP-712 structured hash
        bytes32 typeHash = PRICE_MESSAGE_TYPEHASH;
        bytes32 structHash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), mload(add(_priceMessages, 0x00))) // asset
            mstore(add(ptr, 0x40), mload(add(_priceMessages, 0x20))) // price
            mstore(add(ptr, 0x60), mload(add(_priceMessages, 0x40))) // chainId
            mstore(add(ptr, 0x80), mload(add(_priceMessages, 0x60))) // timestamp
            structHash := keccak256(ptr, 0xa0)
        }

        // Create EIP-712 typed data hash
        bytes32 digest = _hashTypedDataV4(structHash);

        bytes memory signature = _priceMessages.signature;
        address signer = ECDSA.recover(digest, signature);

        require(isKeeper[signer], "Oracle: invalid signer");
        require(block.chainid == _priceMessages.chainId, "Oracle: invalid chain id");
        require(_priceMessages.asset == _asset, "Oracle: wrong asset");
        require(block.timestamp - _priceMessages.timestamp <= priceDuration, "Oracle: invalid timestamp");
        return signer;
    }

    /// @notice Returns the EIP-712 hash for a PriceMessage (for off-chain signing)
    function getPriceMessageHash(address asset, uint256 price, uint256 chainId, uint256 _timestamp)
        external
        view
        returns (bytes32)
    {
        bytes32 typeHash = PRICE_MESSAGE_TYPEHASH;
        bytes32 structHash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), asset)
            mstore(add(ptr, 0x40), price)
            mstore(add(ptr, 0x60), chainId)
            mstore(add(ptr, 0x80), _timestamp)
            structHash := keccak256(ptr, 0xa0)
        }
        return _hashTypedDataV4(structHash);
    }

    function validateSigners(address[] memory _seenSigners) internal pure {
        // no duplicates
        for (uint256 i = 0; i < _seenSigners.length; i++) {
            for (uint256 j = i + 1; j < _seenSigners.length; j++) {
                require(_seenSigners[i] != _seenSigners[j], "Oracle: duplicate signer");
            }
        }
    }

    function median(uint256[] memory _priceOpinions) internal pure returns (uint256) {
        Arrays.sort(_priceOpinions);
        uint256 length = _priceOpinions.length;
        return
            length % 2 == 0
                ? (_priceOpinions[length / 2 - 1] + _priceOpinions[length / 2]) / 2
                : _priceOpinions[length / 2];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
