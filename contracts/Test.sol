// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.4.0 <0.8.0;

contract Test {

    // bytes32[] public theByte;
    // function Alter() public{
    //     theByte.push(keccak256(abi.encode(block.timestamp)));
    // }
    
    enum State{Valid, Done}
    
    struct Class{
        uint256[] a;
        bytes32[] b;
        address[] c;
        State state;
        
    }
    Class cl;
    constructor(){
        cl.state = State.Valid;
        for(uint i = 0; i < 3; ++i)
        {
            cl.a.push(i);
            cl.b.push(keccak256(abi.encode(block.timestamp, i)));
            cl.c.push(msg.sender);
        }
    }
    function fun() public view returns(State, uint256[] memory,  bytes32[] memory,address[] memory){
        return(State.Valid, cl.a, cl.b, cl.c);
        
    }


    fallback() external payable{}
    receive() external payable{}

}