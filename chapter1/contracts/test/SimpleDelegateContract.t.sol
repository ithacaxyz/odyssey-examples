// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {SimpleDelegateContract} from "../src/SimpleDelegateContract.sol";

contract SimpleDelegateContractTest is Test {
    function test() public {
        address payable ALICE = payable(address(0xa11ce));
        SimpleDelegateContract delegation = new SimpleDelegateContract();

        // let's inject EIP-7702 delegation designation into ALICE's code to
        // make it forward all calls to the deployed contract
        vm.etch(ALICE, bytes.concat(hex"ef0100", abi.encodePacked(delegation)));

        ALICE.call{value: 1e18}("");

        SimpleDelegateContract.Call[] memory calls = new SimpleDelegateContract.Call[](1);
        calls[0] = SimpleDelegateContract.Call({data: "", to: address(0), value: 1e18});

        SimpleDelegateContract(ALICE).execute(calls);
    }
}
