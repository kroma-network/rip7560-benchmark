// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

bytes4 constant MAGIC_VALUE_SENDER = 0xbf45c166;

bytes4 constant MAGIC_VALUE_SIGFAIL = 0x31665494;

struct ValidationData {
    bytes20 magicValue;
    uint48 validUntil;
    uint48 validAfter;
}

function _packValidationData(ValidationData memory data) pure returns (bytes32) {
    return
        bytes32(data.magicValue) | bytes32(uint256(data.validUntil)) << 48 | bytes32(uint256(data.validAfter));
}