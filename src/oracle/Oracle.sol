// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

struct PriceMessage {
    address asset;
    uint256 price;
    uint256 chainId;
    uint256 timestamp;
    bytes signature;
}
contract Oracle is Ownable2Step, Pausable {
    using ECDSA for bytes32;
    mapping(address => ReferenceData) public referenceData;
    mapping(address => bool) public isKeeper;
    uint public constant PRECISION = 1e18;
    uint public requiredSignatures;
    uint public priceDuration = 10 seconds;

    constructor(uint _requiredSignatures) Ownable(msg.sender) {
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
        bytes32 message = keccak256(
            abi.encodePacked(
                address(_priceMessages.asset),
                _priceMessages.price,
                _priceMessages.chainId,
                _priceMessages.timestamp
            )
        );
        bytes memory signature = _priceMessages.signature;
        address signer = ECDSA.recover(message, signature);
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
        uint[] memory sortedPrices = new uint[](_priceOpinions.length);
        for (uint i = 0; i < _priceOpinions.length; i++) {
            sortedPrices[i] = _priceOpinions[i];
        }

        // Sort the array
        for (uint i = 0; i < sortedPrices.length - 1; i++) {
            for (uint j = 0; j < sortedPrices.length - i - 1; j++) {
                if (sortedPrices[j] > sortedPrices[j + 1]) {
                    uint temp = sortedPrices[j];
                    sortedPrices[j] = sortedPrices[j + 1];
                    sortedPrices[j + 1] = temp;
                }
            }
        }

        uint length = sortedPrices.length;
        if (length % 2 == 0) {
            // Even number of elements: average of middle two
            return
                (sortedPrices[length / 2 - 1] + sortedPrices[length / 2]) / 2;
        } else {
            // Odd number of elements: middle element
            return sortedPrices[length / 2];
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
