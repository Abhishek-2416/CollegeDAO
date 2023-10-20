// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "./Token.sol";

contract FundAllocation {
    Token token;

    /**State Variables */
    string public mainDescription;
    address immutable i_admin;
    uint256 private noOfContributors;
    uint256 private deadline;
    uint256 private goal;
    uint256 private raisedAmount;
    mapping(address => uint256) contributors;


    //Creating a spending request
    struct Request{
        string description;
        address payable recepient;
        uint256 value;
        bool completed;
        uint256 noOfVoters;
        mapping(address => bool) voters;
    }

    //mapping the spending requests , the key is the spending request number (index) 
    mapping(uint256 => Request) requests;
    uint256 private numRequests;

    /**Events */
    event Contribute(address _sender,uint256 _value);
    event CreateRequest(string _description, address _recepient,uint256 _value);
    event MakePayment(address _recepient,uint256 _value);

    constructor(string memory _mainDescription,uint256 _goal,uint256 _deadline){
        mainDescription = _mainDescription;
        goal = _goal;
        deadline = block.timestamp + _deadline;
        i_admin = msg.sender;
    }

    modifier OnlyAdmin(){
        require(msg.sender == i_admin);
        _;
    }

    modifier memberOfDAOOnly() {
        require(token.balanceOf(msg.sender) > 0, "Dumb");
        _;
    }

    modifier activeProposalOnly(){
        require(block.timestamp < deadline);
        _;
    }

    function contribute() public payable activeProposalOnly memberOfDAOOnly{
        //Checking if they are sending money in for the first time
        if(contributors[msg.sender] == 0){
            noOfContributors++;
        }

        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit Contribute(msg.sender,msg.value);
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }

    function createRequest(string calldata _description,address payable _recepient, uint256 _value) public OnlyAdmin memberOfDAOOnly activeProposalOnly{
        Request storage newRequest = requests[numRequests];
        numRequests++;

        newRequest.description = _description;
        newRequest.recepient = _recepient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        emit CreateRequest(_description,_recepient,_value);
    }

    function voteRequest(uint requestId) public{
        Request storage thisRequest = requests[requestId];
        require(thisRequest.voters[msg.sender] == false,"Else you have already voted");
        thisRequest.voters[msg.sender] == true;
        thisRequest.noOfVoters++;
    }

    function makePayment(uint256 requestId) public OnlyAdmin{
        Request storage thisRequest = requests[requestId];
        require(thisRequest.completed == false);
        require(thisRequest.noOfVoters > noOfContributors / 2);
        thisRequest.completed == true;
        
        //Now transferring funds to the recepient address
        (bool s,) = thisRequest.recepient.call{value:thisRequest.value}("");
        require(s);

        emit MakePayment(thisRequest.recepient, thisRequest.value);
    }
}