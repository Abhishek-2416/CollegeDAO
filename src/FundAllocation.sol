// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "../src/Token.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@4.7.0/security/ReentrancyGuard.sol";

contract FundAllocation is ReentrancyGuard {
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
    error FundAllocation__EnterAValidProposalId();
    error FundAllocation__EnterAValidRequestId();
    error FundAllocation__TheRequestHasReachedDeadline();
    error FundAllocation__ValueREquestedCannotBeHigherThanRemaningBalance();
    error FundAllocation__ActiveREquestCannotBeMoreThanOne();
    error FundAllocation__ARequestIsAlreadyActive();
    error FundAllocation__SoulBoundTokenAddressCantBeZero();
    error FundAllocation__TheDescriptionCannotBeEmpty();
    error FundAllocation__TheDeadlineCannotBeZero();
    error FundAllocation__RequestsCanBeCreatedOnlyAterContributionTimeIsExpired();
    error FundAllocation__APersonCannotVoteMoreThanOnce();

    struct Proposal {
        address ownerOfProposal;
        string mainDescription;
        uint256 deadline;
        uint256 goal;
        uint256 raisedAmount;
        uint256 noOfContributors;
        uint256 numRequest;
        uint256 amountSpentUntilNow;
        uint256 activeRequest;
        mapping(address => uint256) contributors;
        mapping(uint256 => Request) requests;
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
        uint256 proposalId;
        uint256 noOfYesVotes;
        uint256 noOfNoVotes;
        uint256 requestDeadline;
        mapping(address => Vote) voteStateInRequest;
    }

    /**Events */
    event ProposalCreatedForFunds(string indexed _mainDescription,uint256 indexed _goal,uint256 indexed _deadline);
    event Contributed(address indexed _sender,uint256 indexed _value);
    event CreateRequest(string _description,address _recepient,uint256 _value);
    event VoteRequested(address indexed voter,bool indexed Vote);
    event MakePayment(address _recepient,uint256 _value);
    event RequestCreated(uint256 indexed proposalId,string indexed description,address indexed recepient,uint256 value);
    event VoteCasted(address indexed voter,Vote indexed vote);
    event ChangeVoteRequest(address indexed voter,Vote indexed newVote);
    event PaymentMade(uint256 indexed proposalId,uint256 indexed requestId);

    constructor(address SoulBoundToken1){
        if(SoulBoundToken1 == address(0)){
            revert FundAllocation__SoulBoundTokenAddressCantBeZero();
        }
        token = Token(SoulBoundToken1);
    }

    receive() external payable{}

    /**Modifier */

    modifier OnlyProposalOwner(uint256 proposalId) {
        if(proposals[proposalId].ownerOfProposal != msg.sender){
            revert FundAllocation__NotTheOwnerOfProposal();
        }
        _;
    }

    modifier memberOfDAOOnly() {
        // if(token.balanceOf(msg.sender) == 0){
        //     revert FundAllocation__NotMemberOfTheDAO();
        // }
        _;
    }

    modifier activeProposalOnly(uint256 proposalId) {
        if(proposals[proposalId].deadline < block.timestamp ){
            revert FundAllocation__ThePropsalHasReachedDeadline();
        }
        _;
    }

    modifier activeRequestOnly(uint256 proposalId,uint256 requestId) {
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        if(thisRequest.requestDeadline < block.timestamp){
            revert FundAllocation__TheRequestHasReachedDeadline();
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

    modifier IfValidProposalId(uint256 proposalId) {
        if(proposalId > numProposals){
            revert FundAllocation__EnterAValidProposalId();
        }
        _;
    }

    modifier IfValidRequestIdOfTheSpecificProposalId(uint256 proposalId , uint256 requestId){
        Proposal storage thisProposal = proposals[proposalId];

        if(requestId > thisProposal.numRequest){
            revert FundAllocation__EnterAValidRequestId();
        }
        _;
    }

    modifier activeRequestsExists(uint256 proposalId){
        Proposal storage thisProposal = proposals[proposalId];

        if(thisProposal.activeRequest != 1){
            revert FundAllocation__ARequestIsAlreadyActive();
        }
        _;
    }

    modifier CreateRequestAfterContributionDeadline(uint256 proposalID) {
        if (proposals[proposalID].deadline > block.timestamp) {
            revert FundAllocation__RequestsCanBeCreatedOnlyAterContributionTimeIsExpired();
        }
        _;
    }

    modifier IfAlreadyVoted(uint256 proposalId,uint256 requestId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];
        if(thisRequest.voteStateInRequest[msg.sender] == Vote.Yes || thisRequest.voteStateInRequest[msg.sender] == Vote.No){
            revert FundAllocation__APersonCannotVoteMoreThanOnce();
        }
        _;
    }

    modifier PaymentCanBeMadeOnlyAfterRequestVotingTimeHasExpired(uint256 proposalId,uint256 requestId) {
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];
        _;
    }

    /**
     * 
     * @notice This function is to create a Proposal which require certain funds
     * @param _description  This is to describe why the poposal was created and what will it be used for 
     * @param _goal This is the amount of money needed for the campaign
     * @param _deadline This is to mention the time period of the campaign
     */
    function createProposal(string calldata _description, uint256 _goal,uint256 _deadline)
    external
    memberOfDAOOnly {
        if(_goal <= 0 ){
            revert FundAllocation__TheGoalAmountShouldBeGreaterThanZero();
        }

        if(bytes(_description).length == 0){
            revert FundAllocation__TheDescriptionCannotBeEmpty();
        }

        if(_deadline == 0){
            revert FundAllocation__TheDeadlineCannotBeZero();
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
    function contribute(uint256 proposalId,uint256 _value) external payable
    memberOfDAOOnly
    IfValidProposalId(proposalId)
    activeProposalOnly(proposalId){

        //Checking if they are sending money in for the first time
        if(_value <= 0){
            revert FundAllocation__TheValueSentShouldBeGreaterThanZero();
        }

        Proposal storage thisproposal = proposals[proposalId];

        if(thisproposal.contributors[msg.sender] == 0){
            thisproposal.noOfContributors++;
        }

        thisproposal.contributors[msg.sender] += _value;
        thisproposal.raisedAmount += _value;

        emit Contributed(msg.sender,_value);
    }

    /**
     * This function allows the owner of the Proposal to create a spending Request to spend the funds which were alloted to him
     * @param proposalId This is unique Id of the Proposal to know which Proposal we are going to allow to spend funds for
     * @param description This is a short description of to know for what does the owner of Proposal wants to spend the money
     * @param _recepient This is the person whom the funds will be transfered for the specific request
     * @param _value This is the value which will be requested by the owner which he can spend in this request
     */
    function CreateRequestToSpendFunds(uint256 proposalId,string calldata description,address payable _recepient,uint256 _value,uint256 _requestDeadline) external 
    memberOfDAOOnly
    OnlyProposalOwner(proposalId)
    IfValidProposalId(proposalId)
    CreateRequestAfterContributionDeadline(proposalId){
        Proposal storage thisproposal = proposals[proposalId];
        Request storage newRequest = thisproposal.requests[thisproposal.numRequest];

        if(_value <= 0){
            revert FundAllocation__TheValueSentShouldBeGreaterThanZero();
        }

        if(_value > getRemaningBalance(proposalId)){
            revert FundAllocation__ValueREquestedCannotBeHigherThanRemaningBalance();
        }

        if(_recepient == address(0)){
            revert FundAllocation__TheRecepientAddressCannotBeNullAddress();
        }

        if(_recepient == thisproposal.ownerOfProposal){
            revert FundAllocation__TheRecepientAddressCannotBeSameAsTheOwnerOfProposal();
        }

        if(thisproposal.activeRequest > 1){
            revert FundAllocation__ActiveREquestCannotBeMoreThanOne();
        }

        newRequest.requestdescription = description;
        newRequest.recepient = _recepient;
        newRequest.value = _value;
        newRequest.requestDeadline = block.timestamp + _requestDeadline;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        unchecked {
        thisproposal.activeRequest++;
        thisproposal.numRequest++;
        }

        emit RequestCreated(proposalId,description,_recepient,_value);
    }

    /**
     * This function will allow the member of DAO to vote if the speicific request should be approved or not
     * @param proposalId This to Id of the proposal which will contain the specific request
     * @param requestId This is the specific request Id which requires votes
     * @param vote This is the vote which should taken in by the members of the DAO
     */
    function voteRequest(uint256 proposalId,uint256 requestId,Vote vote) external
    memberOfDAOOnly
    IfValidProposalId(proposalId)
    activeRequestsExists(proposalId)
    activeRequestOnly(proposalId,requestId)
    IfAlreadyVoted(proposalId,requestId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId)
    voteOnlyIfRequestNotCompleted(proposalId,requestId){

        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];

        if(vote == Vote.Yes){
            thisRequest.voteStateInRequest[msg.sender] == Vote.Yes;

            unchecked {
            thisRequest.noOfYesVotes++;
            thisRequest.noOfVoters++;
            }

            emit VoteCasted(msg.sender,Vote.Yes);
            
        }else if(vote == Vote.No){
            thisRequest.voteStateInRequest[msg.sender] == Vote.No;

            unchecked {
            thisRequest.noOfNoVotes++;
            thisRequest.noOfVoters++;
            }

            emit VoteCasted(msg.sender,Vote.No);
        }
    }

    /**
     * @notice This function is to change the user's vote on a particular request of proposal proposal
     * @param proposalId The Id of the Proposal the user wants to vote on 
     * @param requestId The Id of the Request the user wants to vote on
     * @param vote The vote which the User wants to change to
     */
    function changeVoteForRequest(uint256 proposalId,uint256 requestId,Vote vote) external
    memberOfDAOOnly
    IfValidProposalId(proposalId)
    activeRequestsExists(proposalId)
    activeRequestOnly(proposalId,requestId)
    IfAlreadyVoted(proposalId,requestId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId)
    voteOnlyIfRequestNotCompleted(proposalId,requestId){

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
            emit VoteCasted(msg.sender,Vote.Yes);
        }else if(vote == Vote.No){
            thisRequest.noOfNoVotes++;
            thisRequest.voteStateInRequest[msg.sender] = Vote.No;
            emit VoteCasted(msg.sender,Vote.No);
        }

        emit ChangeVoteRequest(msg.sender,vote);
    }

    /**
     * @notice This function called by the proposal owner to approve and transfer the payment 
     * @param proposalId The unique Proposal Id where it should take place
     * @param requestId  The Request ID of a particular proposal user want to fulfill
     */
    function makePayment(uint256 proposalId,uint256 requestId) external 
    OnlyProposalOwner(proposalId)
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId)
    voteOnlyIfRequestNotCompleted(proposalId,requestId)
    nonReentrant{
        Proposal storage thisproposal = proposals[proposalId];
        Request storage thisRequest = thisproposal.requests[requestId];

        if (thisRequest.noOfVoters > thisRequest.noOfYesVotes){
            thisRequest.completed = true;
            thisproposal.activeRequest = 0;
        }
        else {
            //transferring the funds to the recepient address
            uint256 transferAMount = thisRequest.value;
            thisRequest.completed = true;
            thisproposal.raisedAmount -= transferAMount;
            thisproposal.amountSpentUntilNow += transferAMount;
            thisproposal.activeRequest = 0;

            (bool success, ) = thisRequest.recepient.call{value : transferAMount}("");

            if (!success) {
                revert FundAllocation__TransactionFailed();
            }

            emit PaymentMade(proposalId,requestId);
        }
    }

    /**Getter Functions */

    /**
     * @notice This function is used to get total amount requested by the owner to spend 
     * @param proposalId The proposal ID whose details user wants to view 
     */
    function getTotalAmountSpent(uint256 proposalId) public view 
    IfValidProposalId(proposalId)
    returns(uint256 x){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.amountSpentUntilNow;
    }

    /**
     * @notice this function is used to get the remaining balance of proposal so that the powner can raise aspend request accordingly 
     * @param proposalId The proposal ID whose details user wants to view 
     */
    function getRemaningBalance(uint256 proposalId) IfValidProposalId(proposalId) public view returns(uint256 x){
            Proposal storage thisProposal = proposals[proposalId];
            x = thisProposal.raisedAmount - thisProposal.amountSpentUntilNow;
    }

    /**
     * @notice This function is used to get the Owner of a particular proposal
     * @param proposalId The proposal ID whose details user wants to view
     */
    function getProposalOwner(uint256 proposalId) external view 
    IfValidProposalId(proposalId) 
    returns(address){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.ownerOfProposal;
    }

    /**
     * @notice This function is used to get the description of a particular proposal
     * @param proposalId The proposal ID whose details user wants to view
     */
    function getMainDescriptionOfProposal(uint256 proposalId) external view 
    IfValidProposalId(proposalId) 
    returns(string memory){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.mainDescription;
    }

    /**
     *  @notice This function gets the deadline time of a particular proposal
     * @param proposalId The proposal ID whose details user wants to view
     */
    function getProposalDeadline(uint256 proposalId) external view 
    IfValidProposalId(proposalId) 
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.deadline;
    }

    /**
     * @notice this function gets the goal amount of a particular proposal
     * @param proposalId The proposalID of the proposal whose goal amount the user wants to view
     */
    function getProposalGoal(uint256 proposalId) external view 
    IfValidProposalId(proposalId) 
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.goal;
    }

    /**
     * 
     * @param proposalId The proposalID of the proposal whose goal amount the user wants to view
     */
    function getTotalRaisedAmount(uint256 proposalId) external view 
    IfValidProposalId(proposalId) 
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.raisedAmount;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     */
    function getNoOfContributors(uint256 proposalId) external view 
    IfValidProposalId(proposalId)
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.noOfContributors;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     */
    function getNoOfRequests(uint256 proposalId) external view
    IfValidProposalId(proposalId)
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.numRequest;
    }

    /**
     * @notice returns the total number of proposals
     */
    function getNoOfProposals() external view returns(uint256){
        return numProposals;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param contributor The address of the person who has contributed
     */
    function getContributionBySpecificContributor(uint256 proposalId,address contributor) external view
    IfValidProposalId(proposalId)
    returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        return thisProposal.contributors[contributor];
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getDescriptionOfTheRequest(uint256 proposalId,uint256 requestId) external view
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(string memory){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.requestdescription;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getTheAddressOfTheRecepient(uint256 proposalId,uint256 requestId) external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(address){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.recepient;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getBoolIfRequestIsCompletedOrNot(uint256 proposalId,uint256 requestId) external view
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(bool){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.completed;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getNumberOfVotersForSpecificRequest(uint256 proposalId,uint256 requestId)external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.noOfVoters;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getNumberOfYesVotersForSpecificRequest(uint256 proposalId,uint256 requestId)external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.noOfYesVotes;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getNumberOfNoVotersForSpecificRequest(uint256 proposalId,uint256 requestId)external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.noOfNoVotes;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     * @param voter Address of the voter who has voted before
     */
    function getRequestAddressVote(uint256 proposalId,uint256 requestId,address voter) external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(Vote){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.voteStateInRequest[voter];
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     * @param requestId The requestId of that specific request
     */
    function getRequestDeadline(uint256 proposalId,uint256 requestId) external view 
    IfValidProposalId(proposalId)
    IfValidRequestIdOfTheSpecificProposalId(proposalId,requestId) returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];
        Request storage thisRequest = thisProposal.requests[requestId];

        return thisRequest.requestDeadline;
    }

    /**
     * 
     * @param proposalId The proposalID of that specific proposal
     */
    function getnumOfActiveRequest(uint256 proposalId) external view 
    IfValidProposalId(proposalId) returns(uint256){
        Proposal storage thisProposal = proposals[proposalId];

        return thisProposal.activeRequest;
    }

    /**
     * @notice it returns the address of the soulbound token
     */
    function getSoulBoundTokenAddress() external view returns(Token){
        return token;
    }
}