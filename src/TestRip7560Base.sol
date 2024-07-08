pragma solidity ^0.8.0;

import "solady/utils/ECDSA.sol";
import "solady/utils/LibRLP.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "src/MockERC20.sol";
import "./RLPEncoder.sol";
import "./TestBase.sol";
import {TransactionType4} from "./interfaces/IRip7560Account.sol";

abstract contract Rip7560GasProfileBase is AAGasProfileBase {
    address emptyAccount;
    address deployedAccount;
    uint256 public devnetFork;
    address public constant RIP7560_ENTRYPOINT = 0x0000000000000000000000000000000000007560;
    address token;

    function (TransactionType4 memory) internal view returns(bytes memory) rip7560PaymasterData;
    function (TransactionType4 memory) internal view returns(bytes memory) rip7560DummyPaymasterData;

    function forkDevnet() public {
        devnetFork = vm.createFork("pioneerDevnet");
    }

    function fillRip7560Transaction(bytes memory _data, address account) internal view returns (TransactionType4 memory _tx) {
        _tx.sender = account;
        _tx.nonce = 0; // Using legacy nonce by default
        if (account == emptyAccount) {
            _tx.deployerAndData = getDeployerData(owner, 0);
        }
        _tx.callData = _data;
        _tx.callGasLimit = 1000000;
        _tx.validationGasLimit = 1000000;
        _tx.builderFee = 0;
        _tx.maxFeePerGas = 1;
        _tx.maxPriorityFeePerGas = 1;
        _tx.signature = getRip7560DummySig(_tx);
        _tx.paymasterAndData = rip7560DummyPaymasterData(_tx);
        _tx.paymasterAndData = rip7560PaymasterData(_tx);
        _tx.signature = getRip7560Signature(_tx);
    }

    function executeTransaction(TransactionType4 memory _tx, string memory _test, uint256 _value) internal {
        vm.selectFork(devnetFork);
        string memory estimateGasParams = serializeAaTransaction(_tx);

        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "src/rip7560-samples/estimateGas.js";
        inputs[2] = estimateGasParams;

        bytes memory result = vm.ffi(inputs);
        uint256 gasUsed_ = stringToUint(string(result));
    

        if (!writeGasProfile) {
            console.log("case - %s", _test);
            // TODO: Fix this
            console.log("  gasUsed       : ", gasUsed_);
            console.log("  calldatacost  : ", calldataCost(pack(_tx)));
        }
        if (writeGasProfile && bytes(scenarioName).length > 0) {
            // TODO: Fix this
            uint256 gasUsed = gasUsed_ + calldataCost(pack(_tx));
            vm.serializeUint(jsonObj, _test, gasUsed);
            sum += gasUsed;
        }
    }

    function testRip7560Creation() internal {
        TransactionType4 memory _tx = fillRip7560Transaction(fillData(address(0), 0, ""), emptyAccount);
        executeTransaction(_tx, "creation", 0);
    }

    function testRip7560TransferNative() internal {
        uint256 amount = 5e17;
        address recipient = makeAddr("recipient");
        TransactionType4 memory _tx = fillRip7560Transaction(fillData(recipient, amount, ""), deployedAccount);
        executeTransaction(_tx, "native", amount);
    }

    function testRip7560TransferERC20() internal {
        MockERC20 mockToken = MockERC20(token);
        // mockToken.mint(address(account), 1e18);
        // uint256 amount = 5e17;
        address recipient = makeAddr("recipient");
        TransactionType4 memory _tx = fillRip7560Transaction(
            fillData(address(mockToken), 0, abi.encodeWithSelector(mockToken.transfer.selector, recipient, 1)),
            deployedAccount
        );
        executeTransaction(_tx, "erc20", 0);
    }

    function testBenchmark4Rip7560() external {
        scenarioName = "rip7560";
        jsonObj = string(abi.encodePacked(scenarioName, " ", name));
        rip7560PaymasterData = validateRip7560PaymasterAndData;
        rip7560DummyPaymasterData = getRip7560DummyPaymasterAndData;

        testRip7560Creation();
        // testRip7560TransferNative();
        // testRip7560TransferERC20();
        if (writeGasProfile) {
            string memory res = vm.serializeUint(jsonObj, "sum", sum);
            console.log(res);
            vm.writeJson(res, string.concat("./results/", scenarioName, "_", name, ".json"));
        }
    }

    function validateRip7560PaymasterAndData(TransactionType4 memory _tx) internal view returns (bytes memory ret) {
        // TODO: Implement this
        // bytes32 hash = paymaster.getHash(_tx, 0, 0);
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifierKey, ECDSA.toEthSignedMessageHash(hash));
        // ret = abi.encodePacked(address(paymaster), uint256(0), uint256(0), r, s, uint8(v));
    }

    function getRip7560DummyPaymasterAndData(TransactionType4 memory _tx) internal view returns (bytes memory ret) {
        ret = abi.encodePacked(
            address(paymaster),
            uint256(0),
            uint256(0),
            hex"fffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c"
        );
    }

    function pack(TransactionType4 memory _tx) internal pure returns (bytes memory) {
        bytes memory packed = abi.encode(
            _tx.sender,
            _tx.nonce,
            _tx.deployerAndData,
            _tx.callData,
            _tx.callGasLimit,
            _tx.validationGasLimit,
            _tx.builderFee,
            _tx.maxFeePerGas,
            _tx.maxPriorityFeePerGas,
            _tx.paymasterAndData,
            _tx.signature
        );
        return packed;
    }

    function _rlpEncodeHash(TransactionType4 memory _tx) internal view returns (bytes32) {
        // bytes memory encodedFixedLengthParams;
        // {
        //     bytes memory encodedChainId = RLPEncoder.encodeUint256(block.chainid);
        //     bytes memory encodedNonce = RLPEncoder.encodeUint256(_tx.nonce);
        //     bytes memory encodedBuilderFee = RLPEncoder.encodeUint256(_tx.builderFee);
        //     bytes memory encodedGasTipCap = RLPEncoder.encodeUint256(_tx.maxPriorityFeePerGas);
        //     bytes memory encodedGasFeeCap = RLPEncoder.encodeUint256(_tx.maxFeePerGas);
        //     bytes memory encodedValidationGasLimit = RLPEncoder.encodeUint256(_tx.validationGasLimit);
        //     bytes memory encodedPaymasterValidationGasLimit = RLPEncoder.encodeUint256(_tx.paymasterValidationGasLimit);
        //     bytes memory encodedPaymasterPostOpGasLimit = RLPEncoder.encodeUint256(_tx.paymasterPostOpGasLimit);
        //     bytes memory encodedCallGasLimit = RLPEncoder.encodeUint256(_tx.callGasLimit);
        //     encodedFixedLengthParams = bytes.concat(
        //         encodedChainId,
        //         encodedNonce,
        //         encodedBuilderFee,
        //         encodedGasTipCap,
        //         encodedGasFeeCap,
        //         encodedValidationGasLimit,
        //         encodedPaymasterValidationGasLimit,
        //         encodedPaymasterPostOpGasLimit,
        //         encodedCallGasLimit
        //     );
        // }

        // bytes memory encodedDeployerDataLength;
        // {
        //     uint64 deployerDataLength = uint64(_tx.deployerAndData.length);
        //     if (deployerDataLength != 1) {
        //         encodedDeployerDataLength = RLPEncoder.encodeNonSingleBytesLen(deployerDataLength);
        //     } else if (_tx.deployerAndData[0] >= 0x80) {
        //         encodedDeployerDataLength = hex"81";
        //     }
        // }

        // bytes memory encodedPaymasterDataLength;
        // {
        //     uint64 paymasterDataLength = uint64(_tx.paymasterAndData.length);
        //     if (paymasterDataLength != 1) {
        //         encodedPaymasterDataLength = RLPEncoder.encodeNonSingleBytesLen(paymasterDataLength);
        //     } else if (_tx.paymasterAndData[0] >= 0x80) {
        //         encodedPaymasterDataLength = hex"81";
        //     }
        // }

        // bytes memory encodedDataLength;
        // {
        //     uint64 dataLength = uint64(_tx.callData.length);
        //     if (dataLength != 1) {
        //         encodedDataLength = RLPEncoder.encodeNonSingleBytesLen(dataLength);
        //     } else if (_tx.callData[0] >= 0x80) {
        //         encodedDataLength = hex"81";
        //     }
        // }

        // // This time, access list is empty
        // bytes memory encodedAccessListLength = RLPEncoder.encodeListLen(0);

        // bytes memory encodedListLength;
        // unchecked {
        //     uint256 listLength = encodedFixedLengthParams.length + encodedDeployerDataLength.length + _tx.deployerAndData.length + encodedAccessListLength.length + encodedPaymasterDataLength.length + _tx.paymasterAndData.length + encodedDataLength.length + _tx.callData.length;
        
        //     encodedListLength = RLPEncoder.encodeListLen(uint64(listLength));
        // }

        // return keccak256(
        //     bytes.concat(
        //         encodedListLength,
        //         encodedFixedLengthParams,
        //         encodedDeployerDataLength,
        //         _tx.deployerAndData,
        //         encodedPaymasterDataLength,
        //         _tx.paymasterAndData,
        //         encodedDataLength,
        //         _tx.callData,
        //         encodedAccessListLength
        //     )
        // );
        return keccak256(abi.encodePacked("dummy"));
    }

    function rlpEncodeHash(TransactionType4 memory _tx) internal view returns (bytes32) {
        return _rlpEncodeHash(_tx);
    }

    // NOTE: this can vary depending on the bundler, this equation is referencing eth-infinitism bundler's pvg calculation
    function calculateBuilderFee(TransactionType4 memory _tx) internal view returns (uint256) {
        bytes memory packed = pack(_tx);
        uint256 calculated = OV_FIXED + OV_PER_USEROP + OV_PER_WORD * (packed.length + 31) / 32;
        calculated += calldataCost(packed);
        return calculated;
    }

    function serializeAaTransaction(TransactionType4 memory _tx) internal returns (string memory) {
        string memory obj = "transaction";
        vm.serializeAddress(obj, "from", RIP7560_ENTRYPOINT);
        // vm.serializeAddress(obj, "to", address(account));
        vm.serializeAddress(obj, "sender", _tx.sender);
        vm.serializeString(obj, "bigNonce", uintToString(_tx.nonce));
        vm.serializeString(obj, "builderFee", uintToString(_tx.builderFee));
        vm.serializeString(obj, "maxFeePerGas", uintToString(_tx.maxFeePerGas));
        vm.serializeString(obj, "maxPriorityFeePerGas", uintToString(_tx.maxPriorityFeePerGas));
        vm.serializeString(obj, "validationGas", uintToString(_tx.validationGasLimit));
        vm.serializeString(obj, "paymasterGas", uintToString(_tx.paymasterValidationGasLimit));
        vm.serializeString(obj, "postOpGas", uintToString(_tx.paymasterPostOpGasLimit));
        vm.serializeString(obj, "gas", uintToString(_tx.callGasLimit));
        // Hardcoded
        vm.serializeString(obj, "subType", "0x1");
        vm.serializeString(obj, "gasPrice", "0x1");
        vm.serializeBytes(obj, "deployerData", _tx.deployerAndData);
        vm.serializeBytes(obj, "paymasterData", _tx.paymasterAndData);
        vm.serializeBytes(obj, "data", _tx.callData);
        return vm.serializeBytes(obj, "signature", _tx.signature);
    }

    function uintToString(uint256 v) internal pure returns (string memory str) {
        return string(abi.encodePacked("0x", Strings.toString(v)));
    }

    function stringToUint(string memory s) internal pure returns (uint result) {
        bytes memory b = bytes(s);
        uint i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    function signTransactionHash(uint256 _key, TransactionType4 memory _tx)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 _hash = 0x315296e3f591252be38663c3ac254e81317ddad1b7e0bfdbf40924fa9ae42d94;
        console.logBytes32(_hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, ECDSA.toEthSignedMessageHash(_hash));
        signature = abi.encodePacked(r, s, v);
    }

    function getRip7560Signature(TransactionType4 memory _tx) internal view virtual returns (bytes memory);

    function getRip7560DummySig(TransactionType4 memory _tx) internal pure virtual returns (bytes memory);

    function getDeployerData(address _owner, uint256 salt) internal view virtual returns (bytes memory);

    function getDummySig(UserOperation memory _op) internal pure override returns (bytes memory) {}
    
    function getSignature(UserOperation memory _op) internal view override returns (bytes memory) {}

    function getInitCode(address _owner) internal view override returns (bytes memory) {}
}
