pragma solidity 0.8.17;

contract Encode {

    function encode(address _address, uint _uint) public pure returns (bytes memory) {
        bytes memory encoded = abi.encode(_address, _uint);
        return encoded;
    }

    function decode(bytes memory data) public pure returns (address _address, uint _uint) {
        (_address, _uint) = abi.decode(data, (address, uint));
    }
}