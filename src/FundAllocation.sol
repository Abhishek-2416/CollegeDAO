// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "../src/Token.sol";

contract FundAllocation {
    Token token;

    enum Vote{Yes,No}

    /**Errors */
    error FundAllocation__NotTheOwnerOfProposal();
    error FundAllocation__NotMemberOfTheDAO();
    error FundAllocation__ThePropsalHasReachedDeadline();
    error FundAllocation__YouHaveAlreadyVoted();
    error FundAllocation__HasBeenCompleted();
    error FundAllocation__NotEnoughVoters();

    struct Proposal {
        address ownerOfProposal;
        string mainDescription;
        uint256 deadline;
        uint256 goal;
        uint256 raisedAmount;
        uint256 noOfContributors;
        mapping(address => uint256) contributors;
        mapping(uint256 => Request) requests;
        uint256 numRequest;
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
        mapping(address => Vote) voteStateInRequest;
        uint256 proposalId;
        uint256 noOfYesVotes;
        uint256 noOfNoVotes;
    }

    /**Events */
    event ProposalCreatedForFunds(string indexed _mainDescription,uint256 indexed _goal,uint256 indexed _deadline);
    event Contributed(address indexed _sender,uint256 indexed _value);
    event CreateRequest(string _description,address _recepient,uint256 _value);
    event VoteRequested(address indexed voter,bool indexed Vote);

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

    modifier voteOnlyIfRequestNotCompleted(uint256 proposalId,uint256 requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];

        if(thisRequest.completed == true){
            revert  FundAllocation__HasBeenCompleted();
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
        Proposal storage thisproposal = proposals[proposalId];
        Request storage newRequest = thisproposal.requests[thisproposal.numRequest];
        newRequest.requestdescription = description;
        newRequest.recepient = _recepient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        thisproposal.numRequest++;
    }

    function voteRequest(uint256 proposalId,uint256 requestId,Vote vote) external memberOfDAOOnly voteOnlyIfRequestNotCompleted(proposalId,requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];
        if(vote == Vote.Yes){
            thisRequest.noOfYesVotes++;
            thisRequest.voteStateInRequest[msg.sender] == Vote.Yes;
        }else if(vote == Vote.No){
            thisRequest.noOfNoVotes++;
            thisRequest.voteStateInRequest[msg.sender] == Vote.No;
        }

        thisRequest.noOfVoters++;
    }

    function changeVoteForRequest(uint256 proposalId,uint256 requestId,Vote vote) external memberOfDAOOnly voteOnlyIfRequestNotCompleted(proposalId,requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];
        //Clearing out previous vote
        if(thisRequest.voteStateInRequest[msg.sender] == Vote.Yes){
            thisRequest.noOfYesVotes--;
        }else if(thisRequest.voteStateInRequest[msg.sender] == Vote.No){
            thisRequest.noOfNoVotes--;
        }

        if(vote == Vote.Yes){
            thisRequest.noOfYesVotes++;
            thisRequest.voteStateInRequest[msg.sender] = Vote.Yes;
        }else if(vote == Vote.No){
            thisRequest.noOfNoVotes++;
            thisRequest.voteStateInRequest[msg.sender] = Vote.No;
        }
    }

    function makePayment(uint256 proposalId,uint256 requestId) external OnlyProposalOwner(proposalId) voteOnlyIfRequestNotCompleted(proposalId,requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];
        if(thisRequest.noOfVoters > thisproposal.noOfContributors / 2){
            revert FundAllocation__NotEnoughVoters();
        }

        //transferring the funds to the recepient address
        (bool s,) = thisRequest.recepient.call{value: thisRequest.value}("");
        require(s);

        
    }

}