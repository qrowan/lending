// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {SignedMath} from "openzeppelin-contracts/contracts/utils/math/SignedMath.sol";
import {IVault} from "./Vault.sol";
import {ICore} from "./Core.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract Position is ERC721Upgradeable, Ownable2StepUpgradeable {
    using SignedMath for int256;
    using EnumerableSet for EnumerableSet.AddressSet;
    uint private _tokenIdCouter;
    address public core;
    constructor() {
        _disableInitializers();
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
            ICore(core).isVault(_vToken),
            "Only vault can call this function"
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

    function initialize(address _core) external initializer {
        __ERC721_init("Position", "POSITION");
        __Ownable_init(msg.sender);
        core = _core;
    }

    function mint(address _to) external returns (uint256) {
        uint256 tokenId = _tokenIdCouter++;
        _mint(_to, tokenId);
        return tokenId;
    }

    function supply(
        uint256 _tokenId,
        address _vToken
    )
        external
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
    )
        external
        onlyVault(_vToken)
        onlyOwnerOf(_tokenId)
        balanceCheck(_tokenId, _vToken, BalanceType.CREDIT)
    {
        claim(_vToken);
        require(_amount > 0, "Amount must be greater than 0");
        _updateBalance(_tokenId, _vToken, int256(_amount) * -1);
        _updateReserve(_vToken, int256(_amount) * -1);
        IERC20(_vToken).transfer(msg.sender, _amount);
    }

    function borrow(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    )
        external
        onlyVault(_vToken)
        onlyOwnerOf(_tokenId)
        balanceCheck(_tokenId, _vToken, BalanceType.NO_CREDIT)
    {
        claim(_vToken);
        require(_amount > 0, "Amount must be greater than 0");
        _addAsset(_tokenId, _vToken);
        _updateBalance(_tokenId, _vToken, int256(_amount) * -1);
        IVault(_vToken).borrow(_amount, msg.sender);
    }

    function repay(
        uint256 _tokenId,
        address _vToken,
        uint256 _amount
    )
        external
        onlyVault(_vToken)
        onlyOwnerOf(_tokenId)
        balanceCheck(_tokenId, _vToken, BalanceType.DEBT)
    {
        require(_amount > 0, "Amount must be greater than 0");
        _updateBalance(_tokenId, _vToken, int256(_amount));
        IERC20(_vToken).transferFrom(msg.sender, address(this), _amount);
        // IVault(_vToken).repay(_amount);
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

    function claim(address _vToken) public {
        uint256 diff = IERC20(_vToken).balanceOf(address(this)) -
            reserves[_vToken];
        IERC20(_vToken).transfer(msg.sender, diff);
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
}
