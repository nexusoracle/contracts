// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAIOracle.sol";

contract FlightInsurance {
    IAIOracle public oracle;

    struct Policy {
        address customer;
        string flightNumber;
        uint256 premium;
        uint256 payout;
        bytes32 questionId;
        bool claimed;
    }

    mapping(uint256 => Policy) public policies;
    uint256 public policyCount;

    event PolicyPurchased(uint256 indexed policyId, address indexed customer, string flightNumber);
    event ClaimProcessed(uint256 indexed policyId, address indexed customer, uint256 payout);

    constructor() {
        oracle = IAIOracle(0xB8020265F487C7A4589e28bBA42bfB6357c994B4);
    }

    function buyInsurance(string memory flightNumber) external payable returns (uint256 policyId) {
        require(msg.value >= 0.02 ether, "Minimum premium: 0.02 BNB (0.01 for oracle + 0.01 minimum insurance)");

        policyId = policyCount++;

        policies[policyId] = Policy({
            customer: msg.sender,
            flightNumber: flightNumber,
            premium: msg.value - 0.01 ether,
            payout: (msg.value - 0.01 ether) * 3,
            questionId: bytes32(0),
            claimed: false
        });

        emit PolicyPurchased(policyId, msg.sender, flightNumber);
    }

    function fileClaim(uint256 policyId) external {
        Policy storage policy = policies[policyId];
        require(msg.sender == policy.customer, "Not your policy");
        require(!policy.claimed, "Already claimed");
        require(policy.questionId == bytes32(0), "Claim already filed");

        string memory question = string.concat(
            "Was flight ",
            policy.flightNumber,
            " delayed by more than 2 hours or cancelled?"
        );

        policy.questionId = oracle.askOracle{value: 0.01 ether}(question);
    }

    function processClaim(uint256 policyId) external {
        Policy storage policy = policies[policyId];
        require(!policy.claimed, "Already claimed");
        require(policy.questionId != bytes32(0), "No claim filed");
        require(oracle.hasAnswer(policy.questionId), "Oracle hasn't answered yet");

        (string memory answer, uint8 confidence, , ) = oracle.getAnswer(policy.questionId);

        if (keccak256(bytes(answer)) == keccak256(bytes("YES")) && confidence >= 70) {
            policy.claimed = true;
            payable(policy.customer).transfer(policy.payout);
            emit ClaimProcessed(policyId, policy.customer, policy.payout);
        } else {
            policy.claimed = true;
            emit ClaimProcessed(policyId, policy.customer, 0);
        }
    }

    function canProcessClaim(uint256 policyId) external view returns (bool) {
        Policy storage policy = policies[policyId];
        return !policy.claimed &&
               policy.questionId != bytes32(0) &&
               oracle.hasAnswer(policy.questionId);
    }

    receive() external payable {}
}
