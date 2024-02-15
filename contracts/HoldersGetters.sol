// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Collaborator} from "./Elements.sol";
import "./HoldersDatabase.sol";

contract HoldersGetters is HoldersDatabase {
    // Getters
    function getCollaboratorId(address collaboratorAddress) public view returns (uint256) {
        uint256 collaboratorId = 0;

        // Check if the address is the first collaborator
        if (collaborators.length > 0 && collaboratorAddress != collaborators[0].collaboratorAddress) {
            if (collaboratorsIndexes[collaboratorAddress] > 0) {
                // If mapping address -> amount higher than 0 (default), existing collaborator
                collaboratorId = collaboratorsIndexes[collaboratorAddress];
            } else {
                // If it's 0, then it's default and it's a new collaborator (exception: fisrt collaborator - alredy checked)
                collaboratorId = collaborators.length;
            }
        }

        return collaboratorId;
    }

    function getCollaboratorAmount(address collaboratorAddress) public view returns (uint256) {
        uint256 collaboratorId = getCollaboratorId(collaboratorAddress);
        if (collaboratorId != collaborators.length) {
            return collaborators[collaboratorId].amount;
        }
        return 0;
    }

    function getCollaboratorByAddress(address collaboratorAddress) public view returns (Collaborator memory) {
        uint256 collaboratorId = getCollaboratorId(collaboratorAddress);
        if (collaboratorId != collaborators.length) {
            return collaborators[collaboratorId];
        }
    }

    function getTokenAmount(address tokenAddress) public view returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                return tokens[i].amount;
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

    function getNumberOfTokesn() public view returns (uint256) {
        return tokens.length;
    }

    function getActiveLevel() public view returns (Level memory) {
        uint256 minTokenAmount = tokens[0].amount;
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i].amount < minTokenAmount) {
                minTokenAmount = tokens[i].amount;
            }
        }
        for (uint256 i = 0; i < levels.length; i++) {
            if (minTokenAmount <= levels[i].treshhold) {
                return levels[i];
            }
        }
        return levels[levels.length - 1];
    }

    function getLevelByOrder(uint256 levelOrder) public view returns (Level memory) {
        for (uint256 i = 0; i < levels.length; i++) {
            if (levels[i].levelOrder == levelOrder) {
                return levels[i];
            }
        }
    }

    function getLevelIdByOrder(uint256 levelOrder) public view returns (int256) {
        for (uint256 i = 0; i < levels.length; i++) {
            if (levels[i].levelOrder == levelOrder) {
                return int256(i);
            }
        }
        return -1;
    }

    function getLevelMinimum(uint256 levelOrder) public view returns (uint256) {
        Level memory getLevel = getLevelByOrder(levelOrder);
        return getLevel.minimum;
    }

    function getLevelMaximum(uint256 levelOrder) public view returns (uint256) {
        Level memory getLevel = getLevelByOrder(levelOrder);
        return getLevel.maximum;
    }

    function getLevelTreshhold(uint256 levelOrder) public view returns (uint256) {
        Level memory getLevel = getLevelByOrder(levelOrder);
        return getLevel.treshhold;
    }

    function getNumberOfLevels() public view returns (uint256) {
        return levels.length;
    }

    function getTotalAmount() public view returns (uint256) {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            totalAmount += tokens[i].amount;
        }

        return totalAmount;
    }
}
