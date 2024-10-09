# Simple delegate transactions with 7702

EIP-7702 allows an Externally Owned Accounts (EOAs) to function like a smart contract. This unlocks features such as gas sponsorship, transaction bundling or granting limited permissions to a sub-key.

## Scenario

Imagine a DeFi protocol wants to enable gas sponsoring for its users, to improve the UX of their product. To do this, Alice can submit an authorization message to a smart contract which maybe be broadcasted by Bob, who will sponsor gas. This example will walk you through how EIP-7702 can be used to submit a transaction via delegate. 

## Steps involved

- Start local anvil node with Odyssey features enabled

```bash
anvil --odyssey
```

- Anvil comes with developer accounts pre-funded, with the commands below we will go ahead and use them

```bash
# using anvil dev accounts 
export ALICE_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
export ALICE_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
export BOB_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
```

- Deploy a contract which delegates calls from the user and executes on their behalf. The contract itself is very basic, it will delegate the call and emit an `Executed` event:

```bash
# deploy sample DelegateContract using anvil dev accounts
forge create contracts/SimpleDelegateContract.sol:SimpleDelegateContract --private-key $ALICE_PK

export SIMPLE_DELEGATE_ADDRESS="<enter contract address>"
```

- Alice (delegator) delegates authority to a smart contract to send specific transactions from her account by signing the following message. For this she can use `cast wallet sign-auth` to sign an EIP-7702 sign authorization:

```bash
SIGNED_AUTH=$(cast wallet sign-auth $SIMPLE_DELEGATE_ADDRESS --private-key $ALICE_PK)
```

- Bob (delegate) can relay the transaction on Alice's behalf using his own private key and thereby paying gas fee from his account:

```bash
cast send $ALICE_ADDRESS "execute((bytes,address,uint256)[])" "[("0x",$(cast az),0)]" --private-key $BOB_PK --auth $SIGNED_AUTH
```

This is done by passing `--auth` flag, which can accept either an address or an encoded authorization. The transaction above would firstly apply a signed authorization, making Alice’s EOA to have bytecode delegating to deployed contract. After that it will be executed as a call to Alice which code would already include the newly added bytecode, allowing us to succesfully call `execute` and transact on her behalf.

Note that in this over-simplified example, you’ll already see some issues e.g. Bob the relayer can technically send the transaction to any address, since there’s no restriction of the delegator or expiry date. To address this you would need to add additional setup functions which would be called on user's bytecode once delegation has been applied.

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