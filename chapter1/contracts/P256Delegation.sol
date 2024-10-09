// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Secp256r1} from "./Secp256r1.sol";

/// @notice Contract designed for being delegated to by EOAs to authorize a secp256r1 key to transact on their behalf.
contract P256Delegation {
    /// @notice The x coordinate of the authorized public key
    uint256 authorizedPublicKeyX;
    /// @notice The y coordinate of the authorized public key
    uint256 authorizedPublicKeyY;

    /// @notice Internal nonce used for replay protection, must be tracked and included into prehashed message.
    uint256 public nonce;

    /// @notice Authorizes provided public key to transact on behalf of this account. Only callable by EOA itself.
    function authorize(uint256 publicKeyX, uint256 publicKeyY) public {
        require(msg.sender == address(this));

        authorizedPublicKeyX = publicKeyX;
        authorizedPublicKeyY = publicKeyY;
    }

    /// @notice Main entrypoint for authorized transactions. Accepts transaction parameters (to, data, value) and a secp256r1 signature.
    function transact(address to, bytes memory data, uint256 value, bytes32 r, bytes32 s) public {
        bytes32 digest = keccak256(abi.encode(nonce++, to, data, value));
        require(Secp256r1.verify(digest, r, s, authorizedPublicKeyX, authorizedPublicKeyY), "Invalid signature");

        (bool success,) = to.call{value: value}(data);
        require(success);
    }
}
