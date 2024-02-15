// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Collaborator} from "./Elements.sol";
import "./HoldersDatabase.sol";
import "./HoldersGetters.sol";
import "./HoldersHelpers.sol";

contract HoldersCollaborate is HoldersDatabase, HoldersGetters, HoldersHelpers {
    constructor(Token[] memory newTokens, Level[] memory newLevels, uint256 startTimestamp, uint256 endTimestamp) {
        require(block.timestamp < startTimestamp, "HoldersCollaborate: start in past");
        require(startTimestamp < endTimestamp, "HoldersCollaborate: Must be start < end");
        start = startTimestamp;
        end = endTimestamp;
        setTokens(newTokens);
        setLevels(newLevels);
    }

    // Contribute to the collaboration
    function contribute(address token, uint256 amount) public returns (bool) {
        require(token != address(0), "HoldersCollaborate: Invalid token");
        require(tokenIsPresent(token), "HoldersCollaborate: Invalid token");
        require(getStatus() == Status.ACTIVE, "HoldersCollaborate: Not active");
        require(matchesLevelExtremes(token, amount), "HoldersCollaborate: wrong amount");

        uint256 collaboratorId = getCollaboratorId(msg.sender);
        if (collaboratorId == collaborators.length) {
            collaborators.push(Collaborator(msg.sender, 0));
            collaboratorsIndexes[msg.sender] = collaboratorId;
        }

        uint256 tokenUsdAmount = tokenToUsd(token, amount);
        collaborators[collaboratorId].amount += tokenUsdAmount;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == token) {
                tokens[i].amount += tokenUsdAmount;
            }
        }

        emit Contributed(msg.sender, token, amount, tokenUsdAmount);

        return true;
    }

    // Changes status of the collaboration (between ACTIVE and PAUSED)
    // see getStatus() function.
    function changeStatus(Status newStatus) public onlyOwner returns (bool) {
        require(newStatus == Status.PAUSED || newStatus == Status.ACTIVE, "HoldersCollaborate: Only paursed/active");
        require(getStatus() != Status.FINISHED, "HoldersCollaborate: Finished");

        Status oldStatus = status;
        status = newStatus;

        emit StatusChanged(oldStatus, status);

        return true;
    }

    // Changes levels of the collaboration
    function updateLevel(Level memory updatedLevel) public onlyOwner onlyUpcoming returns (bool) {
        int256 getLevelId = getLevelIdByOrder(updatedLevel.levelOrder);
        require(getLevelId >= 0, "HoldersCollaborate: No level");
        updatedLevel.treshhold = updatedLevel.treshhold * 1 ether;
        updatedLevel.minimum = updatedLevel.minimum * 1 ether;
        updatedLevel.maximum = updatedLevel.maximum * 1 ether;

        checkLevelParamsConsistency(updatedLevel);

        uint256 levelId = uint256(getLevelId);
        Level memory oldLevel = levels[levelId];

        levels[levelId].levelName = updatedLevel.levelName;
        levels[levelId].minimum = updatedLevel.minimum;
        levels[levelId].maximum = updatedLevel.maximum;
        levels[levelId].treshhold = updatedLevel.treshhold;
        levels[levelId].reward = updatedLevel.reward;

        emit LevelUpdated(oldLevel, updatedLevel);
        return true;
    }

    // Changes tokens of the collaboration
    function updateToken(Token memory updatedToken) public onlyOwner onlyUpcoming returns (bool) {
        require(updatedToken.tokenUsdPrice != 0, "HoldersCollaborate: tokenUsdPrice 0");

        bool existingToken = tokenIsPresent(updatedToken.tokenAddress);
        require(existingToken, "HoldersCollaborate: No token");

        Token memory oldToken;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == updatedToken.tokenAddress) {
                oldToken = tokens[i];
                tokens[i].tokenUsdPrice = updatedToken.tokenUsdPrice;
                break;
            }
        }

        emit TokenUpdated(oldToken, updatedToken);

        return true;
    }

    // Changes start and end time
    function updateStartEndTime(
        uint256 startTimestamp,
        uint256 endTimestamp
    ) public onlyOwner onlyUpcoming returns (bool) {
        require(startTimestamp < endTimestamp, "HoldersCollaborate: Must be start < end");
        uint256 oldStart = start;
        uint256 oldEnd = end;

        start = startTimestamp;
        end = endTimestamp;

        emit StartEndTimeUpdated(oldStart, oldEnd, start, end);

        return true;
    }

    // Adds new level
    function addLevel(Level memory newLevel) public onlyOwner returns (bool) {
        newLevel.treshhold = newLevel.treshhold * 1 ether;
        newLevel.maximum = newLevel.maximum * 1 ether;
        newLevel.minimum = newLevel.minimum * 1 ether;
        checkLevelParamsConsistency(newLevel);

        levels.push(newLevel);

        emit LevelAdded(newLevel);

        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
