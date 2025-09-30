// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {SignedMath} from "lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol";
import {IVault} from "../core/Vault.sol";
import {IConfig} from "../core/Config.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPosition} from "./IPosition.sol";

interface IOracle {
    function priceOf(address _asset) external view returns (uint256);
}

struct RepayData {
    address vToken;
    uint256 amount;
}

struct RewardData {
    address vToken;
    uint256 amount;
}

struct LiquidateData {
    RepayData[] repayData;
    RewardData[] rewardData;
    address payer;
    address receiver;
}

contract MultiAssetPosition is
    IPosition,
    ERC721,
    Ownable2Step,
    ReentrancyGuard
{
    using SignedMath for int256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    uint private _tokenIdCounter;
    address public config;
    address public oracle;
    uint public constant INITIALIZATION_THRESHOLD = 20000;
    uint public constant LIQUIDATION_THRESHOLD = 15000;
    address public liquidator;
    constructor(
        address _config,
        address _oracle
    ) Ownable(msg.sender) ERC721("Position", "POSITION") {
        config = _config;
        oracle = _oracle;
        liquidator = IConfig(config).getLiquidator();
    }

    error HasDebt();
    error HasCredit();
    error NoDebt();
    error NoCredit();

    enum BalanceType {
        NO_DEBT,
        NO_CREDIT,
        DEBT,
        CREDIT
    }

    struct Position {
        EnumerableSet.AddressSet vaults;
    }

    mapping(uint256 => Position) private positions; // tokenId => position
    mapping(uint256 => mapping(address => int256)) private balances; // (tokenId, vToken) => balance
    mapping(address => uint) public reserves; // vToken => reserve

    modifier onlyVault(address _vToken) {
        require(
            IConfig(config).isVault(_vToken),
            "Only vault can call this function"
        );
        _;
    }

    modifier onlyLiquidator() {
        require(
            msg.sender == IConfig(config).getLiquidator(),
            "Only liquidator can call this function"
        );
        _;
    }

    modifier onlyOwnerOf(uint256 _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender,
            "Only owner can call this function"
        );
        _;
    }

    modifier balanceCheck(
        uint256 _tokenId,
        address _vToken,
        BalanceType _balanceType
    ) {
        int256 balance = balances[_tokenId][_vToken];

        if (_balanceType == BalanceType.NO_DEBT && balance < 0)
            revert HasDebt();
        if (_balanceType == BalanceType.NO_CREDIT && balance > 0)
            revert HasCredit();
        if (_balanceType == BalanceType.DEBT && balance >= 0) revert NoDebt();
        if (_balanceType == BalanceType.CREDIT && balance <= 0)
            revert NoCredit();
        _;
    }

    function mint(address _to) external nonReentrant returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(_to, tokenId);
        return tokenId;
    }

    function supply(
        uint256 _tokenId,
        address _vToken
    )
        external
        nonReentrant
        onlyVault(_vToken)
        balanceCheck(_tokenId, _vToken, BalanceType.NO_DEBT)
    {
        int256 amount = int256(
            IERC20(_vToken).balanceOf(address(this)) - reserves[_vToken]
        );
        require(amount > 0, "Amount must be greater than 0");
        _addAsset(_tokenId, _vToken);
        _updateBalance(_tokenId, _vToken, amount);
        _updateReserve(_vToken, amount);
    }

    function withdraw(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    ) external nonReentrant onlyOwnerOf(_tokenId) {
        _withdraw(_tokenId, _vToken, _amount);
    }

    function _withdraw(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    )
        private
        onlyVault(_vToken)
        balanceCheck(_tokenId, _vToken, BalanceType.CREDIT)
    {
        _claim(_vToken);
        require(_amount > 0, "Amount must be greater than 0");
        _updateBalance(_tokenId, _vToken, int256(_amount) * -1);
        _updateReserve(_vToken, int256(_amount) * -1);
        IERC20(_vToken).safeTransfer(msg.sender, _amount);

        require(isInitializable(_tokenId), "Position is not initializable");
    }

    function borrow(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    )
        external
        nonReentrant
        onlyVault(_vToken)
        onlyOwnerOf(_tokenId)
        balanceCheck(_tokenId, _vToken, BalanceType.NO_CREDIT)
    {
        _claim(_vToken);
        require(_amount > 0, "Amount must be greater than 0");
        _addAsset(_tokenId, _vToken);
        _updateBalance(_tokenId, _vToken, int256(_amount) * -1);
        IVault(_vToken).borrow(_amount, msg.sender);

        require(isInitializable(_tokenId), "Position is not initializable");
    }

    function repay(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    ) external nonReentrant onlyOwnerOf(_tokenId) {
        require(_amount > 0, "Amount must be greater than 0");
        _claim(_vToken);
        _repay(_tokenId, _vToken, _amount, msg.sender);
    }

    function _repay(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount,
        address _payer
    )
        private
        onlyVault(_vToken)
        balanceCheck(_tokenId, _vToken, BalanceType.DEBT)
    {
        _updateBalance(_tokenId, _vToken, int256(_amount));
        address asset = IVault(_vToken).asset();
        IERC20(asset).safeTransferFrom(_payer, address(this), _amount);
        IERC20(asset).approve(address(IVault(_vToken)), _amount);
        IVault(_vToken).repay(_amount);
    }

    function _updateBalance(
        uint256 _tokenId,
        address _vToken,
        int256 _amount
    ) private {
        balances[_tokenId][_vToken] += _amount;
    }

    function _addAsset(uint256 _tokenId, address _vToken) private {
        Position storage position = positions[_tokenId];
        if (!position.vaults.contains(_vToken)) {
            position.vaults.add(_vToken);
        }
    }

    function _updateReserve(address _vToken, int256 _amount) private {
        reserves[_vToken] = uint256(int256(reserves[_vToken]) + _amount);
    }

    function claim(address _vToken) public nonReentrant {
        _claim(_vToken);
    }

    function _claim(address _vToken) private {
        uint256 diff = IERC20(_vToken).balanceOf(address(this)) -
            reserves[_vToken];
        IERC20(_vToken).safeTransfer(msg.sender, diff);
    }

    function getBalance(
        uint256 _tokenId,
        address _vToken
    ) public view returns (int256) {
        return balances[_tokenId][_vToken];
    }

    function getPosition(
        uint256 _tokenId
    ) public view returns (address[] memory _vTokens, int[] memory _balances) {
        _vTokens = new address[](positions[_tokenId].vaults.length());
        _balances = new int[](positions[_tokenId].vaults.length());
        for (uint256 i = 0; i < positions[_tokenId].vaults.length(); i++) {
            _vTokens[i] = positions[_tokenId].vaults.at(i);
            _balances[i] = balances[_tokenId][_vTokens[i]];
        }
        return (_vTokens, _balances);
    }

    function health(
        uint256 _tokenId
    ) public view returns (uint256 collateral, uint256 debt) {
        address[] memory _vTokens = positions[_tokenId].vaults.values();
        for (uint256 i = 0; i < _vTokens.length; i++) {
            uint absBalance = balances[_tokenId][_vTokens[i]].abs();
            address asset = IVault(_vTokens[i]).asset();
            collateral += absBalance * IOracle(oracle).priceOf(asset);
            if (balances[_tokenId][_vTokens[i]] < 0) {
                debt += absBalance * IOracle(oracle).priceOf(asset);
            }
        }
        return (collateral, debt);
    }

    function isInitializable(uint256 _tokenId) public view returns (bool) {
        (uint256 collateral, uint256 debt) = health(_tokenId);
        return collateral > (debt * INITIALIZATION_THRESHOLD) / 10000;
    }

    function isLiquidatable(uint256 _tokenId) public view returns (bool) {
        (uint256 collateral, uint256 debt) = health(_tokenId);
        return collateral < (debt * LIQUIDATION_THRESHOLD) / 10000;
    }

    function liquidate(
        uint256 _tokenId,
        bytes memory _data
    ) external onlyLiquidator {
        require(isLiquidatable(_tokenId), "Position is not liquidatable");
        LiquidateData memory liquidateData = abi.decode(_data, (LiquidateData));
        (uint256 collateralBefore, uint256 debtBefore) = health(_tokenId);

        uint repaidValue = 0;
        uint rewardValue = 0;
        for (uint256 i = 0; i < liquidateData.repayData.length; i++) {
            _repay(
                _tokenId,
                liquidateData.repayData[i].vToken,
                liquidateData.repayData[i].amount,
                liquidateData.payer
            );
            repaidValue +=
                liquidateData.repayData[i].amount *
                IOracle(oracle).priceOf(
                    IVault(liquidateData.repayData[i].vToken).asset()
                );
        }
        for (uint256 i = 0; i < liquidateData.rewardData.length; i++) {
            _withdraw(
                _tokenId,
                liquidateData.rewardData[i].vToken,
                liquidateData.rewardData[i].amount
            );
            rewardValue +=
                liquidateData.rewardData[i].amount *
                IOracle(oracle).priceOf(
                    IVault(liquidateData.rewardData[i].vToken).asset()
                );
        }
        (uint256 collateralAfter, uint256 debtAfter) = health(_tokenId);
        require(
            debtAfter * collateralBefore < debtBefore * collateralAfter,
            "Health decreased"
        );
        require(rewardValue < repaidValue * 2, "Too much reward");
        return;
    }
}
