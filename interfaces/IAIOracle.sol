// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAIOracle {
    function askOracle(string memory question) external payable returns (bytes32 questionId);

    function getAnswer(bytes32 questionId)
        external
        view
        returns (string memory answer, uint8 confidence, string memory reasoning, uint256 timestamp);

    function hasAnswer(bytes32 questionId) external view returns (bool);

    function getUserQuestions(address user) external view returns (bytes32[] memory);

    function getStats() external view returns (uint256 totalQuestions, uint256 totalFees, uint256 balance);

    event QuestionAsked(
        bytes32 indexed questionId,
        address indexed asker,
        string question,
        uint256 fee,
        uint256 timestamp
    );

    event AnswerProvided(
        bytes32 indexed questionId,
        string answer,
        uint8 confidence,
        uint256 timestamp
    );
}
