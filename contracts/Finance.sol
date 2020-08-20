// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.4.0 <0.8.0;

import "./SafeMath.sol";



contract Finance {
    
    // 合约安全性隐患：重入攻击、溢出攻击

    using SafeMath for uint256;

    //应收账款凭证状态：有效、已拆分、已还款
    enum BillState{Valid, Split, Done}    
    //应收账款凭证
    struct TradeDebtBill{
        bytes32 id; // id由sha3生成
        address issuer; // 发行者 核心企业
        uint256 facevalue; // 面值
        uint256 expire_time;// 到期时间
        BillState state; // 状态
        bytes32 idOfCR0; // 对应与银行交互的现金收据ID
        bytes32 idOfCR1; // 对应与核心企业交互的现金收据ID
        bytes32 idOfparent; // 拆分前的父ID
        bytes32 idOfson0;   // 拆分后的两个子ID
        bytes32 idOfson1;   
        address[] owners; // 以下两个个字段可追溯交易记录。 
        uint256[] times; // 首次发行时第一个值为0，第二个值为now
		/*
		Owners: a -> b -> c -> d -> e
		Times:  0     1     2.   3.     4
				a->b的时间点为1，b->c时间点为2
        */
    }

    
    // 现金收据，使用应收账款凭证融资或核销后生成
    struct CashReceipt{
        bytes32 id; // sha3生成id
        uint256 amount; // 金额数
        bytes32 idOfTDB; // 对应发生核销或融资行为的应收账款凭证ID
        address from; 
        address to;
        uint256 time;
    }   
    
    //金融机构 银行
    struct Bank {
        address _address;
        bytes32[] idOfBills; // 与其发生过交易行为的应收账款id
        bytes32[] idOfRecepits;// 与其发生过交易行为的现金收据id
        string name;
    }

    //核心企业
    struct Enterprise {
        address _address;
        uint256 totalDebt;// 应收账款发行总额 / 核心企业应还款总额 / 当前已用额度
        uint256 totalDebtLimit; // 信用总额度
        bytes32[] idOfBills;
        bytes32[] idOfRecepits;
        string name;
    }
    
    //供应商
    struct Supplier {
        address _address;
        bytes32[] idOfBills;
        bytes32[] idOfRecepits;
        string name;
    }
    
    address public Arbitral_address;

    mapping(bytes32 => CashReceipt) mapOfCashReceipt;
    mapping(bytes32 => TradeDebtBill) mapOfTradeDebtBill;
    mapping(address => Enterprise) mapOfEnterprise;
    mapping(address => Bank) mapOfBank;
    mapping(address => Supplier) mapOfSupplier;
    
    TradeDebtBill[]  Bills;
    CashReceipt[]  Recepits;
    Enterprise[]  enterprises;
    Bank[]  banks;
    Supplier[]  suppliers;
    
    
    constructor(){
        Arbitral_address =  msg.sender;
    }
    
    // 添加成员只允许仲裁者（管理员）的地址发起
    modifier onlytheArbitral{
        require(msg.sender == Arbitral_address, "Only arbitral can operate");
        _;
    }
    
    // 新增银行
    function addBank(address bk_ad, string memory _name) 
            onlytheArbitral public returns(bool, string memory) {

        banks.push(Bank({
            _address: bk_ad, 
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfBank[bk_ad] = banks[banks.length - 1];
        return (true, "success");
    }
    
    //新增核心企业
    function addEnterprise(address ep_ad, uint256 limit,string memory _name) 
                            onlytheArbitral public returns(bool, string memory) {
        
        enterprises.push(Enterprise({
            _address: ep_ad, 
            totalDebt: 0,
            totalDebtLimit: limit,
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfEnterprise[ep_ad] = enterprises[enterprises.length - 1];
        return (true, "success");
    }

    function updateEnterpriseCreditLimit(address ep_ad, uint256 newLimit) 
                public returns(bool, string memory){
        Enterprise storage e = mapOfEnterprise[ep_ad];
        Bank storage b = mapOfBank[msg.sender];
        require(b._address != address(0x0), "Bank doesn't exist" );
        require(e._address != address(0x0),  "Enterprise doesn't exist");
        require(e.totalDebt < newLimit, "new limit can not even cover current debt");
        e.totalDebtLimit = newLimit;
        return (true, "success");
    }
    
    // 新增供应商
    function addSupplier(address sp_ad, string memory _name) 
            onlytheArbitral public returns(bool, string memory) {

        suppliers.push(Supplier({
            _address: sp_ad, 
            idOfBills: new bytes32[](0),
            idOfRecepits: new bytes32[](0),
            name: _name
        }));

        mapOfSupplier[sp_ad] = suppliers[suppliers.length - 1];
        return (true, "success");
    }
    
    // 生成新应收账款凭证
    function newTradeDebtBill(address _owner, address _issuer, bytes32 _parentid,uint256 _init_time,
                                uint256 _facevalue, uint256 _expire_time) internal returns(bytes32){
                                
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
            owners: new address[](0),
            times: new uint256[](0),
            idOfparent: _parentid
        }));
        
        TradeDebtBill storage t = Bills[Bills.length - 1];
        mapOfTradeDebtBill[_id] = t;
        t.times.push(_init_time); // 更新历史记录
        t.owners.push(_owner);

        return _id;
    }
    
    // 生成新现金收据
    function newCashRecepit(address _from, address _to, bytes32 _idOfTDB,
                            uint256 _amount) internal returns(bytes32){
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
    function issueTradeDebtBill(address ep_ad, address sp_ad, uint256 tolerate_time, uint256 _facevalue) 
                                external returns(bool, bytes32, string memory){
        Enterprise storage e = mapOfEnterprise[ep_ad];
        Supplier storage s = mapOfSupplier[sp_ad];
        
        require(e._address != address(0x0), "Enterprise doesn't exist ");
        require(e.totalDebt.add(_facevalue) <= e.totalDebtLimit,"Insufficient credit line");
        require(s._address != address(0x0), "Supplier doesn't exist");
        require(msg.sender == ep_ad, "permission denied!"); // 限制调用者的权限 只有地址符合才允许调用
        
        bytes32 id = newTradeDebtBill(ep_ad, ep_ad, 0x0, 0, _facevalue, 0);

        TradeDebtBill storage b = mapOfTradeDebtBill[id];

        b.owners.push(sp_ad);
        b.times.push(block.timestamp);
        b.expire_time = b.times[1].add(tolerate_time);
        
        e.totalDebt = e.totalDebt.add(_facevalue);
        
        e.idOfBills.push(id);
        s.idOfBills.push(id);
        
        return (true, id, "success");
    }
    
    // 应收账款到期核心企业应尽快还款 事件
    event billDueToRepay(bytes32 billid, address ep_ad);
    
    //检查及更新应收账款凭证的状态
    function CheckBillState(bytes32 billid) internal returns(bool){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        require(b.id != 0x0 , "Bill is not existed.");
        if(b.state == BillState.Split || b.state == BillState.Done) return false;

        if(block.timestamp < b.expire_time) return true;

        emit billDueToRepay(billid, b.issuer);

        return false;
    }
    
    // 应收账款在供应商之间流转
    function transferBillbetweenSuppliers(address sp_ad1, address sp_ad2, bytes32 billid, uint256 amount) 
                                            external returns(bool, string memory, bytes32 billid0, bytes32 billid1){
        Supplier storage s1 = mapOfSupplier[sp_ad1];
        Supplier storage s2 = mapOfSupplier[sp_ad2];
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        
        require(s1._address != address(0x0), "Supplier1 doesn't exist");  
        require(s2._address != address(0x0), "Supplier2 doesn't exist");

        bytes32[2] memory newbillids;

        if(!CheckBillState(billid)){
            return(false, "failed", newbillids[0], newbillids[1]);
        }

        uint256 ridx = b.owners.length - 1; // 取最新的历史记录index
        require(b.owners[ridx] ==  sp_ad1, "Bill doesn't belong to Supplier1");
        require(amount <= b.facevalue, "amount exceeds");
        require(msg.sender == sp_ad1, "permission denied!");// 限制调用者的权限 只有地址符合才允许调用
        
        if(amount == b.facevalue){
            b.owners.push(sp_ad2);
            b.times.push(block.timestamp);
            s2.idOfBills.push(billid);
        }else{//拆分
            newbillids[0] = newTradeDebtBill(sp_ad2 , b.issuer, billid, block.timestamp, amount, b.expire_time);
            newbillids[1] = newTradeDebtBill(sp_ad1 , b.issuer, billid, block.timestamp, b.facevalue.sub(amount), b.expire_time);

            b.idOfson0 = newbillids[0];
            b.idOfson1 = newbillids[1];

            mapOfSupplier[sp_ad1].idOfBills.push(newbillids[1]);
            mapOfSupplier[sp_ad2].idOfBills.push(newbillids[0]);

            Enterprise storage e = mapOfEnterprise[b.issuer];
            e.idOfBills.push(newbillids[0]);
            e.idOfBills.push(newbillids[1]);

            b.state = BillState.Split;
        }
        return (true, "success", newbillids[0], newbillids[1]);
    }
    
    
    // 供应商使用应收账款进行融资
    function supplierFinancingfromBank(bytes32 billid, address sp_ad, address bank_ad, uint16 rate) 
                                        external returns(bool, string memory, bytes32){
        TradeDebtBill storage bi = mapOfTradeDebtBill[billid];
        Supplier storage s = mapOfSupplier[sp_ad];
        Bank storage ba = mapOfBank[bank_ad];

        require(s._address != address(0x0), "Supplier doesn't exist");
        require(bi.id != 0x0, "Bill doesn't exist");
        require(ba._address != address(0x0), "Bank doesn't exist");
        bytes32 newrepid; // 新现金收据ID

        if(!CheckBillState(billid)){
            return(false, "failed", newrepid);
        }
        
        uint256 ridx = bi.owners.length - 1;
        require(bi.owners[ridx] ==  sp_ad , "Bill doesn't belong to Supplier ");
        require(msg.sender == sp_ad, "permission denied!");// 限制调用者的权限 只有地址符合才允许调用

        uint256 amount = bi.facevalue.mul(rate).div(1000); // 计算真实可承兑金额 rate为贴现率

        //发放现金
        newrepid = newCashRecepit(bank_ad, sp_ad, billid, amount);
        bi.owners.push(bank_ad);
        bi.times.push(block.timestamp);
        bi.idOfCR0 = newrepid;
        
        ba.idOfRecepits.push(newrepid);
        ba.idOfBills.push(billid);
        s.idOfRecepits.push(newrepid);
        
        return(true, "success", newrepid);

    }
    
    // 核心企业进行核销还款操作（可在过期前操作，所有者尽早拿到现金）(涉及到应收凭证的流动和现金收据的创建)
    function enterpriseRepay(bytes32 billid, address ep_ad) onlytheArbitral 
                            external returns(bool, string memory, bytes32){

        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        Enterprise storage e = mapOfEnterprise[ep_ad];

        require(b.id != 0x0, "Bill doesn't exist");
        require(e._address != address(0x0), "Enterprise doesn't exist");
        require(b.issuer == ep_ad, "Bill is not issued by this Enterprise");
        require(msg.sender == ep_ad, "permission denied!");// 限制调用者的权限 只有地址符合才允许调用

        uint256 amount = b.facevalue;
        address debtorid = b.owners[b.owners.length - 1]; // 确认最后一任所有者 为还款对象
        bytes32 newrepid = newCashRecepit(ep_ad, debtorid, billid, amount);
        

        b.owners.push(address(0x0));// 发往0地址表示已核销
        b.times.push(block.timestamp);
        b.idOfCR1 = newrepid;
        b.state = BillState.Done;
        e.idOfRecepits.push(newrepid);
        
        //还款对象为供应商或银行，现金收据id加入此对象的数组中
        if(mapOfSupplier[debtorid]._address != address(0x0)) {
            mapOfSupplier[debtorid].idOfRecepits.push(newrepid);
        }else{
            mapOfBank[debtorid].idOfRecepits.push(newrepid);
        }
        
        require(amount <= e.totalDebt, "Accounting errors.");
        e.totalDebt = e.totalDebt.sub(amount);

        return(true, "success", newrepid);
    }
    
    // functions of get Informations
    function getSupplierCount() public view returns(uint256){
        return uint256(suppliers.length);
    }
    
    function getBankCount() public view returns(uint256){
        return uint256(banks.length);
    }
    
    function getBillCount() public view returns(uint256){
        return Bills.length;
    }
    
    function getRecepitCount() public view returns(uint256){
        return Recepits.length;
    }
    
    function getEnterpriseCount() public view returns(uint256){
        return uint256(enterprises.length);
    }
        
    function getBillBasicInfo(bytes32 billid) public view 
            returns(bytes32, address, uint256, uint256, BillState, bytes32, bytes32){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.id, b.issuer, b.facevalue, b.expire_time, b.state, b.idOfCR0, b.idOfCR1);
    }
    
    function getBillHistory(bytes32 billid) public view returns(uint256[] memory, address[] memory){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.times, b.owners);
    }
    
    function getBillSplitInfo(bytes32 billid) public view returns(bytes32, bytes32, bytes32){
        TradeDebtBill storage b = mapOfTradeDebtBill[billid];
        return(b.idOfparent, b.idOfson0, b.idOfson1);
    }
    
    function getRecepitInfo(bytes32 repid) public view returns(uint256, bytes32, address, address){
        CashReceipt storage r = mapOfCashReceipt[repid];
        return(r.amount, r.idOfTDB, r.from, r.to);
    }
    
    function getBankBasicInfo(address _ad) public view returns(uint256, uint256, string memory){
        Bank storage b = mapOfBank[_ad];
        return( b.idOfBills.length, b.idOfRecepits.length, b.name);
    }
    
    function getSupplierBasicInfo(address _ad) public view returns( uint256, uint256, string memory){
        Supplier storage s = mapOfSupplier[_ad];
        return( s.idOfBills.length, s.idOfRecepits.length, s.name);
    }
    
    function getEnterpriseBasicInfo(address _ad) public view 
                        returns(uint256, uint256, uint256 , string memory){
        Enterprise storage e = mapOfEnterprise[_ad];
        return(e.totalDebt, e.idOfBills.length, e.idOfRecepits.length, e.name);
    }
    
    function getAllofSupplierBillsid(address _ad) public view returns(bytes32[] memory){
        Supplier storage s = mapOfSupplier[_ad];
        return(s.idOfBills);
    }
    
    function getAllofBankBillsid(address _ad) public view returns(bytes32[] memory){
        Bank storage b = mapOfBank[_ad];
        return(b.idOfBills);
    }
    
    function getAllofEnterpriseBillsid(address _ad) public view returns(bytes32[] memory){
        Enterprise storage e = mapOfEnterprise[_ad];
        return(e.idOfBills);
    }
    
    function getAllofSupplierRecepitsid(address _ad) public view returns(bytes32[] memory){
        Supplier storage s = mapOfSupplier[_ad];
        return(s.idOfRecepits);
    }
    
    function getAllofBankRecepitsid(address _ad) public view returns(bytes32[] memory){
        Bank storage b = mapOfBank[_ad];
        return(b.idOfRecepits);
    }
    
    function getAllofEnterpriseRecepitsid(address _ad) public view returns(bytes32[] memory){
        Enterprise storage e = mapOfEnterprise[_ad];
        return(e.idOfRecepits);
    }
    
    function withdraw(uint256 amount) onlytheArbitral public{
        require(amount < 1e25);
        msg.sender.transfer(amount);
    }

    function viewBalanceOf(address addr) public view returns(uint256){
        return addr.balance;
    }
    
    fallback() external payable{}
    receive() external payable{}

}