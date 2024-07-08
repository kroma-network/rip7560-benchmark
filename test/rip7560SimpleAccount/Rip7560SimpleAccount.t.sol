pragma solidity ^0.8.0;

import "src/TestRip7560Base.sol";

import {
    Rip7560SimpleAccountFactory,
    Rip7560SimpleAccount,
    RIP7560_SIMPLE_ACCOUNT_FACTORY_ADDRESS,
    RIP7560_SIMPLE_ACCOUNT_DEPLOYED_ADDRESS,
    RIP7560_SIMPLE_ACCOUNT_EOA_ADDRESS,
    MOCK_ERC20_ADDRESS
} from "./Rip7560SimpleAccountArtifacts.sol";

contract Rip7560SimpleAccountTest is Rip7560GasProfileBase {
    Rip7560SimpleAccountFactory factory;

    function setUp() external {
        forkDevnet();
        initializeTest("simpleAccount");
        factory = Rip7560SimpleAccountFactory(RIP7560_SIMPLE_ACCOUNT_FACTORY_ADDRESS);
        emptyAccount = RIP7560_SIMPLE_ACCOUNT_EOA_ADDRESS;
        deployedAccount = RIP7560_SIMPLE_ACCOUNT_DEPLOYED_ADDRESS;
        key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        owner = vm.addr(key);
        token = MOCK_ERC20_ADDRESS;
    }

    function fillData(address _to, uint256 _value, bytes memory _data) internal view override returns (bytes memory) {
        return abi.encodeWithSelector(Rip7560SimpleAccount.execute.selector, _to, _value, _data);
    }

    function getRip7560Signature(TransactionType4 memory _tx) internal view override returns (bytes memory) {
        return signTransactionHash(key, _tx);
    }

    function createAccount(address _owner) internal override {
        factory.createAccount(_owner, 0);
    }

    function getAccountAddr(address _owner) internal view override returns (IAccount) {
        return IAccount(factory.getAddress(_owner, 0));
    }

    function getDeployerData(address _owner, uint256 salt) internal view override returns (bytes memory) {
        return abi.encodePacked(address(factory), abi.encodeWithSelector(factory.createAccount.selector, _owner, salt));
    }

    function getRip7560DummySig(TransactionType4 memory _tx) internal pure override returns (bytes memory) {
        return
        hex"fffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c";
    }
}