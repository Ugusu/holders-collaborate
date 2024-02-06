// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Competitor} from "./Elements.sol";
import "./HoldersDatabase.sol";
import "./HoldersGetters.sol";
import "./HoldersHelpers.sol";

contract HoldersCollaborate is HoldersDatabase, HoldersGetters, HoldersHelpers {
    constructor(
        address[] memory tokensAddresses,
        uint256[] memory tokenUsdPrices,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums,
        uint256[] memory levelsRewards
    ) {
        require(block.timestamp < startTimestamp, "Can't create collaboration in the past");
        require(startTimestamp < endTimestamp, "End time should be after start time");
        start = startTimestamp;
        end = endTimestamp;
        setTokens(tokensAddresses, tokenUsdPrices);
        setLevels(levelsTreshholds, levelsMinimums, levelsMaximums, levelsRewards);
    }

    // Contribute to the collaboration
    function contribute(address token, uint256 amount) public returns (bool) {
        require(token != address(0), "Invalid token");
        require(tokenIsPresent(token), "No such token in collaboration");
        require(status == Status.Active, "collaboration isn't active");
        require(matchesLevelExtremes(token, amount), "Amount doesn't match level minimum-maximum requirements");

        uint256 competitorId = getCompetitorId(msg.sender);
        if (competitorId == competitors.length) {
            competitors.push(Competitor(msg.sender, 0));
            competitorIndexes[msg.sender] = competitorId;
        }

        uint256 tokenUsdAmount = tokenToUsd(token, amount);
        competitors[competitorId].value += tokenUsdAmount;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == token) {
                tokens[i].value += tokenUsdAmount;
            }
        }

        emit Contributed(msg.sender, token, amount, tokenUsdAmount);

        return true;
    }

    // Changes status of the collaboration
    function changeStatus(uint256 newStatus) public onlyOwner returns (bool) {
        require(
            newStatus >= uint256(Status.Upcoming) && uint256(status) <= uint256(Status.Finished),
            "Invalid status value, must be between 0 and 3"
        );
        Status oldStatus = status;

        require(block.timestamp < end, "collaboration has already finished");
        require(oldStatus != Status.Finished, "collaboration has already finished");

        if (newStatus == uint256(Status.Finished)) {
            require(block.timestamp >= end, "Can't finish collaboration before the end time");
        }

        if (newStatus == uint256(Status.Active)) {
            require(block.timestamp >= start, "Can't start collaboration before the start time");
            require(
                checkBalances(),
                "Minimum balance for all tokens must meet last level goal + last level minimum with reward"
            );
        }

        if (newStatus == uint256(Status.Upcoming)) {
            require(block.timestamp < start, "Can't declare upcoming after the start time");
        }

        status = Status(newStatus);

        emit StatusChanged(oldStatus, status);

        return true;
    }

    // Changes levels of the collaboration
    function updateLevels(
        uint256[] memory levelsOrders,
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums,
        uint256[] memory levelsRewards
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change existing levels after start time");
        require(
            levelsOrders.length == levelsTreshholds.length &&
                levelsOrders.length == levelsMinimums.length &&
                levelsOrders.length == levelsMaximums.length &&
                levelsOrders.length == levelsRewards.length,
            "Number of parameters must be the same"
        );

        require(
            checkLevelParamsConsistency(levelsOrders, levelsTreshholds, levelsMinimums, levelsMaximums, levelsRewards),
            "Levels Params aren't correct"
        );

        Level[] memory oldLevels = levels;

        for (uint256 i = 0; i < levelsOrders.length; i++) {
            if (levelsOrders[i] < oldLevels.length) {
                levels[levelsOrders[i]].treshhold = levelsTreshholds[i];
                levels[levelsOrders[i]].minimum = levelsMinimums[i];
                levels[levelsOrders[i]].maximum = levelsMaximums[i];
                levels[levelsOrders[i]].reward = levelsRewards[i];
            } else {
                levels.push(Level(levelsTreshholds[i], levelsMinimums[i], levelsMaximums[i], levelsRewards[i]));
            }
        }

        emit LevelsUpdated(oldLevels, levels);

        return true;
    }

    // Changes tokens of the collaboration
    function updateTokens(
        address[] memory tokensAddresses,
        uint256[] memory tokensUsdPrices
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change tokens after start time");
        require(tokensAddresses.length == tokensUsdPrices.length);

        Token[] memory oldTokens = tokens;

        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < tokensAddresses.length; j++) {
                if (tokens[i].tokenAddress == tokensAddresses[j]) {
                    tokens[i].tokenUsdPrice = tokensUsdPrices[j];
                }
            }
        }

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            if (!tokenIsPresent(tokensAddresses[i])) {
                tokens.push(Token(tokensAddresses[i], tokensUsdPrices[i], 0));
            }
        }

        emit TokensUpdated(oldTokens, tokens);

        return true;
    }

    // Changes start and end time
    function changeStartEndTime(uint256 startTimestamp, uint256 endTimestamp) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change start and end times after start time");
        require(startTimestamp < endTimestamp, "End time should be after start time");

        uint256 oldStart = start;
        uint256 oldEnd = end;

        start = startTimestamp;
        end = endTimestamp;

        emit StartEndTimeChanged(oldStart, oldEnd, start, end);

        return true;
    }

    // Adds new level
    function addLevel(
        uint256 levelTreshhold,
        uint256 levelMinimum,
        uint256 levelMaximum,
        uint256 levelReward
    ) public onlyOwner returns (bool) {
        require(
            levelTreshhold > levels[levels.length - 1].treshhold,
            "New level's treshhold must be higher than last existing level's treshhold"
        );
        require(levelMinimum <= levelMaximum, "Level minimum must be lower or equal to level maximum");
        require(
            checkBalancesForNewLevel(levelTreshhold, levelMinimum, levelMaximum),
            "Higher balance required for the last level"
        );

        levels.push(Level(levelTreshhold, levelMinimum, levelMaximum, levelReward));

        emit LevelAdded(levels[levels.length - 1]);

        return true;
    }

    function startCollaboration() public onlyOwner returns (bool) {
        changeStatus(uint256(Status.Active));
        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
