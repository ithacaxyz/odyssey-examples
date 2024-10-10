# EOF

## Context
EOF (Ethereum Object Format) is a series of EIPs which aim to improve effenciency & security of smart contract deployment & execution. EOF introduces a new binary format for smart contracts on the Ethereum blockchain.

## How to compile for EOF
Support for EOF compilation is avaiable natively in [foundry](https://github.com/foundry-rs/foundry).

Compile the contracts with EOF, using the `--eof` flag. Note that this will pull a docker image and might take a while to download on the first iteration
```bash
forge build --eof 
```

Deploy a contract with EOF
```bash
forge create P256Delegation --private-key $PK --eof
```

Verify that deployed contract is in EOF format
```bash
$ cast code <contract address>
0xef000...
```

`0xef00` prefix indicates that contract was deployed with EOF.


## Inspecting EOF

EOF defines separation of bytecode into sections which include header, code sections, container sections and data sections.

Let's take a look at such simple contract:
```solidity
contract Simple {}

contract EOFCompiled {
    bytes32 public immutable DATA = hex"1234567890";

    function deploySimple() public returns (address) {
        return address(new Simple());
    }
}

```

Let's now deploy it and inspect the bytecode:
```bash
$ forge create EOFCompiled --private-key $PK --eof
$ cast decode-eof $(cast code <address>)

Header:
+------------------------+-------+
| type_size              | 4     |
|------------------------+-------|
| num_code_sections      | 1     |
|------------------------+-------|
| code_sizes             | [137] |
|------------------------+-------|
| num_container_sections | 1     |
|------------------------+-------|
| container_sizes        | [167] |
|------------------------+-------|
| data_size              | 136   |
+------------------------+-------+

Code sections:
+---+--------+---------+------------------+-----------------------------------------------------------------------------------+
|   | Inputs | Outputs | Max stack height | Code                                                                              |
+=============================================================================================================================+
| 0 | 0      | 128     | 6                | 0x6080806040526004361015e100035f80fd5f3560e01c908163a3f4df7e14e1004b5063ecb63dd31 |
|   |        |         |                  | 4e100045fe0ffdf34e100365f600319360112e100295f6040518180ec008015e10012602090604051 |
|   |        |         |                  | 9060018060a01b03168152f36040513d5f823e3d90fd5f80fd5f80fd34e100165f600319360112e10 |
|   |        |         |                  | 009602090d100688152f35f80fd5f80fd                                                 |
+---+--------+---------+------------------+-----------------------------------------------------------------------------------+

Container sections:
+---+-------------------------------------------------------------------------------------------------------------------------+
| 0 | 0xef00010100040200010011030001007e0400000000800002608060405234e100055f6080ee005f80fdef000101000402000100030400680000800 |
|   | 0025f80fda36469706673582212204adab3acae2aadb7ce31bad828a83a466c16b941e83e3517eb1a0707b3e9e1326c6578706572696d656e74616c |
|   | f564736f6c637827302e382e32372d646576656c6f702e323032342e382e352b636f6d6d69742e38386366363036300066                      |
+---+-------------------------------------------------------------------------------------------------------------------------+

Data section:
+-----------------------------------------------------------------------------------------------------------------------------+
| 0xa3646970667358221220275630b519861317bba9915386f5dcf25b713a85bf76680d89ddb2cab9e8c44a6c6578706572696d656e74616cf564736f6c6 |
| 37827302e382e32372d646576656c6f702e323032342e382e352b636f6d6d69742e38386366363036300066123456789000000000000000000000000000 |
| 0000000000000000000000000000                                                                                                |
+-----------------------------------------------------------------------------------------------------------------------------+
```

We can see that contract has 1 container section. Container sections are used to store so-called subcontainers — contracts which can be deployed from our contract via `EOFCREATE` opcode. In this case our contract has a method deploying `Simple` contract, so we have a single subcontainer.

We can also see that our immutable `DATA` was placed into the data section. Data section is a separate part of bytecode which can store arbitrary immutable data which can be accessed via special `DATALOAD*` opcodes. The rest of the data section is contract metadata.

Deployed contract also has a single code section. Code sections are similar to functions. They accept fixed number of inputs and return fixed number of outputs. In this case optimizer decided to only include a single code section, but if you will try disabling the optimizer (with `--optimize=false`) you will see that without it we have 18 code sections each of which keeps either external function or internal compiler logic.


## Gas usage

Contracts compiled for EOF tend to consume less gas. You can verify this yourself by running tests in this repository:

```bash
$ forge test
Ran 1 test for contracts/test/SimpleDelegateContract.t.sol:SimpleDelegateContractTest
[PASS] test() (gas: 301928)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.87ms (2.15ms CPU time)

Ran 1 test for contracts/test/P256.t.sol:BLSTest
[PASS] test() (gas: 8951)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 8.86ms (4.14ms CPU time)

Ran 2 tests for contracts/test/BLS.t.sol:BLSTest
[PASS] test() (gas: 321781)
[PASS] testAggregated() (gas: 439327)

$ forge test --eof
Ran 1 test for contracts/test/SimpleDelegateContract.t.sol:SimpleDelegateContractTest
[PASS] test() (gas: 261751)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 9.37ms (2.47ms CPU time)

Ran 1 test for contracts/test/P256.t.sol:BLSTest
[PASS] test() (gas: 8191)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 11.44ms (4.54ms CPU time)

Ran 2 tests for contracts/test/BLS.t.sol:BLSTest
[PASS] test() (gas: 314754)
[PASS] testAggregated() (gas: 425091)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 12.74ms (11.11ms CPU time)
```

As you can see, EOF-compiled contracts are 5-10% more gas efficient.

## Limitations

EOF disables a number of opcodes. Right now, if your contract contains any of those it will get compiled but will not be deployable.

The banned opcodes are:
- Code introspection opcodes: `CODESIZE`, `CODECOPY`, `EXTCODESIZE`, `EXTCODECOPY`, `EXTCODEHASH`
- Dynamic jumps: `JUMP`, `JUMPI`, `PC`
- Gas introspection opcodes: `GAS`, `GASLIMIT`, `GASPRICE`
- Legacy call instructions: `CREATE`, `CALL`, `DELEGATECALL`, `CREATE2`, `STATICCALL`
- Legacy opcodes: `SELFDESTRUCT`, `CALLCODE`

Your contracts are likely to get affected by `EXTCODESIZE` ban, because it made checks like `address(...).code.length > 0` impossible. Another common pattern is calls/staticcalls in low-level assembly. Those would need to either be cahnged to high-level calls or changed to `ext*` instructions. i.e
```solidity
assembly {
    call(gas(), to, value, offset, size, retOffset, retSize)
}
```
would become
```solidity
assembly {
    extcall(to, offset, size, value)
}
```

Additionally, EOF call instructions return 0 on success and not on failure. For more context, check out the [corresponding EIP](https://eips.ethereum.org/EIPS/eip-7069).
