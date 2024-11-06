// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ComplexVotingSystem {
    address public admin;
    bool public votingStarted;
    bool public votingEnded;
    uint public totalWeight; // Total weight of all registered voters

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    struct Voter {
        bool hasVoted;
        uint weight; // Weight of the vote
        uint votedCandidateId;
        address delegate;
    }

    mapping(uint => Candidate) public candidates;
    mapping(bytes32 => Voter) public voters;
    uint public candidatesCount;

    event CandidateAdded(uint id, string name);
    event VoterRegistered(bytes32 voterHash, uint weight);
    event DelegateAssigned(bytes32 voterHash, address delegate);
    event VoteCast(bytes32 voterHash, uint candidateId, uint weight);
    event VotingStarted();
    event VotingEnded();

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier votingActive() {
        require(votingStarted && !votingEnded, "Voting is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Function to add candidates, only admin can add them
    function addCandidate(string memory _name) public onlyAdmin {
        candidatesCount++;
        candidates[candidatesCount] = Candidate(candidatesCount, _name, 0);
        emit CandidateAdded(candidatesCount, _name);
    }

    // Register a voter with a specific weight and store hash of their address for anonymity
    function registerVoter(address _voter, uint _weight) public onlyAdmin {
        bytes32 voterHash = keccak256(abi.encodePacked(_voter));
        require(voters[voterHash].weight == 0, "Voter is already registered");
        
        voters[voterHash] = Voter(false, _weight, 0, address(0));
        totalWeight += _weight;

        emit VoterRegistered(voterHash, _weight);
    }

    // Delegate voting power to another address
    function delegateVote(address _delegate) public votingActive {
        bytes32 voterHash = keccak256(abi.encodePacked(msg.sender));
        Voter storage sender = voters[voterHash];
        require(!sender.hasVoted, "You have already voted");

        bytes32 delegateHash = keccak256(abi.encodePacked(_delegate));
        Voter storage delegateTo = voters[delegateHash];
        require(delegateTo.weight > 0, "Delegate is not a registered voter");

        // Transfer voting power to delegate
        sender.hasVoted = true;
        sender.delegate = _delegate;
        delegateTo.weight += sender.weight;

        emit DelegateAssigned(voterHash, _delegate);
    }

    // Start the voting period
    function startVoting() public onlyAdmin {
        require(!votingStarted, "Voting has already started");
        votingStarted = true;
        emit VotingStarted();
    }

    // End the voting period
    function endVoting() public onlyAdmin {
        require(votingStarted && !votingEnded, "Voting has already ended");
        votingEnded = true;
        emit VotingEnded();
    }

    // Vote for a candidate, only registered and non-delegated voters can vote
    function vote(uint _candidateId) public votingActive {
        bytes32 voterHash = keccak256(abi.encodePacked(msg.sender));
        Voter storage sender = voters[voterHash];
        require(!sender.hasVoted, "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate");

        // Mark as voted and store the candidate ID
        sender.hasVoted = true;
        sender.votedCandidateId = _candidateId;

        // Apply the vote count with the voter's weight
        candidates[_candidateId].voteCount += sender.weight;

        emit VoteCast(voterHash, _candidateId, sender.weight);
    }

    // Calculate the winner based on the vote counts
    function getWinner() public view returns (string memory winnerName) {
        require(votingEnded, "Voting has not ended yet");

        uint winningVoteCount = 0;
        uint winnerId = 0;

        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winnerId = i;
            }
        }

        winnerName = candidates[winnerId].name;
    }
}