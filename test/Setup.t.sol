// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {TestUtils} from "./TestUtils.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {Core} from "../src/Core.sol";
import {Position} from "../src/Position.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Oracle} from "../src/Oracle.sol";

contract ERC20Customized is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

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
    Core public core;
    Position public position;
    Vault[] public vaults;
    ERC20Customized[] public assets;
    Oracle public oracle;
    address public user;
    address public user1;
    address public user2;
    address public deployer;
    address public keeper1;
    address public keeper2;
    address public keeper3;
    uint256 public keeper1Key;
    uint256 public keeper2Key;
    uint256 public keeper3Key;

    function setUp() public {
        (deployer, ) = makeAddrAndKey("deployer");
        (keeper1, keeper1Key) = makeAddrAndKey("keeper1");
        (keeper2, keeper2Key) = makeAddrAndKey("keeper2");
        (keeper3, keeper3Key) = makeAddrAndKey("keeper3");
        vm.startPrank(deployer);
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        console.log("proxyAdmin", address(proxyAdmin));
        Core _core = new Core();
        Position _position = new Position();
        Oracle _oracle = new Oracle();
        core = Core(
            _makeProxy(
                proxyAdmin,
                address(_core),
                abi.encodeWithSelector(
                    Core.initialize.selector,
                    address(position)
                )
            )
        );
        position = Position(
            _makeProxy(
                proxyAdmin,
                address(_position),
                abi.encodeWithSelector(
                    Position.initialize.selector,
                    address(core)
                )
            )
        );
        core.setPosition(address(position));

        oracle = Oracle(
            _makeProxy(
                proxyAdmin,
                address(_oracle),
                abi.encodeWithSelector(Oracle.initialize.selector, 3)
            )
        );

        Vault _logic = new Vault();
        for (uint i = 0; i < 5; i++) {
            console.log("i", i);
            string memory name = string(
                abi.encodePacked("Token", Strings.toString(i))
            );
            string memory symbol = string(
                abi.encodePacked("TOKEN", Strings.toString(i))
            );
            address _asset = address(new ERC20Customized(name, symbol));
            address _vault = address(
                _makeProxy(
                    proxyAdmin,
                    address(_logic),
                    abi.encodeWithSelector(
                        Vault.initialize.selector,
                        address(_asset),
                        address(core)
                    )
                )
            );
            vm.label(
                address(_asset),
                string(abi.encodePacked("TOKEN", Strings.toString(i)))
            );
            vm.label(
                address(_vault),
                string(abi.encodePacked("VAULT", Strings.toString(i)))
            );
            assets.push(ERC20Customized(_asset));
            vaults.push(Vault(_vault));
            core.addVault(address(_vault));
            console.log("vault", address(_vault));
        }

        (user, ) = makeAddrAndKey("user");
        (user1, ) = makeAddrAndKey("user1");
        (user2, ) = makeAddrAndKey("user2");
        vm.stopPrank();
    }
}
