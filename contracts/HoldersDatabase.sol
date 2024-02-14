// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Collaborator} from "./Elements.sol";

contract HoldersDatabase {
    // DATA
    Token[] public tokens;
    Level[] public levels;
    Collaborator[] public collaborators;

    mapping(address => uint256) public collaboratorsIndexes;

    uint256 public start = 0;
    uint256 public end = 0;

    Status internal status = Status.ACTIVE;

    // EVENTS

    event StatusChanged(Status oldStatus, Status newStatus);

    event LevelUpdated(Level oldLevels, Level newLevels);

    event TokenUpdated(Token oldTokens, Token newTokens);

    event RewardPercentageChanged(uint256 oldRewardPercentage, uint256 newRewardPercentage);

    event StartEndTimeUpdated(uint256 oldStart, uint256 oldEnd, uint256 newStart, uint256 newEnd);

    event LevelAdded(Level newLevel);

    event Contributed(address collaborator, address token, uint256 amount, uint256 usdAmount);
}
