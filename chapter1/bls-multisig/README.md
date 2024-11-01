# BLS Multisig

## Context
Imagine a DAO consisting of 100 members (signers in total), where at least 50 members need to approve any transfer of funds from the treasury to ensure that funds cannot be misused without sufficient consensus from the key holders.

EIP-2537 introduces a set of precompiled contracts enabling elliptic curve operations directly on the Ethereum Virtual Machine (EVM). This makes it feasible to use BLS signatures natively on Ethereum and dramatically reduces the cost and complexity of these operations, unlocking efficient use of BLS-based schemes like multisig.

## Implementation

### Contract
We demonstrate a simple multisignature contract [BLSMultisig](../contracts/src/BLSMultisig.sol) which keeps a list of signers public keys and allows executing arbitrary operations which are signed by a subset of signers. Both stored public keys and signatures can be aggregated, thus allowing for much better scalability for large numbers of signers vs ECDSA. Let's walk through the contract's code.

BLS signing operates on two curves: G1 and G2. In our case we will store public keys on G1 while signatures and messages will be on G2. To sign or verify a message consisting of arbitrary bytes, we need to firstly map the message to a point on G2. There is a commonly used [algorithm](https://datatracker.ietf.org/doc/html/rfc9380#name-hashing-to-a-finite-field) for this mapping, we are using its implementation in Solidity:

```solidity
/// @notice Maps an operation to a point on G2 which needs to be signed.
function getOperationPoint(Operation memory op) public view returns (BLS.G2Point memory) {
    return BLS.hashToCurveG2(abi.encode(op));
}
```

Secondly, the contract method `verifyAndExecute` contains core logic for signature verification, let's walk through it.

We start with aggregating the signers public keys into a single point on G1. This is done by simply invoking G1ADD precompile with all public keys. After this step, we will have a single point on G1 which represents the aggregated public key of all signers. We require signers to be sorted to ensure that all signers are unique and valid.

```solidity
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
```

After that, we perform signature verification, by invoking the PAIRING precompile with the aggregated public key and the signature. Notice that we are invoking the `getOperationPoint` method we've defined earlier to map the operation to a point on G2 which we can verify against the signature.
```solidity
BLS.G1Point[] memory g1Points = new BLS.G1Point[](2);
BLS.G2Point[] memory g2Points = new BLS.G2Point[](2);

g1Points[0] = NEGATED_G1_GENERATOR;
g1Points[1] = aggregatedSigner;

g2Points[0] = operation.signature;
g2Points[1] = getOperationPoint(operation.operation);

// verify signature
require(BLS.Pairing(g1Points, g2Points), "invalid signature");
```

If all of those steps are successful, we can execute the operation.

### Integration

We've prepared 2 code snippets demonstrating an integration of the above contract to aggregate and submit signatures obtained off-chain. Examples are written in [Rust](./rust) and [Python](./python). We will walk through the Rust code, but the Python code is very similar.

We will use [blst](https://github.com/supranational/blst) library for BLS operations.

Let's start with generating bindings for our contract.
```rust
alloy::sol! {
    #[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
    #[sol(rpc)]
    BLSMultisig,
    "../out/BLSMultisig.sol/BLSMultisig.json"
}
```

This will generate bindings for `BLSMultisig` and `BLS`, allowing us to reuse the same G1/G2 structures in Rust code.

Now, let's define helpers for converting between our contract's structures and `blst` types. `blst` provides serialization methods for both G1 and G2 points which are a bit different from the format defined in [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537). Converting between the two requires some bit manipulation.
```rust
use blst::min_pk::{PublicKey, Signature};

/// Converts a blst [`PublicKey`] to a [`BLS::G1Point`] which can be passed to the contract
impl From<PublicKey> for BLS::G1Point {
    fn from(value: PublicKey) -> Self {
        let serialized = value.serialize();

        let mut data = [0u8; 128];
        data[16..64].copy_from_slice(&serialized[0..48]);
        data[80..128].copy_from_slice(&serialized[48..96]);

        BLS::G1Point::abi_decode(&data, false).unwrap()
    }
}

/// Converts a blst [`Signature`] to a [`BLS::G2Point`] which can be passed to the contract
impl From<Signature> for BLS::G2Point {
    fn from(value: Signature) -> Self {
        let serialized = value.serialize();

        let mut data = [0u8; 256];
        data[16..64].copy_from_slice(&serialized[48..96]);
        data[80..128].copy_from_slice(&serialized[0..48]);
        data[144..192].copy_from_slice(&serialized[144..192]);
        data[208..256].copy_from_slice(&serialized[96..144]);

        BLS::G2Point::abi_decode(&data, false).unwrap()
    }
}

```

Next, let's define helpers for generating BLS keys and signing messages.
```rust
use blst::min_pk::{AggregateSignature, PublicKey, SecretKey, Signature};

/// Generates `num` BLS keys and returns them as a tuple of private and public keys
fn generate_keys(num: usize) -> (Vec<SecretKey>, Vec<BLS::G1Point>) {
    let mut rng = rand::thread_rng();

    let mut public = Vec::with_capacity(num);
    let mut private = Vec::with_capacity(num);

    for _ in 0..num {
        let mut ikm = [0u8; 32];
        rng.fill_bytes(&mut ikm);

        let sk = SecretKey::key_gen(&ikm, &[]).unwrap();
        let pk = BLS::G1Point::from(sk.sk_to_pk());

        public.push(pk);
        private.push(sk);
    }

    (private, public)
}

/// Signs a message with the provided keys and returns the aggregated signature.
fn sign_message(keys: &[&SecretKey], msg: &[u8]) -> BLS::G2Point {
    let mut sigs = Vec::new();

    // create individual signatures
    for key in keys {
        let sig = key.sign(msg, b"BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_NUL_", &[]);
        sigs.push(sig);
    }

    // aggregate
    Signature::from_aggregate(
        &AggregateSignature::aggregate(sigs.iter().collect::<Vec<_>>().as_slice(), false).unwrap(),
    )
    .into()
}
```

We now have all the pieces we need to interact with our contract. Let's try to send a simple operation. 

Firstly, we need to launch Anvil node and connect to it.
```rust
// Spawn Anvil node in --odyssey mode
let provider = ProviderBuilder::new().on_anvil_with_config(|config| config.arg("--odyssey"));
```

Let's now setup our multisig contract.
```rust
// Generate 100 BLS keys
let (private_keys, public_keys) = generate_keys(100);

// Deploy multisig contract, configuring generated keys as signers and requiring threshold of 50
let multisig = BLSMultisig::deploy(&provider, public_keys.clone(), U256::from(50)).await?;

// Fund multisig with some ETH
provider
    .send_transaction(
        TransactionRequest::default()
            .to(*multisig.address())
            .with_value(U256::from(1_000_000_000_000_000_000u128)),
    )
    .await?
    .watch()
    .await?;
```

At this point we should be able to sign any operation with at least 50 signers, and execute it on behalf of the multisig contract. Let's transfer 1 ETH to a random address:
```rust
let operation = BLSMultisig::Operation {
    to: Address::random(),
    value: U256::from(1_000_000_000_000_000_000u128),
    nonce: multisig.nonce().call().await?._0,
    data: Default::default(),
};
```

Firstly, we choose 50 random signers from our set of 100 keys to sign the operation.
```rust
let (keys, signers): (Vec<_>, Vec<_>) = {
    let mut pairs = private_keys
        .iter()
        .zip(public_keys.clone())
        .choose_multiple(&mut rand::thread_rng(), 50);

    // contract requires signers to be sorted by public key
    pairs.sort_by(|(_, pk1), (_, pk2)| pk1.cmp(pk2));

    pairs.into_iter().unzip()
};
```

Then, we sign the operation with the chosen keys.
```rust
let signature = sign_message(&keys, &operation.abi_encode());
```

Finally, we send the signed operation to the contract along with the list of signers.
```rust
let receipt = multisig
    .verifyAndExecute(BLSMultisig::SignedOperation {
        operation: operation.clone(),
        signers,
        signature,
    })
    .send()
    .await?
    .get_receipt()
    .await?;

// Assert that the transaction was successful and that recipient has received the funds
assert!(receipt.status());
assert!(provider.get_balance(operation.to).await? > U256::ZERO);
```
