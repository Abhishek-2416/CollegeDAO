// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts@4.7.0/access/Ownable.sol";
import {Token} from "./Token.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";

contract Voting is Ownable{
    Token token;

    /**Errors */
    error Voting__NotAMemberOfTheDAO();
    error Voting__DeadlineExcedded();

    /**Events */
    event ProposalCreated(string indexed description, uint256 indexed proposalId);


    /**Creating a Proposal contaning all the relevant information  */
    struct Proposal {
        string description;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed; //wether or not this propsal has been executed yet. Cannot be executed before the deadline has been executed
        mapping(address => bool) voters; // a mapping of nft tokenIds to booleans indicating wether that NFT has already been used  to caste a vote or not
    }

    //This is the possible options to vote for
    enum Vote{Yes,No}

    //Creating a mapping of ID to Proposal to keep a track of all the Proposal created
    mapping(uint256 => Proposal) private proposals; 
    uint256 private numProposals; //To keep a track of number of proposals created

    //Creating a modifier which allows the function to be called only by the people who own the NFT
    modifier memberOfDAOOnly() {
        if(token.balanceOf(msg.sender)>0){
            revert Voting__NotAMemberOfTheDAO();
        }
        _;
    }

    modifier activeProposalOnly(uint256 proposalIndex) {
        if(proposals[proposalIndex].deadline > block.timestamp){
            revert Voting__DeadlineExcedded();
        }
        _;
    }

    function createProposal(string calldata _description,uint256 _deadline) external memberOfDAOOnly{
        Proposal storage proposal = proposals[numProposals];
        proposal.description = _description;
        proposal.deadline = _deadline;
        emit ProposalCreated(_description,numProposals);
    }

    function castVote(uint256 _proposalId,Vote vote) external memberOfDAOOnly activeProposalOnly(_proposalId){
        Proposal storage proposal = proposals[_proposalId];
        if(vote == Vote.Yes){
            proposal.yesVotes++;
        }else if(vote == Vote.No){
            proposal.noVotes++;
        }
    }


}