// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract BillOP{

    enum OperationType{ Issue, Transfer, Split, Finance, Writeoff}
    OperationType opType;

    constructor(OperationType _opType) public{
        opType = _opType;
    }

    

}