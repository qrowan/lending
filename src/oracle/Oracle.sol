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
    using Arrays for uint[];

    // EIP-712 type hash for PriceMessage
    bytes32 private constant PRICE_MESSAGE_TYPEHASH =
        keccak256(
            "PriceMessage(address asset,uint256 price,uint256 chainId,uint256 timestamp)"
        );

    mapping(address => ReferenceData) public referenceData;
    mapping(address => bool) public isKeeper;
    uint public constant PRECISION = 1e18;
    uint public requiredSignatures;
    uint public priceDuration = 10 seconds;

    constructor(
        uint _requiredSignatures
    ) Ownable(msg.sender) EIP712("RowanFi Oracle", "1") {
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

    function priceOf(
        address _asset
    ) external view whenNotPaused returns (uint256) {
        require(
            block.timestamp - referenceData[_asset].timestamp <=
                referenceData[_asset].heartbeat,
            "Oracle: price not updated"
        );
        return referenceData[_asset].lastData;
    }

    function updatePrice(
        address _asset,
        PriceMessage[] memory _priceMessages
    ) external whenNotPaused onlyKeeper {
        require(
            _priceMessages.length >= requiredSignatures,
            "Oracle: not enough signatures"
        );
        address[] memory seenSigners = new address[](_priceMessages.length);
        uint[] memory priceOpinions = new uint[](_priceMessages.length);
        for (uint i = 0; i < _priceMessages.length; i++) {
            seenSigners[i] = validateSignatures(_asset, _priceMessages[i]);
            priceOpinions[i] = _priceMessages[i].price;
        }
        validateSigners(seenSigners);
        uint medianPrice = median(priceOpinions);
        referenceData[_asset].lastData = medianPrice;
        referenceData[_asset].timestamp = block.timestamp;
    }

    function validateSignatures(
        address _asset,
        PriceMessage memory _priceMessages
    ) internal view returns (address) {
        // Create EIP-712 structured hash
        bytes32 structHash = keccak256(
            abi.encode(
                PRICE_MESSAGE_TYPEHASH,
                _priceMessages.asset,
                _priceMessages.price,
                _priceMessages.chainId,
                _priceMessages.timestamp
            )
        );

        // Create EIP-712 typed data hash
        bytes32 digest = _hashTypedDataV4(structHash);

        bytes memory signature = _priceMessages.signature;
        address signer = ECDSA.recover(digest, signature);

        require(isKeeper[signer], "Oracle: invalid signer");
        require(
            block.chainid == _priceMessages.chainId,
            "Oracle: invalid chain id"
        );
        require(_priceMessages.asset == _asset, "Oracle: wrong asset");
        require(
            block.timestamp - _priceMessages.timestamp <= priceDuration,
            "Oracle: invalid timestamp"
        );
        return signer;
    }

    /// @notice Returns the EIP-712 hash for a PriceMessage (for off-chain signing)
    function getPriceMessageHash(
        address asset,
        uint256 price,
        uint256 chainId,
        uint256 timestamp
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(PRICE_MESSAGE_TYPEHASH, asset, price, chainId, timestamp)
        );
        return _hashTypedDataV4(structHash);
    }

    function validateSigners(address[] memory _seenSigners) internal pure {
        // no duplicates
        for (uint i = 0; i < _seenSigners.length; i++) {
            for (uint j = i + 1; j < _seenSigners.length; j++) {
                require(
                    _seenSigners[i] != _seenSigners[j],
                    "Oracle: duplicate signer"
                );
            }
        }
    }

    function median(uint[] memory _priceOpinions) internal pure returns (uint) {
        Arrays.sort(_priceOpinions);
        uint length = _priceOpinions.length;
        return
            length % 2 == 0
                ? (_priceOpinions[length / 2 - 1] +
                    _priceOpinions[length / 2]) / 2
                : _priceOpinions[length / 2];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
