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
    address daoOwner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    //State Variables
    string proposalDescription = "Buy me a BMW M1000R";
    uint256 proposalDeadline = 99;
    uint256 proposalGoal = 100 ether;
    string requestDescription = "Atleast buy me Z900";
    uint256 requestDeadline = 99;
    uint256 requestGoal = 5 ether;

    function setUp() external {
        deployer = new DeployFundAllocation();
        fundAllocation = deployer.run();
    }

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
    
}