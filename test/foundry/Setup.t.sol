// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "@core/Vault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {InterestRate} from "@constants/InterestRate.sol";
import {TestUtils} from "./TestUtils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Config} from "@core/Config.sol";
import {MultiAssetPosition} from "@position/MultiAssetPosition.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Oracle, PriceMessage} from "@oracle/Oracle.sol";
import {Liquidator} from "@core/Liquidator.sol";

contract ERC20Customized is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

contract Setup is TestUtils {
    Config public config;
    MultiAssetPosition public multiAssetPosition;
    Vault[] public vaults;
    ERC20Customized[] public assets;
    Oracle public oracle;
    Liquidator public liquidator;
    address public user;
    address public user1;
    address public user2;
    address public deployer;
    address public keeper1;
    address public keeper2;
    address public keeper3;
    address public keeper4;
    uint256 public keeper1Key;
    uint256 public keeper2Key;
    uint256 public keeper3Key;
    uint256 public keeper4Key;

    function setUp() public virtual {
        (deployer,) = makeAddrAndKey("deployer");
        (keeper1, keeper1Key) = makeAddrAndKey("keeper1");
        (keeper2, keeper2Key) = makeAddrAndKey("keeper2");
        (keeper3, keeper3Key) = makeAddrAndKey("keeper3");
        (keeper4, keeper4Key) = makeAddrAndKey("keeper4");
        vm.startPrank(deployer);
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        console.log("proxyAdmin", address(proxyAdmin));
        vm.label(address(proxyAdmin), "PROXY_ADMIN");
        config = new Config();
        liquidator = new Liquidator(address(config));
        config.setLiquidator(address(liquidator));

        oracle = new Oracle(3);
        multiAssetPosition = new MultiAssetPosition(address(config), address(oracle));

        vm.label(address(multiAssetPosition), "POSITION");
        vm.label(address(config), "CONFIG");
        vm.label(address(oracle), "ORACLE");

        for (uint256 i = 0; i < 5; i++) {
            console.log("i", i);
            string memory name = string(abi.encodePacked("Token", Strings.toString(i)));
            string memory symbol = string(abi.encodePacked("TOKEN", Strings.toString(i)));
            address _asset = address(new ERC20Customized(name, symbol));
            address _vault = address(new Vault(_asset, address(config)));
            vm.label(address(_asset), string(abi.encodePacked("TOKEN", Strings.toString(i))));
            vm.label(address(_vault), string(abi.encodePacked("VAULT", Strings.toString(i))));
            assets.push(ERC20Customized(_asset));
            vaults.push(Vault(_vault));
            config.addVault(address(_vault));
            console.log("vault", address(_vault));

            vaults[i].setWhitelisted(address(multiAssetPosition), true);
        }

        (user,) = makeAddrAndKey("user");
        (user1,) = makeAddrAndKey("user1");
        (user2,) = makeAddrAndKey("user2");
        vm.stopPrank();

        _setKeepers();
        _setHeartbeats();
        _updatePrices();
        _makeMarket();
    }

    function _setKeepers() internal {
        vm.startPrank(deployer);
        oracle.setKeeper(keeper1, true);
        oracle.setKeeper(keeper2, true);
        oracle.setKeeper(keeper3, true);
        oracle.setKeeper(keeper4, true);
        assertEq(oracle.isKeeper(keeper1), true);
        assertEq(oracle.isKeeper(keeper2), true);
        assertEq(oracle.isKeeper(keeper3), true);
        assertEq(oracle.isKeeper(keeper4), true);
        vm.stopPrank();
    }

    function _setHeartbeats() internal {
        vm.startPrank(deployer);
        oracle.setHeartbeat(address(assets[0]), 30);
        oracle.setHeartbeat(address(assets[1]), 30);
        oracle.setHeartbeat(address(assets[2]), 30);
        oracle.setHeartbeat(address(assets[3]), 30);
        vm.stopPrank();
    }

    function _makeMarket() internal {
        deal(address(assets[0]), deployer, 100 ether);
        deal(address(assets[1]), deployer, 100 ether);
        deal(address(assets[2]), deployer, 100 ether);
        deal(address(assets[3]), deployer, 100 ether);
        vm.startPrank(deployer);
        for (uint256 i = 0; i < 4; i++) {
            assets[i].approve(address(vaults[i]), 100 ether);
            vaults[i].deposit(100 ether, deployer);
        }
        vm.stopPrank();
    }

    function _updatePrices() internal {
        _updatePrice(address(assets[0]), (1e18 * 80000) / 1e8);
        _updatePrice(address(assets[1]), (1e18 * 80000) / 1e8);
        _updatePrice(address(assets[2]), (1e18 * 80000) / 1e8);
        _updatePrice(address(assets[3]), (1e18 * 80000) / 1e8);
    }

    function _updatePrice(address _asset, uint256 _price) internal {
        // Test with 3 different prices (odd number)
        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(address(_asset), _price, keeper1Key);
        pMsg[1] = getPMsg(address(_asset), _price, keeper2Key);
        pMsg[2] = getPMsg(address(_asset), _price, keeper3Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(_asset, pMsg);
        vm.stopPrank();
    }

    function getPMsg(address asset, uint256 price, uint256 privateKey) public view returns (PriceMessage memory) {
        uint256 timestamp = block.timestamp;
        uint256 chainId = block.chainid;

        // Use Oracle's EIP-712 hash function
        bytes32 digest = oracle.getPriceMessageHash(asset, price, chainId, timestamp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        return PriceMessage({asset: asset, price: price, chainId: chainId, timestamp: timestamp, signature: signature});
    }
}
