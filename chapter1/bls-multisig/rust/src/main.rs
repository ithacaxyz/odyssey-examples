use alloy::{
    network::TransactionBuilder,
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder},
    rpc::types::TransactionRequest,
    sol_types::SolValue,
};
use blst::min_pk::{AggregateSignature, PublicKey, SecretKey, Signature};
use rand::{seq::IteratorRandom, RngCore};

alloy::sol! {
    #[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
    #[sol(rpc)]
    BLSMultisig,
    "../../out/BLSMultisig.sol/BLSMultisig.json"
}

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

#[tokio::main]
pub async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Spawn Anvil node and connect to it
    let provider = ProviderBuilder::new().on_anvil_with_config(|config| config.arg("--alphanet"));

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

    // Operation which will transfer 1 ETH to a random address
    let operation = BLSMultisig::Operation {
        to: Address::random(),
        value: U256::from(1_000_000_000_000_000_000u128),
        nonce: multisig.nonce().call().await?._0,
        data: Default::default(),
    };

    // Choose 50 random signers to sign the operation
    let (keys, signers): (Vec<_>, Vec<_>) = {
        let mut pairs = private_keys
            .iter()
            .zip(public_keys.clone())
            .choose_multiple(&mut rand::thread_rng(), 50);

        // contract requires signers to be sorted by public key
        pairs.sort_by(|(_, pk1), (_, pk2)| pk1.cmp(pk2));

        pairs.into_iter().unzip()
    };

    // Sign abi-encoded operation with the chosen keys
    let signature = sign_message(&keys, &operation.abi_encode());

    // Send the signed operation to the contract along with the list of signers
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

    Ok(())
}

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
