# Python Alphanet Multisig

This example demonstrates an integration of [BlsMultisig](../../../src/BLSMultisig.sol) with Python.

## Running the example

To run the example, you will need to install the required dependencies:

```shell
pip install web3 py_ecc
```

Then, you can run the example by executing the following command:

```shell
python multisig.py
```

This will spin up an Anvil instance in Alphanet mode, deploy the multisig contract and execute a simple operation signed by random BLS keys.