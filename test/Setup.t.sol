// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {TestUtils} from "./TestUtils.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {Core} from "../src/Core.sol";
import {Position} from "../src/Position.sol";

contract Setup is TestUtils {
    Core public core;
    Position public position;
    Vault public vault;
    ERC20Mock public asset;
    address public user;
    address public deployer;

    function setUp() public {
        (deployer,) = makeAddrAndKey("deployer");
        vm.startPrank(deployer);
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        asset = new ERC20Mock();
        Vault _logic = new Vault();
        Core _core = new Core();
        Position _position = new Position();

        core = Core(_makeProxy(
            proxyAdmin,
            address(_core),
            abi.encodeWithSelector(Core.initialize.selector, address(position))
        ));

        vault = Vault(_makeProxy(
            proxyAdmin,
            address(_logic),
            abi.encodeWithSelector(Vault.initialize.selector, address(asset), address(core))
        ));

        position = Position(_makeProxy(
            proxyAdmin,
            address(_position),
            abi.encodeWithSelector(Position.initialize.selector, address(core))
        ));

        core.addVault(address(vault));
        core.setPosition(address(position));

        (user,) = makeAddrAndKey("user");
        vm.stopPrank();
    }
}
