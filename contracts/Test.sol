// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.4.0 <0.8.0;

contract Test {

    bytes32[] public theByte;
    function Alter() public{
        theByte.push(keccak256(abi.encode(block.timestamp)));
    }
    

    fallback() external payable{}
    receive() external payable{}

}