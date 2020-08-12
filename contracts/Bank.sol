// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract Bank{


    constructor(uint _discountRate, bytes32 _bankID) public{
        discountRate = _discountRate;
        bankID = _bankID;
    }

    uint public discountRate;
    bytes32 public bankID;


}