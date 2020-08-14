// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.4.0 <0.8.0;

contract Finance {
    
    //应收账款凭证状态：有效、已拆分、已还款
    enum BillState{Valid, Split, Done} // Expired: not not writed off yet ; Done: already writed off.
    
    //应收账款凭证
    struct TradeDebtBill{
        bytes32 id;
        bytes32 issuer; // 发行者 核心企业
        uint facevalue; // 面值
        uint expire_time;// 到期时间
        BillState state;
        bytes32 idOfCR0; // 对应与银行交互的现金收据ID
        bytes32 idOfCR1; // 对应与核心企业交互的现金收据ID
        bytes32 idOfparent; 
        bytes32 idOfson0;   
        bytes32 idOfson1;   
        bytes32[] owners; // 者两个个字段可追溯交易记录。 
        uint[] times;
    }
    
    // 现金收据，使用应收账款凭证融资或核销后生成
    struct CashReceipt{
        bytes32 id;
        uint amount;
        bytes32 idOfTDB; // 对应的应收账款凭证ID
        bytes32 from;
        bytes32 to;
        uint time;
    }   
    
    //仲裁者 管理者
    struct Arbitral {
        bytes32 _id;
        address _address;
    }
    
    //金融机构 银行
    struct Bank {
        bytes32 id;
        bytes32[] idOfBills; // 与其发生过交易行为的应收账款id
        bytes32[] idOfRecepits;// 与其发生过交易行为的现金收据id
        string name;
    }

    //核心企业
    struct Enterprise {
        bytes32 id;
        uint totalDebt;// 应收账款发行总额 / 核心企业应还款总额 / 当前已用信用额度
        uint totalDebtLimit; // 信用总额度
        bytes32[] idOfBills;
        bytes32[] idOfRecepits;
        string name;
    }
    
    //供应商
    struct Supplier {
        bytes32 id;
        bytes32[] idOfBills;
        bytes32[] idOfRecepits;
        string name;
    }
    
    Arbitral public theArbitral;

    mapping(bytes32 => CashReceipt) mapOfCashReceipt;
    mapping(bytes32 => TradeDebtBill) mapOfTradeDebtBill;
    mapping(bytes32 => Enterprise) mapOfEnterprise;
    mapping(bytes32 => Bank) mapOfBank;
    mapping(bytes32 => Supplier) mapOfSupplier;
    
    TradeDebtBill[]  Bills;
    // TradeDebtBill[] public doneBills;
    CashReceipt[]  Recepits;
    Enterprise[]  enterprises;
    Bank[]  banks;
    Supplier[]  suppliers;
    
    
    constructor(bytes32 id){
        theArbitral = Arbitral({
            _id: id,
            _address: msg.sender
        });
    }
    
    // 写操作调用只允许仲裁者（管理员）的地址发起
    modifier onlytheArbitral{
        require(msg.sender == theArbitral._address, "Only arbitral can operate");
        _;
    }
    
    // 新增银行
    function addBank(bytes32 bankid, string memory _name) onlytheArbitral public returns(bool, string memory) {

        banks.push(Bank({
            id: bankid, 
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfBank[bankid] = banks[banks.length - 1];
        return (true, "success");
    }
    
    //新增核心企业
    function addEnterprise(bytes32 epid, uint limit,string memory _name) onlytheArbitral public returns(bool, string memory) {
        
        enterprises.push(Enterprise({
            id: epid, 
            totalDebt: 0,
            totalDebtLimit: limit,
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfEnterprise[epid] = enterprises[enterprises.length - 1];
        return (true, "success");
    }

    function updateEnterpriseCreditLimit(bytes32 eid, uint newLimit) onlytheArbitral public returns(bool, string memory){
        Enterprise storage e = mapOfEnterprise[eid];
        require(e.totalDebt < newLimit, "new limit can not even cover current debt");
        e.totalDebtLimit = newLimit;
        return (true, "success");
    }
    
    // 新增供应商
    function addSupplier(bytes32 spid, string memory _name) onlytheArbitral public returns(bool, string memory) {

        suppliers.push(Supplier({
            id: spid, 
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfSupplier[spid] = suppliers[suppliers.length - 1];
        return (true, "success");
    }
    
    // 生成新应收账款凭证
    function newTradeDebtBill(bytes32 _owner, bytes32 _issuer, bytes32 _parentid,
                            uint _init_time, uint _facevalue, uint _expire_time) internal returns(bytes32){
                                
        bytes32 _id = keccak256(abi.encodePacked(block.timestamp, _owner, _issuer)); // 使用sha3生成三个值的哈希作为ID

        Bills.push(TradeDebtBill({
            id: _id,
            issuer: _issuer,
            facevalue: _facevalue,
            expire_time: _expire_time,
            state: BillState.Valid,
            idOfCR0: 0x0,
            idOfCR1: 0x0,
            idOfson0: 0x0,
            idOfson1: 0x0,
            owners: new bytes32[](0),
            times: new uint[](0),
            idOfparent: _parentid
        }));
        
        TradeDebtBill storage t = Bills[Bills.length - 1];
        mapOfTradeDebtBill[_id] = t;
        t.times.push(_init_time); // 更新历史记录
        t.owners.push(_owner);

        return _id;
    }
    
    // 生成新现金收据
    function newCashRecepit(bytes32 _from, bytes32 _to, bytes32 _idOfTDB, uint _amount) internal returns(bytes32){
        bytes32 _id = keccak256(abi.encodePacked(block.timestamp, _from, _to));
        
        Recepits.push(CashReceipt({
            id: _id,
            idOfTDB: _idOfTDB,
            amount: _amount,
            from: _from,
            to: _to,
            time: block.timestamp
        }));
        
        CashReceipt storage c = Recepits[Recepits.length - 1];
        mapOfCashReceipt[_id] = c;
        return _id;
    }
    
    // 发行应收账款凭证
    function issueTradeDebtBill(bytes32 epid, bytes32 spid, uint tolerate_time, uint _facevalue) onlytheArbitral external returns(bool, bytes32, string memory){
        Enterprise storage e = mapOfEnterprise[epid];
        Supplier storage s = mapOfSupplier[spid];
        
        require(e.id != 0x0 && s.id != 0x0 && e.totalDebt + _facevalue <= e.totalDebtLimit, 
                "Enterprise doesn't exist / Supplier doesn't exist  / Insufficient credit line");
        
        bytes32 id = newTradeDebtBill(epid, epid, 0x0, 0, _facevalue, 0);

        TradeDebtBill storage b = mapOfTradeDebtBill[id];

        b.owners.push(spid);
        b.times.push(block.timestamp);
        b.expire_time = b.times[1] + tolerate_time;
        
        e.totalDebt += _facevalue;
        
        e.idOfBills.push(id);
        s.idOfBills.push(id);
        
        return (true, id, "success");
    }
    
    // 应收账款到期核心企业应尽快还款 事件
    event billDueToRepay(bytes32 billid, bytes32 epid);
    
    //检查及更新应收账款凭证的状态
    function CheckBillState(bytes32 billid) internal returns(bool){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        require(b.id != 0x0 , "Bill is not existed.");

        if(block.timestamp < b.expire_time) return true;

        emit billDueToRepay(billid, b.issuer);

        return false;
    }
    
    // 应收账款在供应商之间流转
    function transferBillbetweenSuppliers(bytes32 spid1, bytes32 spid2, bytes32 billid, uint amount) onlytheArbitral external returns(bool, string memory){
        Supplier storage s1 = mapOfSupplier[spid1];
        Supplier storage s2 = mapOfSupplier[spid2];
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        
        require(s1.id != 0x0 && s2.id != 0x0, "Supplier1 doesn't exist / Supplier2 doesn't exist");  

        if(!CheckBillState(billid)){
            return(false, "failed");
        }

        require(b.state != BillState.Split, "Bill is Split");

        uint ridx = b.owners.length - 1; // 取最新的历史记录index
        require(b.owners[ridx] ==  spid1, "Bill doesn't belong to Supplier1");
        require(amount <= b.facevalue, "amount exceeds");

        if(amount == b.facevalue){
            b.owners.push(spid2);
            b.times.push(block.timestamp);
            s2.idOfBills.push(billid);
        }else{//拆分
            bytes32[2] memory newbillids;

            newbillids[0] = newTradeDebtBill(spid2 , b.issuer, billid, block.timestamp, amount, b.expire_time);
            newbillids[1] = newTradeDebtBill(spid1 , b.issuer, billid, block.timestamp, b.facevalue - amount, b.expire_time);

            b.idOfson0 = newbillids[0];
            b.idOfson1 = newbillids[1];

            mapOfSupplier[spid1].idOfBills.push(newbillids[1]);
            mapOfSupplier[spid2].idOfBills.push(newbillids[0]);

            b.state = BillState.Split;
        }
        return (true, "success");
    }
    
    
    // 供应商使用应收账款进行融资
    function supplierFinancingfromBank(bytes32 billid, bytes32 spid, bytes32 bankid, uint rate) onlytheArbitral external returns(bool, string memory, bytes32){
        TradeDebtBill storage bi = mapOfTradeDebtBill[billid];
        Supplier storage s = mapOfSupplier[spid];
        Bank storage ba = mapOfBank[bankid];

        require(s.id != 0x0 && bi.id != 0x0 && ba.id != 0x0, 
                "Supplier doesn't exist / Bill doesn't exist / Bank doesn't exist");
        bytes32 newrepid; // 新现金收据ID

        if(!CheckBillState(billid)){
            return(false, "failed", newrepid);
        }
        require(bi.state != BillState.Split, "Bill is Split");
        
        
        uint ridx = bi.owners.length - 1;
        require(bi.owners[ridx] ==  spid , "Bill doesn't belong to Supplier ");

        uint amount = bi.facevalue * rate / 1000; // 计算真实可承兑金额 rate为贴现率

        //发放现金
        newrepid = newCashRecepit(bankid, spid, billid, amount);
        bi.owners.push(bankid);
        bi.times.push(block.timestamp);
        bi.idOfCR0 = newrepid;
        
        ba.idOfRecepits.push(newrepid);
        ba.idOfBills.push(billid);
        s.idOfRecepits.push(newrepid);
        
        return(true, "success", newrepid);

    }
    
    // 核心企业进行核销操作（可在过期前操作，所有者尽早拿到现金）
    function enterpriseRepay(bytes32 billid, bytes32 epid) onlytheArbitral external returns(bool, string memory, bytes32){

        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        Enterprise storage e = mapOfEnterprise[epid];

        require(b.id != 0x0 && e.id != 0x0 && b.issuer == epid, " Bill doesn't exist / Enterprise doesn't exist / Bill is not issued by this Enterprise");

        uint amount = b.facevalue;
        bytes32 debtorid = b.owners[b.owners.length - 1]; // 确认最后一任所有者 为还款对象
        bytes32 newrepid = newCashRecepit(epid, debtorid, billid, amount);
        

        b.owners.push(0x0);// 发往0地址表示已核销
        b.times.push(block.timestamp);
        b.idOfCR1 = newrepid;
        b.state = BillState.Done;
        e.idOfRecepits.push(newrepid);

        // 若此应收账款是拆分后生成的子应收，未曾被收录，则加入核心企业的应收账款id数组中。
        if(b.idOfparent != 0x0){
            e.idOfBills.push(billid);
        }
        
        //还款对象为供应商或银行，现金收据id加入此对象的数组中
        if(mapOfSupplier[debtorid].id != 0x0){
            mapOfSupplier[debtorid].idOfRecepits.push(newrepid);
        }else{
            mapOfBank[debtorid].idOfRecepits.push(newrepid);
        }
        
        require(amount <= e.totalDebt, "Accounting errors.");
        e.totalDebt -= amount;

        return(true, "success", newrepid);
    }
    
    // functions of get Informations
    function getSupplierCount() public view returns(uint){
        return suppliers.length;
    }
    
    function getBankCount() public view returns(uint){
        return banks.length;
    }
    
    function getBillCount() public view returns(uint){
        return Bills.length;
    }
    
    function getRecepitCount() public view returns(uint){
        return Recepits.length;
    }
    
    function getEnterpriseCount() public view returns(uint){
        return enterprises.length;
    }
        
    function getBillBasicInfo(bytes32 billid) public view returns(bytes32, bytes32, uint, uint, BillState, bytes32, bytes32){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.id, b.issuer, b.facevalue, b.expire_time, b.state, b.idOfCR0, b.idOfCR1);
    }
    
    function getBillHistory(bytes32 billid) public view returns(uint[] memory, bytes32[] memory){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.times, b.owners);
    }
    
    function getBillSplitInfo(bytes32 billid) public view returns(bytes32, bytes32, bytes32){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.idOfparent, b.idOfson0, b.idOfson1);
    }
    
    function getRecepitInfo(bytes32 repid) public view returns(uint, bytes32, bytes32, bytes32){
        CashReceipt storage r = mapOfCashReceipt[repid];
        return(r.amount, r.idOfTDB, r.from, r.to);
    }
    
    function getBankBasicInfo(bytes32 id) public view returns(uint, uint, string memory){
        Bank storage b = mapOfBank[id];
        return( b.idOfBills.length, b.idOfRecepits.length, b.name);
    }
    
    function getSupplierBasicInfo(bytes32 id) public view returns( uint, uint, string memory){
        Supplier storage s = mapOfSupplier[id];
        return( s.idOfBills.length, s.idOfRecepits.length, s.name);
    }
    
    function getEnterpriseBasicInfo(bytes32 id) public view returns(uint, uint, uint , string memory){
        Enterprise storage e = mapOfEnterprise[id];
        return(e.totalDebt, e.idOfBills.length, e.idOfRecepits.length, e.name);
    }
    
    function getAllofSupplierBillsid(bytes32 id) public view returns(bytes32[] memory){
        Supplier storage s = mapOfSupplier[id];
        return(s.idOfBills);
    }
    
    function getAllofBankBillsid(bytes32 id) public view returns(bytes32[] memory){
        Bank storage b = mapOfBank[id];
        return(b.idOfBills);
    }
    
    function getAllofEnterpriseBillsid(bytes32 id) public view returns(bytes32[] memory){
        Enterprise storage e = mapOfEnterprise[id];
        return(e.idOfBills);
    }
    
    function getAllofSupplierRecepitsid(bytes32 id) public view returns(bytes32[] memory){
        Supplier storage s = mapOfSupplier[id];
        return(s.idOfRecepits);
    }
    
    function getAllofBankRecepitsid(bytes32 id) public view returns(bytes32[] memory){
        Bank storage b = mapOfBank[id];
        return(b.idOfRecepits);
    }
    
    function getAllofEnterpriseRecepitsid(bytes32 id) public view returns(bytes32[] memory){
        Enterprise storage e = mapOfEnterprise[id];
        return(e.idOfRecepits);
    }
    

    function withdraw(uint amount) onlytheArbitral public{
        require(amount < 1e20);
        msg.sender.transfer(amount);
    }
    
    fallback() external payable{}
    receive() external payable{}

}