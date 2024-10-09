// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {Secp256r1} from "../contracts/Secp256r1.sol";

/// @notice A simple test demonstrating P256 signature verification.
contract BLSTest is Test {
    function test() public {
        // Obtain the private key and derive the public key.
        uint256 privateKey = vm.randomUint();
        (uint256 publicKeyX, uint256 publicKeyY) = vm.publicKeyP256(privateKey);

        bytes memory message = "hello world";
        bytes32 digest = keccak256(message);

        // Sign the hashed message.
        (bytes32 r, bytes32 s) = vm.signP256(privateKey, digest);

        // Verify the signature.
        assertTrue(Secp256r1.verify(digest, r, s, publicKeyX, publicKeyY));
    }
}
