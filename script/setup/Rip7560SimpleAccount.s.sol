pragma solidity ^0.8.0;

import "script/AATestScriptBase.s.sol";
import {MockERC20} from "src/MockERC20.sol";
import {MockNFT} from "src/MockNFT.sol";
import {TransactionType4} from "src/interfaces/IRip7560Account.sol";
import {Rip7560SimpleAccountFactory} from "src/rip7560-samples/simpleAccount/Rip7560SimpleAccountFactory.sol";
import {Rip7560SimpleAccount} from "src/rip7560-samples/simpleAccount/Rip7560SimpleAccount.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract Rip7560TestScriptBase is Script {
    uint256 public deployerKey;

    MockERC20 token;
    MockNFT mockNFT;

    function setUp() external {
        deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.rpcUrl("pioneerDevnet");
        // Note: you have to prepare at least 0.21 eth at the deployer account
        vm.startBroadcast(deployerKey);
        token = new MockERC20();
        mockNFT = new MockNFT();
        console.log("Token: %s, NFT: %s", address(token), address(mockNFT));
        vm.stopBroadcast();
    }

    function run() external {
        vm.startBroadcast(deployerKey);
        // Deploy accounts to pioneer devnet
        (address factory, address eoaAccount, address deployedAccount) = prepareFactoryAndAccount(vm.addr(deployerKey));
        console.log("Factory: %s, EOA: %s, Deployed: %s", factory, eoaAccount, deployedAccount);
        // Fund the given wallets
        token.mint(deployedAccount, 10e18);
        (bool success, bytes memory res) = address(eoaAccount).call{value: 1e16}("");
        if (!success) {
            console.log("Failed to fund EOA account: %s", string(res));
            revert();
        }
        (success, res) = address(deployedAccount).call{value: 1e16}("");
        if (!success) {
            console.log("Failed to fund deployed account: %s", string(res));
            revert();
        }
        vm.stopBroadcast();
    }

    function prepareFactoryAndAccount(address owner) internal returns (address, address, address) {
        Rip7560SimpleAccountFactory factory = new Rip7560SimpleAccountFactory();
        address eoaAccount = factory.getAddress(owner, 0);
        Rip7560SimpleAccount deployedAccount = Rip7560SimpleAccount(factory.createAccount(owner, 1));
        return (address(factory), eoaAccount, address(deployedAccount));
    }
}
