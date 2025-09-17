# Assignment 2: Voting System

Create a simple voting system for proposals with time limits and access controls.

##  Objective

Build a contract that allows users to create proposals and vote on them within specified time limits.

##  Requirements

### Data Structures

```solidity
struct Proposal {
    uint256 id;
    string title;
    string description;
    address proposer;
    uint256 yesVotes;
    uint256 noVotes;
    uint256 deadline;
    bool executed;
}

mapping(uint256 => Proposal) public proposals;
mapping(uint256 => mapping(address => bool)) public hasVoted;
```

### Core Functions

```solidity
function createProposal(string memory title, string memory description, uint256 votingPeriod) public
function vote(uint256 proposalId, bool support) public
function executeProposal(uint256 proposalId) public
function getProposal(uint256 proposalId) public view returns (Proposal memory)
```

##  Requirements Checklist

- [ ] Anyone can create proposals
- [ ] Voters can only vote once per proposal
- [ ] Voting must be within the deadline
- [ ] Proposals can be executed after deadline if majority yes
- [ ] Events emitted for all major actions
- [ ] Proper time validation

##  Test Scenarios

1. Create a proposal
2. Vote yes and no from different accounts
3. Try voting twice from same account (should fail)
4. Try voting after deadline (should fail)
5. Execute proposal with majority votes

---

**Estimated Time**: 3-4 hours
