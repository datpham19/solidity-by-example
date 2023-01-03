// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ViewAndPure {
    uint public x = 1;
    //Both of these don't cost any gas to call if they're called externally from outside the contract
    //(but they do cost gas if called internally by another function).

    // Promise not to modify the state.
    // view tells us that by running the function, no data will be saved/changed.
    function addToX(uint y) public view returns (uint) {
        return x + y;
    }

    // Promise not to modify or read from the state.
    // pure tells us that not only does the function not save any data to the blockchain,
    // but it also doesn't read any data from the blockchain.
    function add(uint i, uint j) public pure returns (uint) {
        return i + j;
    }
}
