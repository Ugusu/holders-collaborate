// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Competitor} from "./Elements.sol";

contract HoldersDatabase {
    // DATA
    Token[] public tokens;
    Level[] public levels;
    Competitor[] public competitors;

    mapping(address => uint256) public competitorIndexes;

    uint256 public start = 0;
    uint256 public end = 0;

    Status public status = Status.Upcoming;

    // EVENTS

    event StatusChanged(Status oldStatus, Status newStatus);

    event LevelsUpdated(Level[] oldLevels, Level[] newLevels);

    event TokensUpdated(Token[] oldTokens, Token[] newTokens);

    event RewardPercentageChanged(uint256 oldRewardPercentage, uint256 newRewardPercentage);

    event StartEndTimeChanged(uint256 oldStart, uint256 oldEnd, uint256 newStart, uint256 newEnd);

    event LevelAdded(Level newLevel);

    event Contributed(address competitor, address token, uint256 amount, uint256 usdAmount);
}
