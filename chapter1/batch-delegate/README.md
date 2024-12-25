# Batch Delegate Authorization Example

This example demonstrates how to perform batch delegation authorization using EIP-7702. It allows a user to authorize multiple delegates to execute transactions on their behalf.

## Steps involved

- Start a local Anvil node with Odyssey features enabled: 

```bash
anvil --odyssey
```

- Set up environment variables for the accounts:
```bash
export ALICE_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export ALICE_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
export BOB_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
export CHARLIE_PK="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
```

- Deploy a batch delegate contract:

```bash
forge create BatchDelegateContract --private-key $BOB_PK
```
- Authorize multiple delegates:
```bash
SIGNED_AUTH=$(cast wallet sign-auth $BATCH_DELEGATE_ADDRESS --private-key $ALICE_PK)
```

- Execute a batch transaction on behalf of Alice:
```bash
cast send $ALICE_ADDRESS "executeBatch((bytes,address,uint256)[])" "[("0x",$(cast az),0),("0x",$(cast az),0)]" --private-key $BOB_PK --auth $SIGNED_AUTH
```

- Verify that the batch transaction was successful:

```bash
cast code $ALICE_ADDRESS
```