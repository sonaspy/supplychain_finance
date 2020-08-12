// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract Supplier{


    bytes32 supplierID;
    uint level;
    bytes32 name;
    address companyConAddr;

    constructor(address _companyConAddr, bytes32 _supplierID, bytes32 _name, uint _level) public{
        companyConAddr = _companyConAddr;
        supplierID = _supplierID;
        name = _name;
        level = _level;
    }

    

}