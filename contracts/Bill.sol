// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract Bill{

    constructor() internal{

    }

    enum BillState{Unissue, Issuing, Issued, Cashing, Cashed, Invalid, Spliting, Splited, Transfering, Transfered}
    BillState billstate;
    
    bytes32 public billID;

    uint public issuedTime;

    uint public expiringTime;

    address public owner;

    address public issuer;

    address[] billOperationAddrs;

    uint public claim_amount;

}