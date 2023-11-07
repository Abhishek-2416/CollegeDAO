// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {console} from "forge-std/Test.sol";
import {DeployToken} from "../script/DeployToken.s.sol";
import {FundAllocation} from "../src/FundAllocation.sol";
import {DeployFundAllocation} from "../script/DeployFundAllocation.s.sol";

contract TestFundAllocation is Test {
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

    //Events
    event ProposalCreatedForFunds(string indexed _mainDescription,uint256 indexed _goal,uint256 indexed _deadline);
    event Contributed(address indexed _sender,uint256 indexed _value);
    event RequestCreated(uint256 indexed proposalId,string indexed description,address indexed recepient,uint256 value);

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

    
}