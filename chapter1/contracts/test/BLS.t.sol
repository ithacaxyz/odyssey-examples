// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {BLS} from "../src/libraries/BLS.sol";

/// @notice A simple test demonstrating BLS signature verification.
contract BLSTest is Test {
    /// @notice The generator point in G1 (P1).
    BLS.G1Point G1_GENERATOR = BLS.G1Point(
        BLS.Fp(
            31827880280837800241567138048534752271,
            88385725958748408079899006800036250932223001591707578097800747617502997169851
        ),
        BLS.Fp(
            11568204302792691131076548377920244452,
            114417265404584670498511149331300188430316142484413708742216858159411894806497
        )
    );

    /// @notice The negated generator point in G1 (-P1).
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

    /// @dev Demonstrates the signing and verification of a message.
    function test() public {
        // Obtain the private key as a random scalar.
        uint256 privateKey = vm.randomUint();

        // Public key is the generator point multiplied by the private key.
        BLS.G1Point memory publicKey = BLS.G1Mul(G1_GENERATOR, privateKey);

        // Compute the message point by mapping message's keccak256 hash to a point in G2.
        bytes memory message = "hello world";
        BLS.G2Point memory messagePoint = BLS.MapFp2ToG2(BLS.Fp2(BLS.Fp(0, 0), BLS.Fp(0, uint256(keccak256(message)))));

        // Obtain the signature by multiplying the message point by the private key.
        BLS.G2Point memory signature = BLS.G2Mul(messagePoint, privateKey);

        // Invoke the pairing check to verify the signature.
        BLS.G1Point[] memory g1Points = new BLS.G1Point[](2);
        g1Points[0] = NEGATED_G1_GENERATOR;
        g1Points[1] = publicKey;

        BLS.G2Point[] memory g2Points = new BLS.G2Point[](2);
        g2Points[0] = signature;
        g2Points[1] = messagePoint;

        assertTrue(BLS.Pairing(g1Points, g2Points));
    }

    /// @dev Demonstrates the aggregation and verification of two signatures.
    function testAggregated() public {
        // private keys
        uint256 sk1 = vm.randomUint();
        uint256 sk2 = vm.randomUint();

        // public keys
        BLS.G1Point memory pk1 = BLS.G1Mul(G1_GENERATOR, sk1);
        BLS.G1Point memory pk2 = BLS.G1Mul(G1_GENERATOR, sk2);

        // Compute the message point by mapping message's keccak256 hash to a point in G2.
        bytes memory message = "hello world";
        BLS.G2Point memory messagePoint = BLS.MapFp2ToG2(BLS.Fp2(BLS.Fp(0, 0), BLS.Fp(0, uint256(keccak256(message)))));

        // signatures
        BLS.G2Point memory sig1 = BLS.G2Mul(messagePoint, sk1);
        BLS.G2Point memory sig2 = BLS.G2Mul(messagePoint, sk2);

        // aggregated signature
        BLS.G2Point memory sig = BLS.G2Add(sig1, sig2);

        // Invoke the pairing check to verify the signature.
        BLS.G1Point[] memory g1Points = new BLS.G1Point[](3);
        g1Points[0] = NEGATED_G1_GENERATOR;
        g1Points[1] = pk1;
        g1Points[2] = pk2;

        BLS.G2Point[] memory g2Points = new BLS.G2Point[](3);
        g2Points[0] = sig;
        g2Points[1] = messagePoint;
        g2Points[2] = messagePoint;

        assertTrue(BLS.Pairing(g1Points, g2Points));
    }
}
