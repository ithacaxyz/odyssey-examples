// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IERC20 {
    function transfer(address _to, uint256 _value) external returns (bool success);
}

contract TestERC20 {
    mapping (address => uint256) public balance;

    function transfer(address _to, uint256 _value) public returns (bool success) {
        balance[msg.sender] -= _value;
        balance[_to] += _value;
        return true;
    }

    function mint(address _to, uint256 _value) public {
        balance[_to] += _value;
    }
}

/// @notice Contract designed for being delegated to by EOAs to authorize an ERC20 transfer with ERC20 as fee.
contract ERC20Fee {

    /// @notice Internal nonce used for replay protection, must be tracked and included into prehashed message.
    uint256 public nonce;

    /// @notice Main entrypoint to send tx.
    function sendERC20(IERC20 token, address to, uint256 amount, uint256 fee, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 digest = keccak256(abi.encode(nonce++, token, to, amount, fee));
        address addr = ecrecover(digest, v, r, s);

        require(addr == address(this));

        require(token.transfer(msg.sender, fee));
        require(token.transfer(to, amount));
    }
}