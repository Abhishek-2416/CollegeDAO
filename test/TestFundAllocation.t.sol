// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {console} from "forge-std/Test.sol";
import {DeployToken} from "../script/DeployToken.s.sol";
import {FundAllocation} from "../src/FundAllocation.sol";
import {DeployFundAllocation} from "../script/DeployFundAllocation.s.sol";

contract TestFundAllocation is Test {
    Token token;
    DeployFundAllocation deployer;
    FundAllocation fundAllocation;

    //Making Addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address payable janice = payable(makeAddr("janice"));
    address daoOwner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    //State Variables
    string proposalDescription = "Buy me a BMW M1000R";
    uint256 proposalDeadline = 99;
    uint256 proposalGoal = 100 ether;
    string requestDescription = "Atleast buy me Z900";
    uint256 requestDeadline = 99;
    uint256 requestGoal = 5 ether;
    uint256 contributeAmount = 50 ether;

    //Enums
    enum Vote{Yes,No}

    //Events
    event ProposalCreatedForFunds(string indexed _mainDescription,uint256 indexed _goal,uint256 indexed _deadline);
    event Contributed(address indexed _sender,uint256 indexed _value);
    event RequestCreated(uint256 indexed proposalId,string indexed description,address indexed recepient,uint256 value);
    event VoteCasted(address indexed voter,Vote indexed vote);
    event ChangeVoteRequest(address indexed voter,Vote indexed newVote);
    event PaymentMade(uint256 indexed proposalId,uint256 indexed requestId);

    function setUp() external {
        deployer = new DeployFundAllocation();
        fundAllocation = deployer.run();
    }

    /////////////////////////////////
    /// Function Create Proposal ////
    /////////////////////////////////

    function testIfDescriptionOfProposalIsCorrect() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(keccak256(abi.encodePacked(fundAllocation.getMainDescriptionOfProposal(0))),keccak256(abi.encodePacked(proposalDescription)));
    }

    function testIfGoalForProposalIsCorrectOrNot() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(proposalGoal,100 ether);
    }
    
    function testIfTheProposalDeadlineIsCorrect() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(proposalDeadline,99);
    }

    function testCreateProposalCanOnlyBeCalledByMemberOfDAO() external {

    }

    function testTheGoalOfProposalCannotBeZero() external {
        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.createProposal(proposalDescription,0,proposalDeadline);
    }

    function testTheDescriptionInTheProposalCannotBeEmpty() external {
        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.createProposal("",proposalGoal,proposalDeadline);
    }

    function testTheDeadlineOfProposalCannotBeZero() external {
        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.createProposal(proposalDescription,proposalGoal,0);
    }

    function testTheProposalCountIncreases() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(fundAllocation.getNoOfProposals(),1);

        vm.prank(alice);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(fundAllocation.getNoOfProposals(),2);
    }

    function testTheOwnerOfProposalIsRight() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(fundAllocation.getProposalOwner(0),bob);

        vm.prank(alice);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        assertEq(fundAllocation.getProposalOwner(1),alice);
    }

    function testCreateProposalEmitsAnEvent() external {
        vm.prank(bob);
        vm.expectEmit(true,true,true,true);
        emit ProposalCreatedForFunds(proposalDescription,proposalGoal,proposalDeadline);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        //Testing where the event is emitted by different address
        vm.prank(alice);
        vm.expectEmit(true,true,true,true);
        emit ProposalCreatedForFunds(proposalDescription,proposalGoal,proposalDeadline);
        vm.expectRevert();
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
    }

    ////////////////////////////
    /// Function Contribute ////
    ////////////////////////////

    function testTheContributeFunctionCanBeCalledByDAOMemeber() external {

    }

    //Testing where the value sent to contribute cannot be zero
    function testTheValueForContributeFunctionCannotBeZero() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.contribute(0,0);
    }

    //Owner Cannot contribute to its own proposal
    function testTheOwnerCannotContributeToItsOwnProposal() external {
        /**
         * Learnt a new thing whenever we are calling a multiple function 
         * we need to call vm.prank() either twice 
         * Or else we need to vm.startPrank() and vm.stopPrank(); instead calling it twice
         */
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        console.log(fundAllocation.getProposalOwner(0));
        
        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.contribute(0,contributeAmount);

        vm.startPrank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        vm.expectRevert();
        fundAllocation.contribute(0,contributeAmount);
        vm.stopPrank();
    }

    //test where to contribute it should have a valid proposalId
    function testContributeWorksWithValisProposalId() external {
        vm.startPrank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        console.log(fundAllocation.getNoOfProposals());
        vm.expectRevert();
        fundAllocation.contribute(1,contributeAmount);
        vm.stopPrank();
    }

    //Test the contribute function cannot work after deadline
    function testContributeDoesNotWorkWhenDeadlineExpired() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.contribute(0,contributeAmount);
    }

    //Test If the No of Contributors should increase
    function testTheNumberOfContributorsIncrease() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        
        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getNoOfContributors(0),1);

        vm.prank(janice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getNoOfContributors(0),2);
    }

    //Test where the raised amount increases when contributed
    function testTheRaisedAmountIncreasesEveryValueSent() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getTotalRaisedAmount(0),contributeAmount);

        vm.prank(janice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getTotalRaisedAmount(0),contributeAmount*2);
    }

    //Test if the indivual balance increases when contributed
    function testIfIndivualBalanceOfContributorsGetsUpated() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getContributionBySpecificContributor(0,alice),contributeAmount);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        assertEq(fundAllocation.getContributionBySpecificContributor(0,alice),contributeAmount*2);
    }

    //Test the event emits when called the contribute function
    function testContributedEventEmitsWhenCalledIt() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        vm.expectEmit(true,true,false,false);
        emit Contributed(alice,contributeAmount);
        fundAllocation.contribute(0,contributeAmount);
    }

    //Testing when one person contributes twice the noOfContributors wont increase
    function testTheNoOfContributorsDontIncreaseWhenContributedTwice() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        assertEq(fundAllocation.getNoOfContributors(0),1);
    }

    ///////////////////////////////////////////
    /// Function CreateRequestToSpendFunds ////
    ///////////////////////////////////////////

    //Modifers
    modifier BaseForCreateRequestoSpendFunds{
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        _;
    }

    //The function can Be called just by members of DAO
    function testCreateRequestToSpendFundsIsMemberOfDAO() external BaseForCreateRequestoSpendFunds{

    }

    /**
     * @notice The test to see if CreateRequestToSpendFunds can be called by Proposal Owner only
     */
    function testCreateRequestToSpendFundsCanBeCalledByProposalOwnerOnly() external BaseForCreateRequestoSpendFunds {
        vm.startPrank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        vm.stopPrank();

        //Testing where it should fail when not called by the owner
        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
    }

    /**
     * @notice Check If the proposalId entered is correct or not
     */
    function testCreateRequestToSpendFundsCannotWorkWithWrongProposalId() external BaseForCreateRequestoSpendFunds{
        vm.startPrank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(1,requestDescription,janice,requestGoal,requestDeadline);
        vm.stopPrank();
    }

    /**
     * @notice A request can be created just after the proposal deadline has ended
     */
    function testCreateRequestToSpendFundsCanBeCalledOnlyAfterDeadline() external BaseForCreateRequestoSpendFunds {
        //Here the deadline hasnt reached so it shouldnt be able to make a request
        vm.startPrank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        vm.stopPrank();
    }

    /**
     * @notice The value sent cannot be zero
     */
    function testTheValueCannotBeZeroForCreatingRequests() external BaseForCreateRequestoSpendFunds{
        vm.startPrank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,0,requestDeadline);
        vm.stopPrank();
    }

    /**
     * @notice The value obviously cannot be more than the remaning balance
     */
    function testTheValueCannotBeMoreThanTheRemaningBalance() external BaseForCreateRequestoSpendFunds{
        vm.startPrank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,proposalGoal,requestDeadline);
        vm.stopPrank();
    }

    /**
     * @notice Test to make sure the recepient address cannot be a null address
     */
    function testTheRecepientAddressCannotBeNull() external BaseForCreateRequestoSpendFunds{
        vm.startPrank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,payable(address(0x0)),proposalGoal,requestDeadline);
        vm.stopPrank();
    }

    /**
     * @notice The functon description cannot be empty
     */
    function testTheDescriptionForRequestCannotBeEmpty() external BaseForCreateRequestoSpendFunds {
        vm.startPrank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,"",janice,requestGoal,requestDeadline);
    }

    /**
     * @notice Test to make sure the recepient address cannot be proposal owner 
     */
    function testTheRecepientAddressCannotBeTheProposalOwner() external BaseForCreateRequestoSpendFunds {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);
        
        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,payable(bob),requestGoal,requestDeadline);
    }

    /**
     * @notice Test to check we cannot create another request when one request is already active
     */
    function testFailCannotCreateAnotherRequestWhenOneIsAlreadyActive() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);

        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
    }

    /**
     * @notice Test to check The requestDescription is correct or not
     */
    function testRequestCreatedDescrptionIsCorrectOrNot() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(
            keccak256(abi.encodePacked(fundAllocation.getDescriptionOfTheRequest(0,0))),
            keccak256(abi.encodePacked("Atleast buy me Z900"))
            );
    }

    /**
     * @notice Test tot check if the recepient address is correct or not
     */
    function testIfRecepientIsSameOrNot() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getTheAddressOfTheRecepient(0,0),janice);
    }

    /**
     * @notice Test to see if the value sent to them is also correct or not
     */
    function testTheValueForRequestIsCorrectOrNot() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getGoalOfTheRequest(0,0),requestGoal);
    }

    /**
     * @notice Test ti check the deadline of the request made
     */
    function testTheDeadlineOfRequestCreated() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getRequestDeadline(0,0), block.timestamp + requestDeadline);
    }

    /**
     * @notice to test the intial condition of completed is false
     */
    function testTheStateOfCompletedInCreateRequestIsFalse() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assert(fundAllocation.getBoolIfRequestIsCompletedOrNot(0,0) == false);
    }

    /**
     * @notice Test to check the number of voters is zero when proposal is created
     */
    function testTheNumberOfVotersShouldBeZeroAtStart() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getNumberOfNoVotersForSpecificRequest(0,0),0);
    }

    /**
     * @notice To test the no Of activeRequests increase
     */
    function testTheNumberOfActiveRequestIncrease() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getnumOfActiveRequest(0),1);

        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getnumOfActiveRequest(0),2);
    }

    /**
     * @notice To test the no Of Requests increase
     */
    function testTheNumberOfRequestIncrease() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getNoOfRequests(0),1);

        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        assertEq(fundAllocation.getNoOfRequests(0),2);
    }

    /**
     * @notice To Check if the event RequestCreated get emitted
     */
    function testIfTheRequestCreatedEventGetsEmitted() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        vm.expectEmit(true,true,true,true);
        emit RequestCreated(0,requestDescription,janice,requestGoal);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
    }

    /////////////////////////////
    /// Function VoteRequest ////
    /////////////////////////////

    modifier BaseModiferForVoteRequest {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);
        _;
    }

    /**
     * @notice Test it can only be called by the members of the DAO
     */
    function testVoteRequestCanOnlyBeCalledByMemeberOfDAO() external {

    }
    
    /**
     * @notice It should works if it has a propoer Proposal Id
     */
    function testRevertIfInvalidProposalId() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);

        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.voteRequest(1,0,FundAllocation.Vote.No);
    }

    /**
     * @notice Test To check if reverts the request is Not active
     */
    function testTheRequestShouldBeActive() external BaseModiferForVoteRequest {
        vm.warp(block.timestamp + fundAllocation.getRequestDeadline(0,0));

        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
    }

    /**
     * @notice Test to see One Person cannot vote twice
     */
    function testOnePersonCannotVoteTwice() external BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
    }

    /**
     * @notice Test to see it reverts when the Request is Not Completed
     */
    function testCannotVoteWhenTheRequestIsInStateCompleted() external 
    BaseModiferForVoteRequest {
        vm.prank(bob);
    }

    /**
     * @notice Test to see the owner of proposal cannot vote
     */
    function testTheOwnerOfProposalCannotVote() external 
    BaseModiferForVoteRequest {
        vm.prank(bob);
        vm.expectRevert();
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
    }

    /**
     * @notice The recepient cannot vote
     */
    function testTheRecepientOfRequestCannotVote() external 
    BaseModiferForVoteRequest {
        vm.prank(janice);
        vm.expectRevert();
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
    }

    /**
     * @notice To check if the Vote State in Requests gets updated
     */
    function testIfTheVoteStatevoteInRequestsGetsUpdatedCorectly() external
    BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
        assert(fundAllocation.getRequestAddressVote(0,0,msg.sender) == FundAllocation.Vote.Yes);

        vm.prank(daoOwner);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
        assert(fundAllocation.getRequestAddressVote(0,0,msg.sender) == FundAllocation.Vote.No);
    }

    /**
     * @notice To check if the VoteState gets updated or no
     */
    function testIfTheVoteStateInRequestsGetsUpdatedCorrectly() external
    BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
        assertEq(fundAllocation.getRequestAddressVoteState(0,0,alice),true);

        assertEq(fundAllocation.getRequestAddressVoteState(0,0,daoOwner),false);
    }

    /**
     * @notice To check if the Number of Yes votes increase
     */
    function testTheNumberOfYesVotesIncreases() external 
    BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
        assertEq(fundAllocation.getNumberOfYesVotersForSpecificRequest(0,0),1);
        assertEq(fundAllocation.getNumberOfNoVotersForSpecificRequest(0,0),0);
    }

    /**
     * @notice To check if the number of No Votes increases
     */
    function testNumberOfNoVotesIncrease() external
    BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
        assertEq(fundAllocation.getNumberOfNoVotersForSpecificRequest(0,0),1);
        assertEq(fundAllocation.getNumberOfYesVotersForSpecificRequest(0,0),0);
    }

    /**
     * @notice To check if the total Number of Votes increase
     */
    function testTheTotalNumberOfVotersIncrease() external 
    BaseModiferForVoteRequest {
        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);
        assertEq(fundAllocation.getNumberOfVotersForSpecificRequest(0,0),1);

        vm.prank(daoOwner);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
        assertEq(fundAllocation.getNumberOfVotersForSpecificRequest(0,0),2);
    }

    /**
     * @notice to check if the event VoteCasted gets emitted
     */
    function testTheEventEmitsWhenVoted() external 
    BaseModiferForVoteRequest {
        vm.prank(alice);
        vm.expectEmit(true,true,false,false);
        emit VoteCasted(alice,Vote.Yes);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(daoOwner);
        vm.expectEmit(true,true,false,false);
        emit VoteCasted(daoOwner,Vote.No);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
    }

    ////////////////////////////////////
    /// Function ChangeVoteRequest /////
    ///////////////////////////////////

    modifier BaseConditionForChangeVoteRequest{
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);

        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(daoOwner);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);
        _;
    }

    /**
     * @notice This is to check the previous vote gets cleared and new is added
     */
    function testThePreviousVoteGetsClearedAndNewIsAdded() external 
    BaseConditionForChangeVoteRequest {
        vm.prank(alice);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.No);
        assertEq(fundAllocation.getNumberOfYesVotersForSpecificRequest(0,0),0);
        assertEq(fundAllocation.getNumberOfNoVotersForSpecificRequest(0,0),2);

        vm.prank(daoOwner);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.Yes);
        assertEq(fundAllocation.getNumberOfYesVotersForSpecificRequest(0,0),1);
        assertEq(fundAllocation.getNumberOfNoVotersForSpecificRequest(0,0),1);
    }

    /**
     * @notice To check if the VoteState In Request Changes Or not 
     */
    function testTheVoteStateChangesWithChangeInVote() external 
    BaseConditionForChangeVoteRequest {
        vm.prank(alice);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.No);
        assert(fundAllocation.getRequestAddressVote(0,0,alice) == FundAllocation.Vote.No);

        vm.prank(daoOwner);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.Yes);
        assert(fundAllocation.getRequestAddressVote(0,0,daoOwner) == FundAllocation.Vote.Yes);
    }

    /**
     * @notice We need to check if the VoteCasted function is emitted or not
     */
    function testVoteCastedEventIsEmittedOrNot() external 
    BaseConditionForChangeVoteRequest {
        vm.prank(alice);
        vm.expectEmit(true,true,false,false);
        emit VoteCasted(alice,Vote.No);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.No);

        vm.prank(daoOwner);
        vm.expectEmit(true,true,false,false);
        emit VoteCasted(daoOwner,Vote.Yes);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.Yes);
    }

    /**
     * @notice The ChangeVote Function emits an Event
     */
    function theChangeVoteEmitsAnEvent() external 
    BaseConditionForChangeVoteRequest {
        vm.prank(alice);
        vm.expectEmit(true,true,false,false);
        emit ChangeVoteRequest(alice,Vote.No);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.No);

        vm.prank(daoOwner);
        vm.expectEmit(true,true,false,false);
        emit ChangeVoteRequest(daoOwner,Vote.Yes);
        fundAllocation.changeVoteForRequest(0,0,FundAllocation.Vote.Yes);
    }

    //////////////////////////////
    /// Function MakePayment /////
    /////////////////////////////

    modifier BaseConditionForMakePayment{
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);

        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(daoOwner);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);

        _;
    }

    /**
     * @notice The function can only be called by the owner of the proposal
     */
    function testThisFunctionCanOnlyBeCalledByTheOwnerOfProposal() external 
    BaseConditionForMakePayment {
        vm.prank(bob);
        fundAllocation.makePayment(0,0);

        vm.prank(alice);
        vm.expectRevert();
        fundAllocation.makePayment(0,0);
    }

    /**
     * @notice This Condition where When No of No Votes is greater then completed is true
     */
    function testWhenNoOfNoVotesIsGreater() external 
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getCompletedOrNot(0,0),true);
    }

    /**
     * @notice When the no of NoVotes is more the Active Request sets to zero
     */
    function testTheActiveRequestsResetsToZeroWhenMoreNoVotes() external
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getnumOfActiveRequest(0),0);
    }

    /**
     * @notice When the number of NoVotes and YesVotes are the Same
     */
    function testTheNumberOfNoVotesAndYesVotesAreTheSame() external 
    BaseConditionForMakePayment {
        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getCompletedOrNot(0,0),true);
        assertEq(fundAllocation.getnumOfActiveRequest(0),0);
    }

    /**
     * @notice When The No of Yes Votes is More Where We Check the completed is true
     */
    function theWhenTheNoOfYesVotesIsMoreThenCompletedIsTrue() external
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getCompletedOrNot(0,0),true);
    }

    /**
     * @notice Deducting the transferAmount from raisedAmount
     */
    function theTestWhereRaisedAmountAfterMakingPayment() external
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getTotalRaisedAmount(0),proposalGoal-requestGoal);
    }

    /**
     * @notice Check the Amount spent until till now
     */
    function theTestToCheckTheAmountSpentTillNow() external 
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getTotalAmountSpent(0),proposalGoal-requestGoal);
    }

    /**
     * @notice The active Request becomes zero
     */
    function theTestWhereTheActiveRequestIsZero() external
    BaseConditionForMakePayment {
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(fundAllocation.getnumOfActiveRequest(0),0);
    }

    /**
     * @notice The amount should be transffered ti recepient
     */
    function theTestWhereTheAmountIsTransferedToRecepient() external {
        vm.prank(bob);
        fundAllocation.createProposal(proposalDescription,proposalGoal,proposalDeadline);

        vm.prank(alice);
        fundAllocation.contribute(0,contributeAmount);

        vm.prank(bob);
        vm.warp(block.timestamp + fundAllocation.getProposalDeadline(0));

        vm.prank(bob);
        fundAllocation.CreateRequestToSpendFunds(0,requestDescription,janice,requestGoal,requestDeadline);

        vm.prank(alice);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(daoOwner);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.No);

        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.prank(bob);
        fundAllocation.makePayment(0,0);
        assertEq(token.balanceOf(janice),proposalGoal-requestGoal);
    }

    /**
     * @notice The PaymentMade event is emitted when we call makePayment
     */
    function testThePaymentMadeIsEmittedWhenMakePaymentIsCalled() external 
    BaseConditionForMakePayment{
        address abhishek = makeAddr("abhishek");
        vm.prank(abhishek);
        fundAllocation.voteRequest(0,0,FundAllocation.Vote.Yes);

        vm.startPrank(bob);
        vm.expectEmit(true,true,false,true);
        emit PaymentMade(0,0);
        fundAllocation.makePayment(0,0);
        vm.stopPrank();
    }
}