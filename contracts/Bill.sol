// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract Bill{

    enum BillState{Unissue, Issuing, Issued, Financing, Financed, Invalid, Spliting, Splited, Transfering, Transfered}
    BillState billstate;
    
    bytes32 public billID;

    uint public issuedTime;

    uint public expiredTime;

    address public owner;

    address public issuer;

    address[] billOperationAddrs;

    uint public faceValue;


    constructor(bytes32 _billID, uint _issuedTime, uint _expiredTime, address _owner, uint _faceValue, BillState _state) public{

        issuer = msg.sender;
        billID = _billID;
        issuedTime = _issuedTime;
        expiredTime = _expiredTime;
        owner = _owner;
        faceValue = _faceValue;
        billstate = _state;
        
    }

}