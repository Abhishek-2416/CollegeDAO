// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "../src/Token.sol";

contract FundAllocation {
    Token token;

    /**Errors */
    error FundAllocation__NotTheOwnerOfProposal();
    error FundAllocation__NotMemberOfTheDAO();
    error FundAllocation__ThePropsalHasReachedDeadline();
    error FundAllocation__YouHaveAlreadyVoted();


    struct Proposal {
        address ownerOfProposal;
        string mainDescription;
        uint256 deadline;
        uint256 goal;
        uint256 raisedAmount;
        uint256 noOfContributors;
        mapping(address => uint256) contributors;
    }

    mapping(uint256 proposalId => Proposal) private proposals;
    uint256 private numProposals;

    //Creating a spending Request
    struct Request {
        string requestdescription;
        address payable recepient;
        uint256 value;
        bool completed;
        uint256 noOfVoters;
        mapping(address => bool) voters;
        uint256 proposalId;
        uint256 numRequests;
    }

    //mapping the spending requests , the key is the spending request number (index) 
    mapping(uint256 => Request) requests;
    uint256 private numRequest;

    /**Events */
    event ProposalCreatedForFunds(string indexed _mainDescription,uint256 indexed _goal,uint256 indexed _deadline);
    event Contributed(address indexed _sender,uint256 indexed _value);
    event CreateRequest(string _description,address _recepient,uint256 _value);
    event MakePayment(address _recepient,uint256 _value);

    constructor(address members){
        token = Token(members);
    }

    /**Modifier */

    modifier OnlyProposalOwner(uint256 proposalId) {
        if(proposals[proposalId].ownerOfProposal != msg.sender){
            revert FundAllocation__NotTheOwnerOfProposal();
        }
        _;
    }

    modifier memberOfDAOOnly() {
        if(token.balanceOf(msg.sender) == 0){
            revert FundAllocation__NotMemberOfTheDAO();
        }
        _;
    }

    modifier activeProposalOnly(uint256 proposalId) {
        if(proposals[proposalId].deadline < block.timestamp ){
            revert FundAllocation__ThePropsalHasReachedDeadline();
        }
        _;
    }

    function createProposal(string calldata _description, uint256 _goal,uint256 _deadline) external memberOfDAOOnly {
        Proposal storage proposal = proposals[numProposals];
        proposal.ownerOfProposal = msg.sender;
        proposal.mainDescription = _description;
        proposal.deadline = block.timestamp + _deadline;
        proposal.goal = _goal;
        numProposals++;

        emit ProposalCreatedForFunds(_description,_goal,_deadline);
    }

    function contribute(uint256 proposalId) external payable activeProposalOnly(proposalId) memberOfDAOOnly {
        //Checking if they are sending money in for the first time
        Proposal storage thisproposal = proposals[proposalId];
        if(thisproposal.contributors[msg.sender] == 0){
            thisproposal.noOfContributors++;
        }

        thisproposal.contributors[msg.sender] += msg.value;
        thisproposal.raisedAmount += msg.value;

        emit Contributed(msg.sender,msg.value);
    }

    function CreateRequestToSpendFunds(uint256 proposalId,string calldata description,address payable _recepient,uint256 _value) external OnlyProposalOwner(proposalId) {
        Request storage newRequest = requests[numRequest];
        newRequest.requestdescription = description;
        newRequest.recepient = _recepient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        newRequest.numRequests++;
        numRequest++;
    }

    function voteRequest(uint256 requestId) external memberOfDAOOnly {
        Request storage thisRequest = requests[requestId];
        if(thisRequest.voters[msg.sender] == true){
            revert FundAllocation__YouHaveAlreadyVoted();
        }
        thisRequest.voters[msg.sender] == true;
        thisRequest.noOfVoters++;
    }

}