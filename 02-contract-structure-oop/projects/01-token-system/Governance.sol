// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AccessControl.sol";

/**
 * @title Governance
 * @dev Simple proposal and voting system for token governance
 * @notice Demonstrates modular design, events, and OOP patterns
 */
contract Governance is AccessControl {
    struct Proposal {
        uint256 id;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }

    uint256 public nextProposalId;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string description
    );
    event Voted(uint256 indexed id, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed id);

    function createProposal(
        string calldata description,
        uint256 duration
    ) external onlyRole(ADMIN_ROLE) {
        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            description: description,
            proposer: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });
        emit ProposalCreated(nextProposalId, msg.sender, description);
        nextProposalId++;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.startTime &&
                block.timestamp <= proposal.endTime,
            "Governance: voting closed"
        );
        require(!hasVoted[proposalId][msg.sender], "Governance: already voted");
        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            proposal.forVotes++;
        } else {
            proposal.againstVotes++;
        }
        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp > proposal.endTime,
            "Governance: voting not ended"
        );
        require(!proposal.executed, "Governance: already executed");
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
        // Add custom logic for proposal execution
    }
}
