// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;
import "./Supplier.sol";

// Core Company
contract Company{


    address[] supplierConAddrs;
    address[] financedBillAddrs;
    address[] billOperations;

    constructor() public{

    }

    function createSupplier(address _companyConAddr,bytes32 _supplierID, uint _level,
                            bytes32 _supplierName) public returns(address){
        Supplier supplier = new Supplier(_companyConAddr, _supplierID, _supplierName, _level);
        supplierConAddrs.push(address(supplier));
        return address(supplier);
    }

    function addFinancedBillAddr(address _financedBillAddr) public {
        financedBillAddrs.push(_financedBillAddr);
    }

    function addBillOperation(address _billOperation) public {
        billOperations.push(_billOperation);
    }

}