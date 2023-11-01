// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "./Token.sol";

contract Voting {
    Token token;

    /**
     * Errors
     */
    error Voting__NotAMemberOfTheDAO();
    error Voting__DeadlineExcedded();

    /**
     * Events
     */
    event ProposalCreated(string indexed description, uint256 indexed proposalId);
    

    //This is the possible options to vote for
    enum Vote {
        Yes,
        No
    }

    /**
     * Creating a Proposal contaning all the relevant information
     */
    struct Proposal {   
        string description;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => Vote) voteState; // To keep a track what the a paticular address has voted
    }

    //Creating a mapping of ID to Proposal to keep a track of all the Proposal created
    mapping(uint256 proposalId => Proposal) private proposals;
    uint256 private numProposals; //To keep a track of number of proposals created

    constructor(address members) payable {
        token = Token(members);
    }

    // Creating a modifier which allows the function to be called only by the people who own the NFT
    modifier memberOfDAOOnly() {
        if(token.balanceOf(msg.sender) == 0){
            revert Voting__NotAMemberOfTheDAO();
        }
        _;
    }

    modifier activeProposalOnly(uint256 proposalIndex) {
        if(proposals[proposalIndex].deadline <= block.timestamp){
            revert Voting__DeadlineExcedded();
        }
        _;
    }

    function createProposal(string calldata _description, uint256 _deadline) external {
        Proposal storage proposal = proposals[numProposals];

        proposal.description = _description;
        proposal.deadline = block.timestamp + _deadline;
        numProposals++;

        emit ProposalCreated(_description, numProposals);
    }

    function castVote(uint256 _proposalId, Vote vote) external  activeProposalOnly(_proposalId) {
        Proposal storage thisproposal = proposals[_proposalId];

        if (vote == Vote.Yes) {
            thisproposal.yesVotes++;
            thisproposal.voteState[msg.sender] = Vote.Yes;
        } else if (vote == Vote.No) {
            thisproposal.noVotes++;
            thisproposal.voteState[msg.sender] = Vote.No;
        }
    }

    function changeVote(uint256 _proposalId, Vote vote) external activeProposalOnly(_proposalId) {
        // clear out previous vote
        Proposal storage thisproposal = proposals[_proposalId];
        
        if (thisproposal.voteState[msg.sender] == Vote.Yes) {
            thisproposal.yesVotes--;
        }
        if (thisproposal.voteState[msg.sender] == Vote.No) {
            thisproposal.noVotes--;
        }

        if (vote == Vote.Yes) {
            thisproposal.yesVotes++;
            thisproposal.voteState[msg.sender] = Vote.Yes;
        } else if (vote == Vote.No) {
            thisproposal.noVotes++;
            thisproposal.voteState[msg.sender] = Vote.No;
        }
    }

    /**Getter Functions */

    function getNumberOfProposals() external view returns(uint256){
        return numProposals;
    }

    function getProposalDescription(uint256 proposalId) external view returns(string memory){
        Proposal storage proposal = proposals[proposalId];
        return proposal.description;
    }

    function getProposalYesVotes(uint256 proposalId) external view returns(uint256){
        Proposal storage proposal = proposals[proposalId];
        return proposal.yesVotes;
    }

    function getProposalNoVotes(uint256 proposalId) external view returns(uint256){
        Proposal storage proposal = proposals[proposalId];
        return proposal.noVotes;
    }

    function getProposalDeadline(uint256 proposalId) external view returns(uint256){
        Proposal storage proposal = proposals[proposalId];
        return proposal.deadline;
    }


}
