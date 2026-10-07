// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MiniOracle {
    address public immutable trustedSigner;
    uint256 public latestPrice;
    uint256 public latestTimestamp;
    uint256 public constant MAX_STALENESS = 300;

    event PriceUpdated(uint256 price, uint256 timestamp);

    error InvalidSignature();
    error StaleData();
    error FutureTimestamp();

    constructor(address _trustedSigner) {
        trustedSigner = _trustedSigner;
    }

    function updatePrice(
        uint256 price,
        uint256 timestamp,
        bytes memory signature
    ) external {
        if (timestamp <= latestTimestamp) revert StaleData();
        if (timestamp > block.timestamp + 60) revert FutureTimestamp();
        if (block.timestamp - timestamp > MAX_STALENESS) revert StaleData();

        bytes32 messageHash = keccak256(
            abi.encodePacked(price, timestamp, block.chainid, address(this))
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        address recovered = recoverSigner(ethSignedMessageHash, signature);
        if (recovered != trustedSigner) revert InvalidSignature();

        latestPrice = price;
        latestTimestamp = timestamp;

        emit PriceUpdated(price, timestamp);
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _sig
    ) internal pure returns (address) {
        if (_sig.length != 65) revert InvalidSignature();

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }
}
