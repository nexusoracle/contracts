// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAIOracle.sol";

contract SimplePredictionMarket {
    IAIOracle public oracle;

    struct Market {
        string question;
        bytes32 questionId;
        uint256 totalYesBets;
        uint256 totalNoBets;
        mapping(address => uint256) yesBets;
        mapping(address => uint256) noBets;
        bool resolved;
        bool outcome; 
    }

    mapping(uint256 => Market) public markets;
    uint256 public marketCount;

    event MarketCreated(uint256 indexed marketId, string question, bytes32 questionId);
    event BetPlaced(uint256 indexed marketId, address indexed user, bool prediction, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome, uint256 totalPayout);

    constructor() {
        oracle = IAIOracle(0xB8020265F487C7A4589e28bBA42bfB6357c994B4);
    }

    function createMarket(string memory question) external payable returns (uint256 marketId) {
        require(msg.value >= 0.01 ether, "Need 0.01 BNB for oracle fee");

        marketId = marketCount++;
        Market storage market = markets[marketId];
        market.question = question;

        market.questionId = oracle.askOracle{value: 0.01 ether}(question);

        emit MarketCreated(marketId, question, market.questionId);

        if (msg.value > 0.01 ether) {
            payable(msg.sender).transfer(msg.value - 0.01 ether);
        }
    }

    function betYes(uint256 marketId) external payable {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market already resolved");
        require(msg.value > 0, "Must bet some BNB");

        market.yesBets[msg.sender] += msg.value;
        market.totalYesBets += msg.value;

        emit BetPlaced(marketId, msg.sender, true, msg.value);
    }

    function betNo(uint256 marketId) external payable {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market already resolved");
        require(msg.value > 0, "Must bet some BNB");

        market.noBets[msg.sender] += msg.value;
        market.totalNoBets += msg.value;

        emit BetPlaced(marketId, msg.sender, false, msg.value);
    }

    function resolveMarket(uint256 marketId) external {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(oracle.hasAnswer(market.questionId), "Oracle hasn't answered yet");

        (string memory answer, uint8 confidence, , ) = oracle.getAnswer(market.questionId);

        bool outcome = keccak256(bytes(answer)) == keccak256(bytes("YES"));

        market.resolved = true;
        market.outcome = outcome;

        emit MarketResolved(marketId, outcome, outcome ? market.totalYesBets : market.totalNoBets);
    }

    function claimWinnings(uint256 marketId) external {
        Market storage market = markets[marketId];
        require(market.resolved, "Market not resolved yet");

        uint256 winnings;
        uint256 totalPool = market.totalYesBets + market.totalNoBets;

        if (market.outcome) {
            uint256 userBet = market.yesBets[msg.sender];
            require(userBet > 0, "No winning bet");

            winnings = (userBet * totalPool) / market.totalYesBets;
            market.yesBets[msg.sender] = 0;
        } else {
            uint256 userBet = market.noBets[msg.sender];
            require(userBet > 0, "No winning bet");

            winnings = (userBet * totalPool) / market.totalNoBets;
            market.noBets[msg.sender] = 0;
        }

        payable(msg.sender).transfer(winnings);
    }

    function isResolvable(uint256 marketId) external view returns (bool) {
        return oracle.hasAnswer(markets[marketId].questionId);
    }
}
