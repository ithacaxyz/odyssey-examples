# Simple 7702 demo to pay gas fee using ERC20

This example demonstrates how EIP-7702 allows Alice to authorize a smart contract to execute an ERC20 transfer and pay fee in ERC20 to Bob, who sponsors the gas fees for a seamless experience.

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
export BOB_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
export CHARLES_ADDRESS="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
```

- Deploy ERC20 and mint tokens
```bash
forge create TestERC20 --private-key $BOB_PK
export ERC20=<ERC20 addr>
cast send $ERC20 'mint(address,uint256)' $ALICE_ADDRESS 10000000000000000000 --private-key $BOB_PK # 10E9 tokens
cast call $ERC20 'balance(address)' $ALICE_ADDRESS
```

- We need to deploy a contract which verifies the user signature and execute ERC20 transfers.:

```bash
forge create ERC20Fee --private-key $BOB_PK

export ERC20_FEE="<enter-contract-address>"
```

- Alice (delegator) can sign a message which will delegate all calls to her address to the bytecode of smart contract we've just deployed.

First, let's verify that we don't have a smart contract yet associated to Alice's account, if that's the case the command below should return a `0x` response: 

```bash
$ cast code $ALICE_ADDRESS
0x
```


- Alice can sign an EIP-7702 authorization using `cast wallet sign-auth` as follows:

```bash
SIGNED_AUTH=$(cast wallet sign-auth $ERC20_FEE --private-key $ALICE_PK)
```

- Alice can sign an off-chain data to authorize anyone to send ERC20 on behave of Alice in exchange of ERC20 fee

```bash
SIGNED=$(cast wallet sign --no-hash $(cast keccak256 $(cast abi-encode 'f(uint256,address,address,uint256,uint256)' 0 $ERC20 $CHARLES_ADDRESS 1000000000000000000 1000)) --private-key $ALICE_PK)
V=$(echo $SIGNED | cut -b 1-2,131-132)
R=$(echo $SIGNED | cut -b 1-66)
S=$(echo $SIGNED | cut -b 1-2,67-130)
```

- Bob (delegate) relays the transaction on Alice's behalf using his own private key and thereby paying gas fee from his account and get the ERC20 fee:

```bash
cast send $ALICE_ADDRESS "sendERC20(address,address,uint256,uint256,uint8,bytes32,bytes32)" $ERC20 $CHARLES_ADDRESS 1000000000000000000 1000 $V $R $S  --private-key $BOB_PK --auth $SIGNED_AUTH
```

- Bob will receive the ERC20 token as the fee, and Charles will receive the ERC20 token
```bash
cast call $ERC20 "balance(address)" $BOB_ADDRESS
cast call $ERC20 "balance(address)" $CHARLES_ADDRESS
```

