// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.4.0 <0.8.0;

contract Finance {
    

    enum BillState{Valid, Split, Expired, Done} // Expired: not not writed off yet ; Done: already writed off.
    
    
    struct TradeDebtBill{
        bytes32 id;
        bytes32 issuer;
        uint facevalue;
        uint expire_time;
        BillState state;
        bytes32 idOfCR; // id of CashReceipt correspondingly. 0x0 means is not writed off yet or still valid.
        bytes32 idOfparent;
        bytes32[] idOfsons; // if it is split, store id of its sons to here.  
        bytes32[] froms;
        bytes32[] tos;
        uint[] times;
    }
    
    
    struct CashReceipt{
        bytes32 id;
        uint amount;
        bytes32 idOfTDB; // ID of TradeDebtBill that is writed off correspondingly.
        bytes32 from;
        bytes32 to;
    }
    
    
    struct Arbitral {
        bytes32 _id;
        address _address;
    }
    
    
    struct Bank {
        bytes32 id;
        uint rate1;
        uint rate2;
        string name;
    }


    struct Enterprise {
        bytes32 id;
        uint totalDebt;
        string name;
    }
    
    
    struct Supplier {
        bytes32 id;
        uint8 level;
        string name;
    }
    
    Arbitral public theArbitral;
     
    mapping(bytes32 => CashReceipt) mapOfCashReceipt;
    mapping(bytes32 => TradeDebtBill) mapOfTradeDebtBill;
    mapping(bytes32 => Enterprise) mapOfEnterprise;
    mapping(bytes32 => Bank) mapOfBank;
    mapping(bytes32 => Supplier) mapOfSupplier;
    
    TradeDebtBill[] public Bills;
    // TradeDebtBill[] public doneBills;
   
    Enterprise[] public enterprises;
    Bank[] public banks;
    Supplier[] public suppliers;
    
    
    constructor(bytes32 id){
        theArbitral = Arbitral({
            _id: id,
            _address: msg.sender
        });
    }
    
    
    modifier onlytheArbitral{
        require(msg.sender == theArbitral._address, "Only arbitral can operate");
        _;
    }
    
    
    function addBank(bytes32 bankid, uint r1, uint r2, string memory _name) onlytheArbitral public returns(bool, string memory) {

        banks.push(Bank({
            id: bankid, 
            rate1: r1,
            rate2: r2,
            name: _name
        }));

        mapOfBank[bankid] = banks[banks.length - 1];
        return (true, "success");
    }
    
    
    function addEnterprise(bytes32 epid, string memory _name) onlytheArbitral public returns(bool, string memory) {
        
        enterprises.push(Enterprise({
            id: epid, 
            totalDebt: 0,
            name: _name
        }));

        mapOfEnterprise[epid] = enterprises[enterprises.length - 1];
        return (true, "success");
    }
    
    
    function addSupplier(bytes32 spid, uint8 _level, string memory _name) onlytheArbitral public returns(bool, string memory) {

        suppliers.push(Supplier({
            id: spid, 
            level:_level,
            name: _name
        }));

        mapOfSupplier[spid] = suppliers[suppliers.length - 1];
        return (true, "success");
    }
    
    
    function newTradeDebtBill(bytes32 _from, bytes32 _to, bytes32 _issuer, bytes32 _parentid,
                            uint _init_time, uint _facevalue, uint _expire_time) internal returns(bytes32){
                                
        bytes32 _id = keccak256(abi.encodePacked(block.timestamp, _from, _to));

        Bills.push(TradeDebtBill({
            id: _id,
            issuer: _issuer,
            facevalue: _facevalue,
            expire_time: _expire_time,
            state: BillState.Valid,
            idOfCR: 0x0,
            idOfsons: new bytes32[](0),
            froms: new bytes32[](0),
            tos: new bytes32[](0),
            times: new uint[](0),
            idOfparent: _parentid
        }));
        
        TradeDebtBill storage t = Bills[Bills.length - 1];
        mapOfTradeDebtBill[_id] = t;
        t.times.push(_init_time);
        t.froms.push(_from);
        t.tos.push(_to);

        return _id;
    }
    
    
    function newCashRecepit(bytes32 _from, bytes32 _to, bytes32 _idOfTDB, uint _amount) internal returns(bytes32){
        bytes32 _id = keccak256(abi.encodePacked(block.timestamp, _from, _to));
        
        CashReceipt memory c = CashReceipt({
           id: _id,
           idOfTDB: _idOfTDB,
           amount: _amount,
           from: _from,
           to: _to
        });
        
        mapOfCashReceipt[_id] = c;
        return _id;
    }
    
    
    function issueTradeDebtBill(bytes32 epid, bytes32 spid, uint tolerate_time, uint _facevalue) onlytheArbitral public returns(bool, bytes32, string memory){
        Enterprise storage e = mapOfEnterprise[epid];
        Supplier storage s = mapOfSupplier[spid];
        
        require(e.id != 0x0 && s.id != 0x0 && s.level == 1, 
                "Enterprise doesn't exist / Supplier doesn't exist / Supplier's level doesn't suffice");
        
        bytes32 id = newTradeDebtBill(epid, spid, epid, 0x0,block.timestamp, _facevalue, block.timestamp + tolerate_time);
        
        e.totalDebt += _facevalue;
        return (true, id, "success");
    }
    
    
    event billDueToRepay(bytes32 billid, bytes32 epid);
    
    function CheckUpdateBillState(bytes32 billid) internal returns(bool){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];

        require(b.id != 0x0, "Bill is not existed.");

        if(block.timestamp < b.expire_time) return true;

        if(b.state == BillState.Valid || b.state == BillState.Expired){
            b.state = BillState.Expired;
            emit billDueToRepay(billid, b.issuer);
        }

        return false;
    }
    
    
    function transferBillbetweenSuppliers(bytes32 spid1, bytes32 spid2, bytes32 billid) onlytheArbitral external returns(bool, string memory){
        Supplier storage s1 = mapOfSupplier[spid1];
        Supplier storage s2 = mapOfSupplier[spid2];
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];

        if(!CheckUpdateBillState(billid)){
            return(false, "failed");
        }

        require(s1.id != 0x0 && s2.id != 0x0 && b.state == BillState.Valid, 
                "Supplier1 doesn't exist / Supplier2 doesn't exist / Bill is Invalid");  

        uint ridx = b.froms.length - 1;
        require(b.tos[ridx] ==  spid1, "Bill doesn't belong to Supplier1");

        b.froms.push(spid1);
        b.tos.push(spid2);
        b.times.push(block.timestamp);

        return (true, "success");
    }
    
    
    function billSplitBySupplier(bytes32 billid, bytes32 spid, uint[] memory ways) onlytheArbitral external returns(bool, string memory, bytes32[10] memory){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        Supplier storage s = mapOfSupplier[spid];
        bytes32[10] memory newbillids;

        if(!CheckUpdateBillState(billid)){
            return(false, "failed", newbillids);
        }

        require(s.id != 0x0 && b.state == BillState.Valid, 
                "Supplier doesn't exist / Bill is Invalid");  

        uint ridx = b.froms.length - 1;
        require(b.tos[ridx] ==  spid && ways.length <= 10, "Bill doesn't belong to Supplier / split way isn't feasible.");

        uint sum = 0;
        for(uint i = 0; i < ways.length; i++){
            sum += ways[i];
        }
        require(sum == b.facevalue, "split way isn't feasible.");

        uint expire_time = b.expire_time;
        bytes32 issuer = b.issuer;
        bytes32 bid = billid;
        bytes32 sid = spid;
        bytes32 _from = b.froms[b.froms.length - 1];

        for(uint i = 0; i < ways.length; i++){
            uint v = ways[i];
            newbillids[i] = newTradeDebtBill(_from,sid,issuer,bid,block.timestamp,v,expire_time);
            b.idOfsons.push(newbillids[i]);
        }

        b.state = BillState.Split;
        
        return(true, "success", newbillids);
        
    }
    
    
    
    function supplierFinancingfromBank(bytes32 billid, bytes32 spid, bytes32 bankid) onlytheArbitral external returns(bool, string memory, bytes32){
        TradeDebtBill storage bi = mapOfTradeDebtBill[billid];
        Supplier storage s = mapOfSupplier[spid];
        Bank storage ba = mapOfBank[bankid];

        require(s.id != 0x0 && bi.id != 0x0 && ba.id != 0x0, 
                "Supplier doesn't exist / Bill doesn't exist / Bank doesn't exist");
        bytes32 newrepid;

        if(!CheckUpdateBillState(billid)){
            return(false, "failed", newrepid);
        }
        uint ridx = bi.froms.length - 1;

        require(bi.tos[ridx] ==  spid , "Bill doesn't belong to Supplier ");

        uint amount = bi.facevalue * ba.rate1 / ba.rate2;

        newrepid = newCashRecepit(bankid, spid, billid, amount);
        bi.froms.push(spid);
        bi.tos.push(bankid);
        bi.times.push(block.timestamp);
        bi.idOfCR = newrepid;
        
        return(true, "success", newrepid);

    }
    
    
    function enterpriseRepay(bytes32 billid, bytes32 epid) onlytheArbitral external returns(bool, string memory, bytes32){

        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        Enterprise storage e = mapOfEnterprise[epid];

        require(b.id != 0x0 && e.id != 0x0 && b.issuer == epid, " Bill doesn't exist / Enterprise doesn't exist / Bill is not issued by this Enterprise");

        uint amount = b.facevalue;
        bytes32 spid = b.tos[b.tos.length - 1];
        bytes32 newrepid = newCashRecepit(epid, spid, billid, amount);

        b.froms.push(spid);
        b.tos.push(0x0);
        b.times.push(block.timestamp);
        b.idOfCR = newrepid;
        b.state = BillState.Done;
        

    }
    
    // functions of get Informations not done yet


    fallback() external payable{}
    receive() external payable{}

}