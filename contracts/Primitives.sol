// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract NonNegativeInteger {
    bool public boo = true;
    /*
    uint stands for unsigned integer, meaning non negative integers
    different sizes are available
        uint8   ranges from 0 to 2 ** 8 - 1
        uint16  ranges from 0 to 2 ** 16 - 1
        ...
        uint256 ranges from 0 to 2 ** 256 - 1
    */
    uint public u = 1;
    uint public u256 = 456;
    uint public u128= 123; // uint is an alias for uint256
}

contract NegativeInteger {
    /*
    Negative numbers are allowed for int types.
    Like uint, different ranges are available from int8 to int256

    int256 ranges from -2 ** 255 to 2 ** 255 - 1
    int128 ranges from -2 ** 127 to 2 ** 127 - 1
    */
    int8 public i8 = -1;
    int public i256 = 456;
    int public i = -123; // int is same as int256

}

contract Primitives {
    // minimum and maximum of int
    int public minInt = type(int).min;
    int public maxInt = type(int).max;

    address public addr = 0xEf9307fD512C94483A2D672B2306D6751643aF64;

    /*
    In Solidity, the data type byte represent a sequence of bytes.
    Solidity presents two type of bytes types :

     - fixed-sized byte arrays
     - dynamically-sized byte arrays.

     The term bytes in Solidity represents a dynamic array of bytes.
     It’s a shorthand for byte[] .
    */
    bytes1 a = 0xb5; //  [10110101] Dynamic array of bytes: 86 in decimal
    bytes1 b = 0x56; //  [01010110] : 181 in decimal

    // Default values
    // Unassigned variables have a default value
    bool public defaultBoo; // false
    uint public defaultUint; // 0
    int public defaultInt; // 0
    address public defaultAddr; // 0x0000000000000000000000000000000000000000
}