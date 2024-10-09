// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

//( @title Secp256r1
/// @notice Wrapper function to abstract low level details of call to the Secp256r1
///         signature verification precompile as defined in EIP-7212, see
///         <https://eips.ethereum.org/EIPS/eip-7212>.
library Secp256r1 {
    /// @notice P256VERIFY operation
    /// @param digest 32 bytes of the signed data hash
    /// @param r 32 bytes of the r component of the signature
    /// @param s 32 bytes of the s component of the signature
    /// @param publicKeyX 32 bytes of the x coordinate of the public key
    /// @param publicKeyY 32 bytes of the y coordinate of the public key
    /// @return success Represents if the operation was successful
    function verify(bytes32 digest, bytes32 r, bytes32 s, uint256 publicKeyX, uint256 publicKeyY)
        internal
        view
        returns (bool)
    {
        // P256VERIFY address is 0x14 from <https://github.com/paradigmxyz/alphanet/blob/main/crates/precompile/src/addresses.rs>
        (bool success, bytes memory output) = address(0x14).staticcall(abi.encode(digest, r, s, publicKeyX, publicKeyY));
        success = success && output.length == 32 && output[31] == 0x01;

        return success;
    }
}
