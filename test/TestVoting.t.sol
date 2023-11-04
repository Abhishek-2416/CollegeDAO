// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {Voting} from "../src/Voting.sol";
import {console} from "forge-std/Test.sol";
import {DeployToken} from "../script/DeployToken.s.sol";
import {DeployVoting} from "../script/DeployVoting.s.sol";

contract TestVoting is Test {
    DeployVoting deployer;
    Voting voting;

    DeployToken deployerToken;
    Token token;

    //Making Addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address daoOwner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    //State Variables
    string actualDescription = "Buy me a BMW M1000R";
    uint256 actualDeadline = 99;

    //Events
    event ProposalCreated(string indexed description, uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId,address indexed voter);

    function setUp() external {
        deployer = new DeployVoting();
        voting = deployer.run();

        deployerToken = new DeployToken();
        token = deployerToken.run();
    }

    function testIfCreateProposalWorks() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
    }

    function testIfDescriptionIsCorrect() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        assertEq(keccak256(abi.encodePacked(actualDescription)),keccak256(abi.encodePacked("Buy me a BMW M1000R")));
    }

    function testIfDeadlineIsCorrect() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        assertEq(voting.getProposalDeadline(0),block.timestamp + actualDeadline);
    }

    function testCannotCreateProposalWhenDeadlineIsZero() external {
        vm.prank(bob);
        vm.expectRevert();
        voting.createProposal(actualDescription,0);
    }

    function testCannotCreateProposalWhenDescriptionIsNull() external {
        vm.prank(bob);
        vm.expectRevert();
        voting.createProposal("",actualDeadline);
    }

    function testThePropsalCountIncreasesWhenCreated() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        assertEq(voting.getNumberOfProposals(),1);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        assertEq(voting.getNumberOfProposals(),2);
    }

    function testAnEventIsEmittedWhenCreateProposal() external {
        vm.prank(bob);
        vm.expectEmit(true,true,false,true);
        emit ProposalCreated(actualDescription,1);
        voting.createProposal(actualDescription,actualDeadline);

        vm.prank(alice);
        vm.expectEmit(true,true,false,true);
        emit ProposalCreated(actualDescription,2);
        voting.createProposal(actualDescription,actualDeadline);
    }

    function testCastVoteWorks() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.Yes);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(1,Voting.Vote.No);
    }

    function testCastVoteDoesntWorkWhenProposalNotActive() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        vm.warp(block.timestamp + voting.getProposalDeadline(0));
        vm.expectRevert();
        voting.castVote(0,Voting.Vote.No);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        vm.warp(block.timestamp + voting.getProposalDeadline(1));
        vm.expectRevert();
        voting.castVote(0,Voting.Vote.Yes);
    }

    function testTheNumberOfYesVotesDoesIncrease() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(0),1);
        assert(voting.getVoteStateOfSpecificUser(0) == Voting.Vote.Yes);

        vm.prank(alice);
        voting.castVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(0),2);
        assert(voting.getVoteStateOfSpecificUser(0) == Voting.Vote.Yes);
    }

    function testTheNumberOfNoVotesDoesIncrease() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.No);
        assertEq(voting.getProposalNoVotes(0),1);
        assert(voting.getVoteStateOfSpecificUser(0) == Voting.Vote.No);

        vm.prank(alice);
        voting.castVote(0,Voting.Vote.No);
        assertEq(voting.getProposalNoVotes(0),2);
        assert(voting.getVoteStateOfSpecificUser(0) == Voting.Vote.No);
    }

    function testWhenSinglePersonCannotCastVoteTwice() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.Yes);
        vm.expectRevert();
        voting.castVote(0,Voting.Vote.No);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(1,Voting.Vote.No);
        vm.expectRevert();
        voting.castVote(1,Voting.Vote.Yes);
    }

    function testChangeVoteDoesntWorkWhenProposalNotActive() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.Yes);
        vm.warp(block.timestamp + actualDeadline);
        vm.expectRevert();
        voting.changeVote(0,Voting.Vote.Yes);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(1,Voting.Vote.No);
        vm.warp(block.timestamp + actualDeadline);
        vm.expectRevert();
        voting.changeVote(1,Voting.Vote.Yes);
    }

    function testChangeVoteWorks() external {
        vm.prank(bob);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(0),1);
        assertEq(voting.getProposalNoVotes(0),0);
        voting.changeVote(0,Voting.Vote.No);
        assertEq(voting.getProposalYesVotes(0),0);
        assertEq(voting.getProposalNoVotes(0),1);

        vm.prank(alice);
        voting.createProposal(actualDescription,actualDeadline);
        voting.castVote(1,Voting.Vote.No);
        assertEq(voting.getProposalYesVotes(1),0);
        assertEq(voting.getProposalNoVotes(1),1);
        voting.changeVote(1,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(1),1);
        assertEq(voting.getProposalNoVotes(1),0);
    }
}