// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAIOracle.sol";

contract PriceConsumer {
    IAIOracle public oracle;

    struct PriceQuery {
        string asset;
        bytes32 questionId;
        uint256 queriedAt;
    }

    mapping(uint256 => PriceQuery) public queries;
    uint256 public queryCount;

    event PriceRequested(uint256 indexed queryId, string asset, bytes32 questionId);
    event PriceReceived(uint256 indexed queryId, string asset, string answer);

    constructor() {
        oracle = IAIOracle(0xB8020265F487C7A4589e28bBA42bfB6357c994B4);
    }

    function requestPrice(string memory asset) external payable returns (uint256 queryId) {
        require(msg.value >= 0.01 ether, "Need 0.01 BNB for oracle fee");

        queryId = queryCount++;

        string memory question = string.concat("What is the current ", asset, " price in USD?");
        bytes32 questionId = oracle.askOracle{value: 0.01 ether}(question);

        queries[queryId] = PriceQuery({
            asset: asset,
            questionId: questionId,
            queriedAt: block.timestamp
        });

        emit PriceRequested(queryId, asset, questionId);

        if (msg.value > 0.01 ether) {
            payable(msg.sender).transfer(msg.value - 0.01 ether);
        }
    }

    function getPrice(uint256 queryId)
        external
        view
        returns (string memory answer, uint8 confidence, string memory reasoning)
    {
        PriceQuery storage query = queries[queryId];
        require(query.questionId != bytes32(0), "Query doesn't exist");
        require(oracle.hasAnswer(query.questionId), "Answer not ready yet");

        (answer, confidence, reasoning, ) = oracle.getAnswer(query.questionId);
    }

    function isPriceAvailable(uint256 queryId) external view returns (bool) {
        PriceQuery storage query = queries[queryId];
        return query.questionId != bytes32(0) && oracle.hasAnswer(query.questionId);
    }

    function getMyQueries() external view returns (bytes32[] memory) {
        return oracle.getUserQuestions(address(this));
    }
}
