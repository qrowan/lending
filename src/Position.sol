// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IVault} from "./Vault.sol";
import {ICore} from "./Core.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract Position is ERC721Upgradeable, Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    uint private _tokenIdCouter;
    address public core;
    constructor() {
        _disableInitializers();
    }

    struct Position {
        EnumerableSet.AddressSet vaults;
    }

    mapping(uint256 => Position) private positions; // tokenId => position
    mapping(uint256 => mapping(address => int)) private balances; // (tokenId, asset) => balance
    mapping(address => uint) public reserves; // asset => reserve

    modifier onlyVault(address _vault) {
        require(ICore(core).isVault(_vault), "Only vault can call this function");
        _;
    }

    modifier onlyOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Only owner can call this function");
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

    function supply(uint256 _tokenId, address _vault) external onlyVault(_vault) {
        int256 amount = int256(IERC20(_vault).balanceOf(address(this)) - reserves[_vault]);
        require(amount > 0, "Amount must be greater than 0");
        Position storage position = positions[_tokenId];
        if (!position.vaults.contains(_vault)) {
            position.vaults.add(_vault);
        }
        updateBalance(getBalance(_tokenId, _vault), amount);
        if (getBalance(_tokenId, _vault) == 0) {
            position.vaults.remove(_vault);
        }
        reserves[_vault] += uint256(int256(reserves[_vault]) + amount);
    }

    function withdraw(uint256 _tokenId, address _vault, uint256 _amount) external onlyVault(_vault) onlyOwnerOf(_tokenId) {
        updateReserve(_vault);
        require(_amount > 0, "Amount must be greater than 0");
        Position storage position = positions[_tokenId];
        updateBalance(getBalance(_tokenId, _vault), int256(_amount) * -1);
        if (getBalance(_tokenId, _vault) == 0) {
            position.vaults.remove(_vault);
        }
        reserves[_vault] -= _amount;
        IERC20(_vault).transfer(msg.sender, _amount);
    }

    function borrow(uint256 _tokenId, address _vault, uint256 _amount) external onlyVault(_vault) onlyOwnerOf(_tokenId) {
        updateReserve(_vault);
        require(_amount > 0, "Amount must be greater than 0");
        IVault(_vault).borrow(_amount, msg.sender);
    }

    function updateBalance(int256 _balance, int256 _amount) internal {
        _balance += _amount;
    }

    function updateReserve(address _vault) public {
        uint256 diff = IERC20(_vault).balanceOf(address(this)) - reserves[_vault];
        IERC20(_vault).transfer(core, diff);
    }

    function getBalance(uint256 _tokenId, address _asset) public view returns (int256) {
        return balances[_tokenId][_asset];
    }
}