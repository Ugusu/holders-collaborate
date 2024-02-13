// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Competitor} from "./Elements.sol";
import "./HoldersDatabase.sol";

contract HoldersGetters is HoldersDatabase {
    // Getters
    function getCompetitorId(address competitorAddress) public view returns (uint256) {
        uint256 competitorId = 0;

        // Check if the address is the first competitor
        if (competitors.length>0 && competitorAddress != competitors[0].competitorAddress) {
            if (competitorIndexes[competitorAddress] > 0) {
                // If mapping address -> value higher than 0 (default), existing competitior
                competitorId = competitorIndexes[competitorAddress];
            } else {
                // If it's 0, then it's default and it's a new competitor (exception: fisrt competitor - alredy checked)
                competitorId = competitors.length;
            }
        }

        return competitorId;
    }

    function getCompetitorValue(address competitorAddress) public view returns (uint256) {
        uint256 competitorId = getCompetitorId(competitorAddress);
        if (competitorId != competitors.length) {
            return competitors[competitorId].value;
        }
        return 0;
    }

    function getCompetitorByAddress(address competitorAddress) public view returns (Competitor memory) {
        uint256 competitorId = getCompetitorId(competitorAddress);
        if (competitorId != competitors.length) {
            return competitors[competitorId];
        }
    }

    function getTokenValue(address tokenAddress) public view returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                return tokens[i].value;
            }
        }
        return 0;
    }

    function getToken(address tokenAddress) public view returns (Token memory) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                return tokens[i];
            }
        }
    }

    function getActiveLevel(address tokenAddress) public view returns (Level memory) {
        uint256 tokenValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                tokenValue = tokens[i].value;
            }
        }
        for (uint256 i = 0; i < levels.length; i++) {
            if (tokenValue <= levels[i].treshhold) {
                return levels[i];
            }
        }
        return levels[levels.length - 1];
    }

    function getLevelMinimum(uint256 levelOrder) public view returns (uint256) {
        return levels[levelOrder].minimum;
    }

    function getLevelMaximum(uint256 levelOrder) public view returns (uint256) {
        return levels[levelOrder].maximum;
    }

    function getLevelTreshhold(uint256 levelOrder) public view returns (uint256) {
        return levels[levelOrder].treshhold;
    }

    function getTotalValue() public view returns (uint256) {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            totalValue += tokens[i].value;
        }

        return totalValue;
    }
}
