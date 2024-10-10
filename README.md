# Odyssey Examples

## Overview

This repository provides a step-by-step walk through for builders interested in the developer-preview features available on [Odyssey](https://www.ithaca.xyz/updates/introducing-ithaca). Each chapter provides examples of new features added. 

## Chapter 1 
- [Simple Example for EIP-7702](./chapter1/simple-7702/): Basic example to showcase how EIP-7702 transactions work
- [Delegate Account to p256 key](./chapter1/delegate-p256/): Step-by-step walk-through of how EIP-7702+EIP-7212 provide the ability to sign a message with a P256 key
- [BLS Multisig](./chapter1/bls-multisig/): Examples in Python and Rust to showcase Multisig based on BLS signatures verified through precompiles from EIP-2537
- [EOF](./chapter1/eof/): Instructions on how to deploy and inspect contracts in the new EOF format

## Build & Run

Use foundry to build and run smart contracts in the repo  

```bash
# Make sure foundry is up to date
foundryup

# Compile contracts and run tests in chapter 1
cd chapter1
forge build
forge test
````