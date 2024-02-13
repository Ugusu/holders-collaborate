// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Competitor} from "./Elements.sol";
import "./HoldersDatabase.sol";

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract HoldersHelpers is HoldersDatabase, Admin(msg.sender), Ownable(msg.sender) {
    // Convert token amount to USD
    function tokenToUsd(address token, uint256 amount) public view returns (uint256) {
        bool found = false;
        uint256 usdAmount = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == token) {
                usdAmount = amount * tokens[i].tokenUsdPrice;
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
        uint256 tokenValue = 0;
        uint256 amountUsd = tokenToUsd(tokenAddress, amount);
        uint256 currentLevel = 0;

        // find the value of the token
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                tokenValue = tokens[i].value;
            }
        }

        // Get current level's id
        for (uint256 i = 0; i < levels.length; i++) {
            if (currentLevel == 0 && tokenValue < levels[i].treshhold) {
                currentLevel = i + 1;
            }
        }

        // Means value higher than last level treshhold or equal
        if (currentLevel == 0) {
            return false;
        }

        currentLevel--;

        // Check if value is in extremes
        if (amountUsd < levels[currentLevel].minimum && amountUsd > levels[currentLevel].maximum) {
            return false;
        }

        // If not last level, or if total is within than treshhold, allowed
        if (currentLevel + 1 != levels.length || tokenValue + amountUsd <= levels[currentLevel].treshhold) {
            return true;
        }

        // If total more than last level treshhold, but less than treshhold + minimum, allowed
        if (tokenValue + amountUsd <= levels[currentLevel].treshhold + levels[currentLevel].minimum) {
            return true;
        }

        return false;
    }

    // Check if treshholds for later levels are higher than for earlier levels
    function checkLevelParamsConsistency(
        uint256[] memory levelsOrders,
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums,
        uint256[] memory levelsRewards
    ) public view returns (bool) {
        uint256 lastLevelOrderIndex = 0;

        for (uint256 i = 0; i < levelsOrders.length; i++) {
            require(levelsMinimums[i] > levelsMaximums[i], "Level minimums must be lower or equal to level maximums");
            require(
                levelsRewards[i] >= 0 && levelsRewards[i] <= 10000,
                "Reward must be between 0.00 and 100.00 (0-10000)"
            );
            if (levelsOrders[i] < levels.length - 1) {
                // If the order smaller than the order of the existing last level,
                // the treshhold and reward must be higher than all level values before that level.
                for (uint256 j = 0; j < levelsOrders[i]; j++) {
                    require(levels[j].treshhold < levelsTreshholds[i], "Higher levels must have higher treshholds");
                    require(levels[j].reward < levelsRewards[i], "Higher levels must have higher reward");
                }
            } else {
                // If the order is higher thatn last level's order,
                // it's values must be higher than all exiting level values.
                for (uint256 j = 0; j < levels.length; j++) {
                    require(levels[j].treshhold < levelsTreshholds[i], "Higher levels must have higher treshholds");
                    require(levels[j].reward < levelsRewards[i], "Higher levels must have higher reward");
                }
            }

            for (uint256 j = 0; j < levelsOrders.length; j++) {
                // In input values, higher levels must have higher values.
                if (levelsOrders[i] > levelsOrders[j]) {
                    require(levelsTreshholds[i] > levelsTreshholds[j], "Higher levels must have higher treshholds");
                    require(levelsRewards[i] > levelsRewards[j], "Higher levels must have higher reward");
                }
                // In input values, lower levels must have lower values.
                if (levelsOrders[i] < levelsOrders[j]) {
                    require(levelsTreshholds[i] < levelsTreshholds[j], "Higher levels must have higher treshholds");
                    require(levelsRewards[i] < levelsRewards[j], "Higher levels must have higher reward");
                }
            }

            // Detect level, which will be last after the update (or existing last level reward increase).
            if (levelsOrders[i] >= levels.length - 1 && levelsOrders[i] > levelsOrders[lastLevelOrderIndex]) {
                lastLevelOrderIndex = i;
            }
        }

        // Check the balance requirement for the new last level.
        if (levelsOrders[lastLevelOrderIndex] >= levels.length) {
            require(
                checkBalances(
                    levelsTreshholds[lastLevelOrderIndex],
                    levelsMinimums[lastLevelOrderIndex],
                    levelsRewards[lastLevelOrderIndex]
                ),
                "Higher balance required for the last level"
            );
        }

        return true;
    }

    // Check contract balance before collaboration start
    function checkBalances(
        uint256 levelTreshhold,
        uint256 levelMinimum,
        uint256 levelReward
    ) public view returns (bool) {
        uint256 requiredAmountUsd = ((levelTreshhold + levelMinimum) * levelReward) / 10000;

        // Ceil
        if (((levelTreshhold + levelMinimum) * levelReward) % 10000 != 0) {
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

    // Creates array of Tokens, with value 0 for each.
    function setTokens(
        address[] memory tokensAddresses,
        uint256[] memory tokenUsdPrices
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't set tokens after start time");
        require(tokensAddresses.length >= 2, "At least 2 tokens required");
        require(tokensAddresses.length == tokenUsdPrices.length, "Number of token and USD prices must be same");

        delete tokens;

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            require(tokensAddresses[i] != address(0), "Zero address can't be a token");
            require(tokenUsdPrices[i] != 0, "Token USD price can't be zero");
            tokens.push(Token(tokensAddresses[i], tokenUsdPrices[i], 0));
        }

        return true;
    }

    // Creates array of Levels, puts first level as active.
    function setLevels(
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums,
        uint256[] memory levelsRewards
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't set levels after start time");
        require(levelsTreshholds.length >= 1, "At least one level is required");
        require(
            levelsMinimums.length == levelsTreshholds.length &&
                levelsMaximums.length == levelsTreshholds.length &&
                levelsRewards.length == levelsTreshholds.length,
            "Number of level parameters must match"
        );

        delete levels;

        for (uint256 i = 0; i < levelsTreshholds.length; i++) {
            require(levelsMinimums[i] <= levelsMaximums[i], "Level minimum must be lower or equal to level maximum");
            require(
                levelsRewards[i] >= 0 && levelsRewards[i] <= 10000,
                "Reward must be between 0.00 and 100.00 (0-10000)"
            );
            if (i > 0) {
                require(
                    levelsTreshholds[i] > levelsTreshholds[i - 1],
                    "Next level must have higher treshhold than previous"
                );
                require(levelsRewards[i] > levelsRewards[i - 1], "Next level reward must be higher than previous");
            }

            levels.push(Level(levelsTreshholds[i], levelsMinimums[i], levelsMaximums[i], levelsRewards[i]));
        }

        return true;
    }
}
