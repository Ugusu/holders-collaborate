// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Collaborator} from "./Elements.sol";

abstract contract HoldersFactory {
    // DATA
    Token[] public tokens;
    Level[] public levels;

    mapping(address => Collaborator[]) public collaborators;

    uint256 public start = 0;
    uint256 public end = 0;

    Status internal status = Status.ACTIVE;

    // EVENTS

    event StatusUpdate(Status oldStatus, Status newStatus);

    event LevelUpdate(Level oldLevel, Level newLevel);

    event TokenUpdate(Token oldToken, Token newToken);

    event StartEndTimeUpdate(uint256 oldStart, uint256 oldEnd, uint256 newStart, uint256 newEnd);

    event LevelAdd(Level newLevel);

    event Contribute(address collaborator, address token, uint256 amount, uint256 usdAmount);

    // Getters
    function getCollaboratorId(address _token, address _collaborator) public view returns (uint256) {
        for (uint256 i = 0; i < collaborators[_token].length; i++){
            if(collaborators[_token][i].adrs == _collaborator){
                return i;
            }
        }

        return collaborators[_token].length;
    }

    function getTokenByAddress(address _token) public view returns (Token memory) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token) {
                return tokens[i];
            }
        }
    }

    function getActiveLevel() public view returns (Level memory) {
        uint256 minTokenAmount = tokens[0].amount;
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i].amount < minTokenAmount) {
                minTokenAmount = tokens[i].amount;
            }
        }
        for (uint256 i = 0; i < levels.length; i++) {
            if (minTokenAmount <= levels[i].threshold) {
                return levels[i];
            }
        }
        return levels[levels.length - 1];
    }

    function getTotalAmount() public view returns (uint256) {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            totalAmount += tokens[i].amount;
        }

        return totalAmount;
    }
}
