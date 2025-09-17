# Advanced Voting Mechanisms

This project demonstrates sophisticated voting systems beyond simple majority rule, including quadratic voting, conviction voting, ranked-choice voting, and advanced anti-manipulation measures.

## 🗳️ Voting Systems Overview

### 1. Simple Majority Voting
- Basic yes/no or multiple choice voting
- One token = one vote (or weighted by stake)
- Fixed voting periods
- Quorum and threshold requirements

### 2. Quadratic Voting
- Voice = √Credits spent
- Prevents wealth dominance through diminishing returns
- Encourages broad participation
- Multiple rounds with credit allocation

### 3. Ranked-Choice Voting (IRV)
- Voters rank options in order of preference
- Instant runoff eliminates least popular options
- Finds true majority preference
- Reduces strategic voting

### 4. Conviction Voting
- Support grows over time without fixed periods
- Continuous democracy with time-weighted preferences
- Dynamic thresholds based on proposal size
- Prevents last-minute manipulation

### 5. Weighted Voting
- Voting power based on stake, reputation, or other factors
- Multiple weighting mechanisms
- Anti-manipulation through minimum holding periods
- Sybil resistance

## 📋 Features

### Advanced Voting Mechanisms Contract
- **Multiple Voting Types**: Support for all major voting mechanisms
- **Anti-Manipulation**: Sybil detection, holding periods, maximum voting power
- **Delegation System**: Flexible delegation with weights and expiration
- **Reputation System**: Participation-based reputation with decay
- **Anonymous Voting**: Preparation for zk-SNARK integration

### Quadratic Voting System
- **Credit Management**: Flexible credit allocation and purchasing
- **Voting Rounds**: Time-bounded rounds with credit limits
- **Voice Calculation**: Democratic √Credits formula
- **Multiple Strategies**: Direct voting and weighted allocation

### Conviction Voting System
- **Time-Weighted Support**: Conviction grows with sustained support
- **Dynamic Thresholds**: Scales with requested funding amount
- **Treasury Integration**: Direct funding upon threshold reach
- **Flexible Support**: Change support levels at any time

## 🚀 Getting Started

### Prerequisites

```bash
npm install --save-dev hardhat @openzeppelin/contracts
```

### Installation

1. Clone the repository
2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
npx hardhat compile
```

4. Run tests:
```bash
npx hardhat test
```

## 📖 Usage Examples

### Basic Voting

```solidity
// Deploy advanced voting contract
AdvancedVotingMechanisms voting = new AdvancedVotingMechanisms(
    governanceToken,
    "VotingSystem",
    "1.0"
);

// Create simple proposal
uint256 proposalId = voting.createProposal(
    "Upgrade Protocol",
    "Should we upgrade to v2?",
    VotingType.SIMPLE,
    7 days,      // voting period
    1000,        // 10% quorum
    5100,        // 51% threshold
    ""           // no special params
);

// Cast vote
voting.vote(proposalId, VoteChoice.FOR, "Support the upgrade");
```

### Quadratic Voting

```solidity
// Deploy quadratic voting system
QuadraticVotingSystem qv = new QuadraticVotingSystem(
    stakeToken,
    100  // default credits per participant
);

// Register participant
qv.registerParticipant{value: 0.01 ether}();

// Create proposal with multiple options
string[] memory options = ["Option A", "Option B", "Option C"];
uint256 proposalId = qv.createProposal(
    "Budget Allocation",
    "How should we allocate the budget?",
    options,
    7 days,
    0  // not part of a round
);

// Vote with quadratic allocation
uint256[] memory optionIds = [0, 1, 2];
uint256[] memory credits = [25, 16, 9]; // Voice: 5, 4, 3
qv.voteQuadratic(proposalId, optionIds, credits);
```

### Conviction Voting

```solidity
// Deploy conviction voting system
ConvictionVotingSystem conviction = new ConvictionVotingSystem(
    stakingToken,
    100,      // conviction growth rate
    1000e18,  // minimum threshold
    100000e18 // spending limit
);

// Stake tokens to participate
conviction.stakeTokens(1000e18);

// Create funding proposal
uint256 proposalId = conviction.createProposal(
    "Community Development",
    "Fund development of community tools",
    50000e18,        // requested amount
    developerAddress // beneficiary
);

// Support proposal
conviction.supportProposal(proposalId, 500e18);

// Conviction grows over time...
// Anyone can update conviction
conviction.updateConviction(proposalId);

// Proposal executes automatically when threshold reached
```

### Delegation

```solidity
// Delegate 75% voting power for 30 days
voting.delegate(
    expertAddress,
    7500,                        // 75% weight
    block.timestamp + 30 days    // expiration
);

// Expert votes on behalf
voting.voteOnBehalf(
    delegatorAddress,
    proposalId,
    VoteChoice.FOR,
    "Voting as delegate"
);
```

## 🎯 Key Concepts

### Quadratic Voting Benefits
- **Democratic Voice**: √Credits prevents wealth dominance
- **Diminishing Returns**: Encourages broad participation
- **Nuanced Expression**: Multiple options with varying intensity
- **Strategic Allocation**: Voters optimize credit distribution

### Conviction Voting Benefits
- **Continuous Democracy**: No fixed voting periods
- **Time Preference**: Rewards sustained support
- **Manipulation Resistance**: Time-weighting prevents gaming
- **Organic Consensus**: Gradual community agreement

### Anti-Manipulation Features
- **Holding Periods**: Minimum token holding time
- **Sybil Detection**: Multiple detection mechanisms
- **Voting Power Caps**: Maximum influence per user
- **Reputation System**: Participation-based weighting

## 🔧 Configuration

### Voting Parameters

```solidity
// Set anti-manipulation parameters
voting.setAntiManipulationParams(
    7 days,      // minimum holding period
    1000000e18,  // maximum voting power
    100e18,      // Sybil threshold
    false        // require verification
);

// Configure conviction parameters
conviction.setConvictionParams(
    150,         // conviction growth rate
    1000e18,     // minimum threshold
    1000000e18   // spending limit
);
```

### Credit Distribution

```solidity
// Set quadratic voting distribution method
qv.setDistributionMethod(CreditDistribution.STAKE_BASED);

// Allocate credits for round
uint256 roundId = qv.startQVRound(
    "Q1 2024 Round",
    30 days,     // duration
    100,         // credits per participant
    50           // max credits per proposal
);
```

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/AdvancedVoting.test.js

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

## 📊 Voting Comparison

| Mechanism | Best For | Pros | Cons |
|-----------|----------|------|------|
| Simple Majority | Basic decisions | Easy to understand | Wealth dominance |
| Quadratic | Preference intensity | Democratic voice | Complex calculation |
| Ranked-Choice | Multiple options | True majority | Implementation complexity |
| Conviction | Funding decisions | Time preference | Slower decisions |
| Weighted | Stake-based | Aligned incentives | Potential centralization |

## 🔮 Advanced Features

### Anonymous Voting Preparation
```solidity
// Commit-reveal scheme
bytes32 commitment = keccak256(abi.encodePacked(choice, nonce, voter));
voting.commitVote(proposalId, commitment);

// Later reveal
voting.revealVote(proposalId, choice, nonce);
```

### Multi-Signature Integration
```solidity
// Require multiple signatures for proposal execution
voting.setMultiSigRequirement(3, 5); // 3 of 5 signatures
```

### Time-Locked Execution
```solidity
// Delay execution after passing
voting.setExecutionDelay(2 days);
```

## 📚 Additional Resources

- [Quadratic Voting Research](https://www.microsoft.com/en-us/research/project/quadratic-voting/)
- [Conviction Voting Documentation](https://github.com/1Hive/conviction-voting-app)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/governance)
- [Aragon Voting](https://aragon.org/voting)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Advanced voting mechanisms for sophisticated democratic governance in DAOs and blockchain protocols.*