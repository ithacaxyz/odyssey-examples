# Simple delegate transactions with 7702

Onboarding novices onto Ethereum can be challenging: Users need to create a new wallet, buy some ETH for gas before they can send their first transaction. [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) unlocks features such as gas sponsorship, but also other use cases such as transaction bundling or granting limited permissions to a sub-key. This EIP introduces a new transaction type, allowing an Externally Owned Account (EOA) to function like a smart contract. Essentially, the way it works is that we can associate smart contract bytecode with an EOA account, allowing the EOA to act like a smart contract.

This example demonstrates how EIP-7702 allows Alice to authorize a smart contract to execute a transaction on her behalf, with Bob sponsoring the gas fees for a seamless experience.

## Steps involved

- Start local anvil node with Odyssey features enabled

```bash
anvil --odyssey
```

- Anvil comes with pre-funded developer accounts which we can use for the example going forward

```bash
# using anvil dev accounts 
export ALICE_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export ALICE_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
export BOB_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
```

- We need to deploy a contract which delegates calls from the user and executes on their behalf. The contract itself is very basic, it will delegate the call and emit an `Executed` event for debugging purposes:

```bash
forge create SimpleDelegateContract --private-key $BOB_PK

export SIMPLE_DELEGATE_ADDRESS="<enter-contract-address>"
```

- Alice (delegator) can sign a message which will delegate all calls to her address to the bytecode of smart contract we've just deployed.

First, let's verify that we don't have a smart contract yet associated to Alice's account, if that's the case the command below should return a `0x` response: 

```bash
$ cast code $ALICE_ADDRESS
0x
```

- Alice can sign an EIP-7702 authorization using `cast wallet sign-auth` as follows:

```bash
SIGNED_AUTH=$(cast wallet sign-auth $SIMPLE_DELEGATE_ADDRESS --private-key $ALICE_PK)
```

- Bob (delegate) relays the transaction on Alice's behalf using his own private key and thereby paying gas fee from his account:

```bash
cast send $ALICE_ADDRESS "execute((bytes,address,uint256)[])" "[("0x",$(cast az),0)]" --private-key $BOB_PK --auth $SIGNED_AUTH
```

This is done by passing the `--auth` flag, which can accept either an address or an encoded authorization. The transaction above would firstly apply a signed authorization, making Alice’s EOA have bytecode that delegates to a deployed contract. After that it will be executed as a call to Alice whose code would already include the newly added bytecode, allowing us to successfully call `execute` and transact on her behalf.

- Verify that our command was successful, by checking Alice's code which now contains the [delegation designation](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7702.md#delegation-designation) prefix `0xef01`:

```bash
$ cast code $ALICE_ADDRESS
0xef0100...
```

Note that in this over-simplified example, you’ll already see some issues e.g. anyone could send the transaction to any address on Alice's behalf, since there’s no such restriction in the signed authorization. To address this issue, you would need to add additional setup functions which would be called on user's bytecode once delegation has been applied.

## Testing with foundry

To test this delegation feature, you may use the `vm.etch` cheatcode in your tests as follows: 

```solidity
// this will inject delegation designation into ALICE's code
vm.etch(ALICE, bytes.concat(hex"ef0100", abi.encodePacked(contractToDelegate)));
```

This cheat code allows you to **simulate that ALICE's account is no longer a regular EOA but a contract**(like `P256Delegation`) and then test how delegations or transactions behave from that new "smart contract" EOA.

You can check out the complete example in [SimpleDelegateContract.t.sol](../contracts/test/SimpleDelegateContract.t.sol)
