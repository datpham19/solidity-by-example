// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Constants {
    // coding convention to uppercase constant variables
    // Constants are variables that cannot be modified.
    // Their value is hard coded and using constants **can save** gas cost.
    address public constant MY_ADDRESS = 0x777788889999AaAAbBbbCcccddDdeeeEfFFfCcCc;
    uint public constant MY_UINT = 123;
}

contract Immutable {
    // coding convention to uppercase constant variables

    // Immutable variables are like constants.
    // Values of immutable variables can be set inside the constructor but cannot be modified afterwards.
    address public immutable MY_ADDRESS;
    uint public immutable MY_UINT;

    constructor(uint _myUint) {
        MY_ADDRESS = msg.sender;
        MY_UINT = _myUint;
    }
}