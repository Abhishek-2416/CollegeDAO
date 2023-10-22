// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test , console} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";
import {Token} from "../src/Token.sol";
import {DeployVoting} from "../script/DeployVoting.s.sol";
import {DeployToken} from "../script/DeployToken.s.sol";

contract TestVoting is Test {
    DeployVoting deployer;
    Voting voting;
    Token token;
    address daoOwner;

    event ProposalCreated(string indexed description, uint256 indexed proposalId);

    string actualDescription = "I am Dumb";
    uint256 deadline = 999;

    //making test addresses 
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() external{
        deployer = new DeployVoting();
        voting = deployer.run();
    }

    function testCreateProposalCounterIsWorking() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        assertEq(voting.getNumberOfProposals(),1);
    }

    function testCreateProposalMustHaveSameDeadline() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        assertEq(voting.getProposalDeadline(0),deadline + 1);
    }

    function testIfTheDescriptionOfProposalIsRight() public{
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        string memory expectedDescription = voting.getProposalDescription(0);
        assert(keccak256(abi.encodePacked(actualDescription)) == keccak256(abi.encodePacked(expectedDescription)));
    }

    function testEventemitsWhenProposalIsCalled() public {
        vm.prank(bob);
        vm.expectEmit(true,true,false,true);
        emit ProposalCreated(actualDescription,1);
        voting.createProposal(actualDescription,deadline);
    }

    function testcastVoteWorksOnlyWhenProposalIsActive() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);

        vm.warp(block.timestamp + deadline + 1);
        vm.expectRevert();
        voting.castVote(0,Voting.Vote.Yes);
    }

    function testcastVoteYesCounterWorks() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        voting.castVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(0),1);
    }

    function testcastVoteNoCounterWorks() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        voting.castVote(0,Voting.Vote.No);
        assertEq(voting.getProposalNoVotes(0),1);
    }

    function testChangeVoteWorksOnlyIfProposalIsActive() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        voting.castVote(0,Voting.Vote.Yes);
        vm.warp(block.timestamp + deadline + 1);
        vm.expectRevert();
        voting.changeVote(0,Voting.Vote.Yes);
    }

    function testChangeVoteWorksIfChangedToYes() public {
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        voting.castVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalYesVotes(0),1);
        voting.changeVote(0,Voting.Vote.No);
        assertEq(voting.getProposalYesVotes(0),0);
        assertEq(voting.getProposalNoVotes(0),1);
    }

    function testChangeVoteWorksIfChangedToNo() public{
        vm.prank(bob);
        voting.createProposal(actualDescription,deadline);
        voting.castVote(0,Voting.Vote.No);
        assertEq(voting.getProposalNoVotes(0),1);
        voting.changeVote(0,Voting.Vote.Yes);
        assertEq(voting.getProposalNoVotes(0),0);
        assertEq(voting.getProposalYesVotes(0),1);
    }
}