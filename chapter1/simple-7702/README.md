# Simple delegate transactions with 7702

Imagine a DeFi protocol wants to enable gas sponsoring for its users, to improve the UX of their product. To do this, Alice can submit an authorization message to a smart contract. Bob can broadcast the message on Alice's behalf and sponsor gas for her transaction.

[EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) paths the way for account abstraction, which will revolutionize on-chain user experience. This EIP introduces a new transaction type, allowing an Externally Owned Accounts (EOAs) to function like a smart contract. This unlocks features such as gas sponsorship, transaction bundling or granting limited permissions to a sub-key. Essentially the way it works is that we can associate smart contract byte code with an EOA account, the EOA can then temporarily act like a smart contract.

This example will walk you through how EIP-7702 can be used to submit a transaction via delegate. 

## Steps involved

- Start local anvil node with Odyssey features enabled

```bash
anvil --odyssey
```

- Anvil comes with developer accounts pre-funded, with the commands below we will go ahead and use them

```bash
# using anvil dev accounts 
export ALICE_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export ALICE_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
export BOB_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
```

- Deploy a contract which delegates calls from the user and executes on their behalf. The contract itself is very basic, it will delegate the call and emit an `Executed` event for debugging purposes:

```bash
forge create contracts/SimpleDelegateContract.sol:SimpleDelegateContract --private-key $ALICE_PK

export SIMPLE_DELEGATE_ADDRESS="<enter-contract-address>"
```

- Alice (delegator) can delegate authority to a smart contract to send specific transactions from her account by signing the following message. First, let's verify that we don't have a smart contract yet associated to Alice's account, if that's the case the command below should return a `0x` response: 

```bash
$ cast code $ALICE_ADDRESS
0x
```

- Alice can sign an EIP-7702 sign authorization using `cast wallet sign-auth` as follows:

```bash
SIGNED_AUTH=$(cast wallet sign-auth $SIMPLE_DELEGATE_ADDRESS --private-key $ALICE_PK)
```

- Bob (delegate) relays the transaction on Alice's behalf using his own private key and thereby paying gas fee from his account:

```bash
cast send $ALICE_ADDRESS "execute((bytes,address,uint256)[])" "[("0x",$(cast az),0)]" --private-key $BOB_PK --auth $SIGNED_AUTH
```

This is done by passing `--auth` flag, which can accept either an address or an encoded authorization. The transaction above would firstly apply a signed authorization, making Alice’s EOA to have bytecode delegating to deployed contract. After that it will be executed as a call to Alice which code would already include the newly added bytecode, allowing us to succesfully call `execute` and transact on her behalf.

- Verify that new our command was successful, by checking Alice's code which now contains the [delegation designation](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7702.md#delegation-designation) prefix `0xef`:

```bash
$ cast code $ALICE_ADDRESS
0xef0100...
```

Note that in this over-simplified example, you’ll already see some issues e.g. Bob could send the transaction to any address, since there’s such restriction in the signed authorization. To address this issue, you would need to add additional setup functions which would be called on user's bytecode once delegation has been applied.

## Testing with foundry

To test this delegation feature, you may use the `vm.etch` cheatcode in your tests as follows: 

```bash
import {Test} from "forge-std/Test.sol";
import {SimpleDelegateContract} from "../src/SimpleDelegateContract.sol";

contract DelegationTest is Test {
    function test() public {
        SimpleDelegateContract delegation = new SimpleDelegateContract();
        // this sets ALICE's EOA code to the deployed contract code
        vm.etch(ALICE, address(delegation).code);
    }
}
```

This cheat code allows you to **simulate that ALICE's account is no longer a regular EOA but a contract**(like `P256Delegation`) and then test how delegations or transactions behave from that new "smart contract" EOA.