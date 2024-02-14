// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Collaborator} from "./Elements.sol";
import "./HoldersDatabase.sol";
import "./HoldersGetters.sol";

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract HoldersHelpers is HoldersDatabase, HoldersGetters, Admin(msg.sender), Ownable(msg.sender) {
    modifier onlyUpcoming() {
        require(getStatus() == Status.UPCOMING, "status not UPCOMING");
        _;
    }
    // If after end, FINISHED. If internal status ACTIVE, before start UPCOMING
    // after start, if balance complete ACTIVE, else PENDING
    // If internal PAUSED (not ACTIVE) PAUSED.
    function getStatus() public view returns (Status) {
        if (block.timestamp >= end) {
            return Status.FINISHED;
        } else if (status == Status.ACTIVE) {
            if (block.timestamp < start) {
                return Status.UPCOMING;
            } else if (checkBalances(levels[levels.length - 1])) {
                return Status.ACTIVE;
            } else if (!checkBalances(levels[levels.length - 1])) {
                return Status.PENDING;
            }
        } else {
            return Status.PAUSED;
        }
    }
    // Convert token amount to USD
    function tokenToUsd(address token, uint256 amount) public view returns (uint256) {
        bool found = false;
        uint256 usdAmount = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == token) {
                usdAmount = (amount/1 ether) * tokens[i].tokenUsdPrice;
                found = true;
            }
        }
        require(found, "Error while converting token to USD");

        return usdAmount;
    }

    // Check if token is in collaboration
    function tokenIsPresent(address token) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (token == tokens[i].tokenAddress) {
                return true;
            }
        }
        return false;
    }

    // Check if amount is in level min and max boundaries
    function matchesLevelExtremes(address tokenAddress, uint256 amount) public view returns (bool) {
        uint256 tokenAmount = getTokenAmount(tokenAddress);
        uint256 amountUsd = tokenToUsd(tokenAddress, amount);
        uint256 lastLevelOrder = levels[levels.length-1].levelOrder;

        Level memory currentLevel = getActiveLevel();
        // Must be between min and max, must be not last level or if last level, within treshhold + minimum
        if (
            amountUsd >= currentLevel.minimum &&
            amountUsd <= currentLevel.maximum &&
            (currentLevel.levelOrder < lastLevelOrder ||
            tokenAmount + amountUsd <= currentLevel.treshhold + currentLevel.minimum)
        ) {
            return true;
        }

        return false;
    }

    // Check if treshholds for later levels are higher than for earlier levels
    function checkLevelParamsConsistency(Level memory level) public view returns (bool) {
        uint256 lastLevelId = levels.length - 1;
        int256 getLevelId = getLevelIdByOrder(level.levelOrder);
        uint256 levelId;

        if (getLevelId >= 0) {
            require(getStatus() == Status.UPCOMING, "status not UPCOMING");
            levelId = uint256(getLevelId);
        } else {
            lastLevelId = levels.length;
            levelId = lastLevelId;
        }

        require(level.minimum <= level.maximum, "Must be min <= max");
        if (levelId > 0) {
            require(level.levelOrder > levels[levelId - 1].levelOrder);
            require(level.treshhold > levels[levelId - 1].treshhold, "Treshhold must increase");
            require(level.reward > levels[levelId - 1].reward, "Reward must increase");
        }
        if (levelId < levels.length-1) {
            require(level.levelOrder < levels[levelId + 1].levelOrder);
            require(level.treshhold < levels[levelId + 1].treshhold, "Treshhold must increase");
            require(level.reward < levels[levelId + 1].reward, "Reward must increase");
        } else {
            require(checkBalances(level), "Insufficient balance");
        }

        return true;
    }

    // Check contract balance before collaboration start
    function checkBalances(Level memory level) public view returns (bool) {
        uint256 levelTreshhold = level.treshhold;
        uint256 levelMinimum = level.minimum;
        uint256 levelReward = level.reward;

        uint256 requiredAmountUsd = ((levelTreshhold + levelMinimum) * levelReward * (tokens.length - 1)) / 10000;

        // Ceil
        if (((levelTreshhold + levelMinimum) * levelReward * (tokens.length - 1)) % 10000 != 0) {
            requiredAmountUsd++;
        }

        // Iterate over tokens and check balance for each.
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20 tokenContract = ERC20(tokens[i].tokenAddress);

            uint256 contractsTokenBalanceUsd = tokenToUsd(
                tokens[i].tokenAddress,
                tokenContract.balanceOf(address(this))
            );

            if (contractsTokenBalanceUsd < requiredAmountUsd) {
                return false;
            }
        }

        return true;
    }

    // Creates array of Tokens, with amount 0 for each.
    function setTokens(Token[] memory newTokens) public onlyOwner onlyUpcoming returns (bool) {
        delete tokens;

        for (uint256 i = 0; i < newTokens.length; i++) {
            require(newTokens[i].tokenAddress != address(0), "tokenAddress 0");
            require(newTokens[i].tokenUsdPrice > 0, "tokenUsdPrice 0");
            newTokens[i].amount = 0;
            tokens.push(newTokens[i]);
        }

        return true;
    }

    // Creates array of Levels
    function setLevels(Level[] memory newLevels) public onlyOwner onlyUpcoming returns (bool) {
        delete levels;

        for (uint256 i = 0; i < newLevels.length; i++) {
            require(newLevels[i].minimum <= newLevels[i].maximum, "Must be min <= max");
            require(newLevels[i].reward >= 0 && newLevels[i].reward <= 10000, "Must be 0 <= reward <= 10000");
            if (i > 0) {
                require(newLevels[i].levelOrder > newLevels[i - 1].levelOrder, "Order must increase");
                require(newLevels[i].treshhold > newLevels[i - 1].treshhold, "Treshhold must increase");
                require(newLevels[i].reward > newLevels[i - 1].reward, "Reward must increase");
            }

            levels.push(newLevels[i]);
        }

        return true;
    }
}
