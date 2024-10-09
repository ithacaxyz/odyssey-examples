// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BLS} from "./libraries/BLS.sol";

/// @notice BLS-powered multisignature wallet, demonstrating the use of
/// aggregated BLS signatures for verification
/// @dev This is for demonstration purposes only, do not use in production. This contract does
/// not include protection from rogue public-key attacks.
contract BLSMultisig {
    /// @notice Public keys of signers. This may contain a pre-aggregated
    /// public keys for common sets of signers as well.
    mapping(bytes32 => bool) public signers;

    struct Operation {
        address to;
        bytes data;
        uint256 value;
        uint256 nonce;
    }

    struct SignedOperation {
        Operation operation;
        BLS.G1Point[] signers;
        BLS.G2Point signature;
    }

    /// @notice The negated generator point in G1 (-P1). Used during pairing as a first G1 point.
    BLS.G1Point NEGATED_G1_GENERATOR = BLS.G1Point(
        BLS.Fp(
            31827880280837800241567138048534752271,
            88385725958748408079899006800036250932223001591707578097800747617502997169851
        ),
        BLS.Fp(
            22997279242622214937712647648895181298,
            46816884707101390882112958134453447585552332943769894357249934112654335001290
        )
    );

    /// @notice The number of signatures required to execute an operation.
    uint256 public threshold;

    /// @notice Nonce used for replay protection.
    uint256 public nonce;

    constructor(BLS.G1Point[] memory _signers, uint256 _threshold) {
        for (uint256 i = 0; i < _signers.length; i++) {
            signers[keccak256(abi.encode(_signers[i]))] = true;
        }
        threshold = _threshold;
    }

    /// @notice Maps an operation to a point on G2 which needs to be signed.
    function getOperationPoint(Operation memory op) public view returns (BLS.G2Point memory) {
        return BLS.hashToCurveG2(abi.encode(op));
    }

    /// @notice Accepts an operation signed by a subset of the signers and executes it
    function verifyAndExecute(SignedOperation memory operation) public {
        require(operation.operation.nonce == nonce++, "invalid nonce");
        require(operation.signers.length >= threshold, "not enough signers");

        BLS.G1Point memory aggregatedSigner;

        for (uint256 i = 0; i < operation.signers.length; i++) {
            BLS.G1Point memory signer = operation.signers[i];
            require(signers[keccak256(abi.encode(signer))], "invalid signer");

            if (i == 0) {
                aggregatedSigner = signer;
            } else {
                aggregatedSigner = BLS.G1Add(aggregatedSigner, signer);
                require(_comparePoints(operation.signers[i - 1], signer), "signers not sorted");
            }
        }

        BLS.G1Point[] memory g1Points = new BLS.G1Point[](2);
        BLS.G2Point[] memory g2Points = new BLS.G2Point[](2);

        g1Points[0] = NEGATED_G1_GENERATOR;
        g1Points[1] = aggregatedSigner;

        g2Points[0] = operation.signature;
        g2Points[1] = getOperationPoint(operation.operation);

        // verify signature
        require(BLS.Pairing(g1Points, g2Points), "invalid signature");

        // execute operation
        Operation memory op = operation.operation;
        (bool success,) = op.to.call{value: op.value}(op.data);
        require(success, "execution failed");
    }

    /// @notice Returns true if X coordinate of the first point is lower than the X coordinate of the second point.
    function _comparePoints(BLS.G1Point memory a, BLS.G1Point memory b) internal pure returns (bool) {
        BLS.Fp memory aX = a.x;
        BLS.Fp memory bX = b.x;

        if (aX.a < bX.a) {
            return true;
        } else if (aX.a > bX.a) {
            return false;
        } else if (aX.b < bX.b) {
            return true;
        } else {
            return false;
        }
    }

    receive() external payable {}
}
