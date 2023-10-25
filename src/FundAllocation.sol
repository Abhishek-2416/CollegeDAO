// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "../src/Token.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@4.7.0/security/ReentrancyGuard.sol";

contract FundAllocation {
    /**
     * @dev 
     */
    Token token;

    /**Enums */
    enum Vote{Yes,No}

    /**Errors */
    error FundAllocation__NotTheOwnerOfProposal();
    error FundAllocation__NotMemberOfTheDAO();
    error FundAllocation__ThePropsalHasReachedDeadline();
    error FundAllocation__YouHaveAlreadyVoted();
    error FundAllocation__HasBeenCompleted();
    error FundAllocation__NotEnoughVoters();
    error FundAllocation__TransactionFailed();
    error FundAllocation__TheGoalAmountShouldBeGreaterThanZero();
    error FundAllocation__TheValueSentShouldBeGreaterThanZero();
    error FundAllocation__TheRecepientAddressCannotBeNullAddress();
    error FundAllocation__TheRecepientAddressCannotBeSameAsTheOwnerOfProposal();

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

    /**
     * 
     * @notice This function is to create a Proposal which require certain funds
     * @param _description  This is to describe why the poposal was created and what will it be used for 
     * @param _goal This is the amount of money needed for the campaign
     * @param _deadline This is to mention the time period of the campaign
     */
    function createProposal(string calldata _description, uint256 _goal,uint256 _deadline) external memberOfDAOOnly {
        if(_goal <= 0 ){
            revert FundAllocation__TheGoalAmountShouldBeGreaterThanZero();
        }
        Proposal storage proposal = proposals[numProposals];
        proposal.ownerOfProposal = msg.sender;
        proposal.mainDescription = _description;
        proposal.deadline = block.timestamp + _deadline;
        proposal.goal = _goal;
        numProposals++;

        emit ProposalCreatedForFunds(_description,_goal,_deadline);
    }

    /**
     * This function allows the members of the DAO to contribute towards the cause for which the Proposal was created
     * @param proposalId This is unique Id of the Proposal which was created
     */
    function contribute(uint256 proposalId) external payable activeProposalOnly(proposalId) memberOfDAOOnly {
        //Checking if they are sending money in for the first time
        if(msg.value <= 0){
            revert FundAllocation__TheValueSentShouldBeGreaterThanZero();
        }

        Proposal storage thisproposal = proposals[proposalId];

        if(thisproposal.contributors[msg.sender] == 0){
            thisproposal.noOfContributors++;
        }

        thisproposal.contributors[msg.sender] += msg.value;
        thisproposal.raisedAmount += msg.value;

        emit Contributed(msg.sender,msg.value);
    }

    /**
     * This function allows the owner of the Proposal to create a spending Request to spend the funds which were alloted to him
     * @param proposalId This is unique Id of the Proposal to know which Proposal we are going to allow to spend funds for
     * @param description This is a short description of to know for what does the owner of Proposal wants to spend the money
     * @param _recepient This is the person whom the funds will be transfered for the specific request
     * @param _value This is the value which will be requested by the owner which he can spend in this request
     */
    function CreateRequestToSpendFunds(uint256 proposalId,string calldata description,address payable _recepient,uint256 _value) external OnlyProposalOwner(proposalId) {
        Proposal storage thisproposal = proposals[proposalId];
        Request storage newRequest = thisproposal.requests[thisproposal.numRequest];

        if(_value <= 0){
            revert FundAllocation__TheValueSentShouldBeGreaterThanZero();
        }

        if(_recepient == address(0)){
            revert FundAllocation__TheRecepientAddressCannotBeNullAddress();
        }

        if(_recepient == thisproposal.ownerOfProposal){
            revert FundAllocation__TheRecepientAddressCannotBeSameAsTheOwnerOfProposal();
        }

        newRequest.requestdescription = description;
        newRequest.recepient = _recepient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        thisproposal.numRequest++;
    }

    /**
     * This function will allow the member of DAO to vote if the speicific request should be approved or not
     * @param proposalId This to Id of the proposal which will contain the specific request
     * @param requestId This is the specific request Id which requires votes
     * @param vote This is the vote which should taken in by the members of the DAO
     */
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

    /**
     * @notice This function is to change the user's vote on a particular request of proposal proposal
     * @param proposalId The Id of the Proposal the user wants to vote on 
     * @param requestId The Id of the Request the user wants to vote on
     * @param vote The vote which the User wants to change to
     */
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

    /**
     * @notice This function called by the proposal owner to approve and transfer the payment 
     * @param proposalId The unique Proposal Id where it should take place
     * @param requestId  The Request ID of a particular proposal user want to fulfill
     */
    function makePayment(uint256 proposalId,uint256 requestId) external OnlyProposalOwner(proposalId) voteOnlyIfRequestNotCompleted(proposalId,requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];

        if(thisRequest.noOfVoters > thisproposal.noOfContributors / 2){
            revert FundAllocation__NotEnoughVoters();
        }

        //transferring the funds to the recepient address
        uint256 transferAMount = thisRequest.value;
        thisRequest.value = 0;
        thisRequest.completed = true;
        thisproposal.raisedAmount -= transferAMount;

        (bool success, ) = thisRequest.recepient.call{value : transferAMount}("");

        if (!success) {
            revert FundAllocation__TransactionFailed();
        }
    }

    /**Getter Functions */

}