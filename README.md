# Odyssey Examples

This repository provides a step-by-step walk through for builders interested in the developer-preview features available on [Odyssey](https://www.ithaca.xyz/updates/introducing-ithaca), a L2 built for developers to innovate. We are rolling out each Chapter with new features for you to build on. 

### Chapter 1 
- [Simple Example for EIP-7702](./chapter1/simple-7702/): Showcases how EIP-7702 transactions work
- [Delegate an account to a p256 key](./chapter1/delegate-p256/): Describes how EIP-7702+EIP-7212 provide the ability to sign a message with a P256 key
- [BLS Multisig](./chapter1/bls-multisig/): In-depth walk-through how to implement a Multisig based on BLS signatures verified through precompiles from EIP-2537
- [EOF](./chapter1/eof/): Instructions on how to deploy and inspect contracts in the new EOF format
- [ERC20 Fee](./chapter1/erc20-fee/): Describes how EIP-7702 provides the ability to pay ERC20 as gas fee to the gas sponsor.

### Build & Test

Use [foundry](https://github.com/foundry-rs/foundry) to build and run smart contracts in the repository:  

```bash
# Make sure foundry is up to date
foundryup

# Compile contracts and run tests in chapter 1
cd chapter1/
forge build
forge test
````
