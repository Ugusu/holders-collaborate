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
            if (levelsOrders[i] < levels.length) {
                for (uint256 j = 0; j < levelsOrders[i]; j++) {
                    require(levels[j].treshhold < levelsTreshholds[i], "Higher levels must have higher treshholds");
                    require(levels[j].reward < levelsRewards[i], "Higher levels must have higher reward");
                }
            } else {
                for (uint256 j = 0; j < levels.length; j++) {
                    require(levels[j].treshhold < levelsTreshholds[i], "Higher levels must have higher treshholds");
                    require(levels[j].reward < levelsRewards[i], "Higher levels must have higher reward");
                }
            }

            for (uint256 j = 0; j < levelsOrders.length; j++) {
                if (levelsOrders[i] > levelsOrders[j]) {
                    require(levelsTreshholds[i] > levelsTreshholds[j], "Higher levels must have higher treshholds");
                    require(levelsRewards[i] > levelsRewards[j], "Higher levels must have higher reward");
                }

                if (levelsOrders[i] < levelsOrders[j]) {
                    require(levelsTreshholds[i] < levelsTreshholds[j], "Higher levels must have higher treshholds");
                    require(levelsRewards[i] < levelsRewards[j], "Higher levels must have higher reward");
                }
            }

            if (levelsOrders[i] >= levels.length - 1 && levelsOrders[i] > levelsOrders[lastLevelOrderIndex]) {
                lastLevelOrderIndex = i;
            }
        }

        if (levelsOrders[lastLevelOrderIndex] >= levels.length) {
            require(
                checkBalancesForNewLevel(
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
    function checkBalances() public view returns (bool) {
        Level memory lastLevel = levels[levels.length - 1];
        uint256 requiredAmountUsd = (lastLevel.treshhold + lastLevel.minimum) * lastLevel.reward;

        return _checkBalance(requiredAmountUsd);
    }

    function checkBalancesForNewLevel(
        uint256 levelTreshhold,
        uint256 levelMinimum,
        uint256 levelReward
    ) public view returns (bool) {
        uint256 requiredAmountUsd = (levelTreshhold + levelMinimum) * levelReward;

        return _checkBalance(requiredAmountUsd);
    }

    function _checkBalance(uint256 requiredAmountUsd) internal view returns (bool) {
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