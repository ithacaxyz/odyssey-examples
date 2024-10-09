from web3 import AsyncWeb3
import pathlib
import asyncio
import json
import subprocess
import random
from py_ecc.bls import G2Basic
from py_ecc.bls import g2_primitives
import eth_abi

Fp = tuple[int, int]
Fp2 = tuple[Fp, Fp]
G1Point = tuple[Fp, Fp]
G2Point = tuple[Fp2, Fp2]
Operation = tuple[str, str, int, int]


def fp_from_int(x: int) -> Fp:
    b = x.to_bytes(64, "big")
    return (int.from_bytes(b[:32], "big"), int.from_bytes(b[32:], "big"))


def generate_keys(num: int) -> list[tuple[G1Point, int]]:
    keypairs = []
    for _ in range(num):
        sk = random.randint(0, 10**30)
        pk_point = g2_primitives.pubkey_to_G1(G2Basic.SkToPk(sk))

        pk = (fp_from_int(int(pk_point[0])), fp_from_int(int(pk_point[1])))

        keypairs.append((pk, sk))

    keypairs.sort()

    return keypairs


def sign_operation(sks: list[int], operation: Operation) -> G2Point:
    encoded = eth_abi.encode(["(address,bytes,uint256,uint256)"], [operation])

    signatures = []
    for sk in sks:
        signatures.append(G2Basic.Sign(sk, encoded))

    aggregated = g2_primitives.signature_to_G2(G2Basic.Aggregate(signatures))

    signature = (
        (fp_from_int(aggregated[0].coeffs[0]), fp_from_int(aggregated[0].coeffs[1])),
        (fp_from_int(aggregated[1].coeffs[0]), fp_from_int(aggregated[1].coeffs[1])),
    )

    return signature


async def main():
    bls_multisig_artifact = json.load(
        open(pathlib.Path(__file__).parent.parent.parent.parent / "out/BLSMultisig.sol/BLSMultisig.json")
    )

    web3 = AsyncWeb3(AsyncWeb3.AsyncHTTPProvider("http://localhost:8545"))

    bytecode = bls_multisig_artifact["bytecode"]["object"]
    abi = bls_multisig_artifact["abi"]
    BlsMultisig = web3.eth.contract(abi=abi, bytecode=bytecode)

    signer = (await web3.eth.accounts)[0]

    # generate 100 BLS keys
    keypairs = generate_keys(100)
    pks = list(map(lambda x: x[0], keypairs))

    # deploy the multisig contract with generated signers and threshold of 50
    tx = await BlsMultisig.constructor(pks, 50).transact({"from": signer})
    receipt = await web3.eth.wait_for_transaction_receipt(tx)
    multisig = BlsMultisig(receipt.contractAddress)

    # fund the multisig
    hash = await web3.eth.send_transaction({"from": signer, "to": multisig.address, "value": 10**18})
    await web3.eth.wait_for_transaction_receipt(hash)

    # create an operation transferring 1 eth to zero address
    operation: Operation = ("0x0000000000000000000000000000000000000000", bytes(), 10**18, 0)

    # choose 50 random signers that will sign the operation
    signers_subset = sorted(random.sample(keypairs, 50))

    pks = list(map(lambda x: x[0], signers_subset))
    sks = list(map(lambda x: x[1], signers_subset))

    # create aggregated signature for operation
    signature = sign_operation(sks, operation)

    # execute the operation
    tx = await multisig.functions.verifyAndExecute((operation, pks, signature)).transact({"from": signer})
    receipt = await web3.eth.wait_for_transaction_receipt(tx)

    assert receipt.status == 1


if __name__ == "__main__":
    try:
        anvil = subprocess.Popen(["anvil", "--alphanet"], stdout=subprocess.PIPE)
        asyncio.run(main())
    finally:
        anvil.terminate()
