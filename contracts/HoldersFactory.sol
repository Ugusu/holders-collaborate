// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Collaborator, LevelTemplate, TokenTemplate} from "./Elements.sol";

interface ERC20 {
    function balanceOf(address _account) external view returns (uint256);
    function allowance(address _holder, address _spender) external view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
    function approve(address _spender, uint256 _amount) external returns (bool);
}

abstract contract HoldersFactory is Admin(msg.sender), Ownable(msg.sender) {
    // DATA
    Token[] public tokens;
    Level[] public levels;

    mapping(address => Collaborator[]) public collaborators;

    uint256 public start = 0;
    uint256 public end = 0;

    Status internal status = Status.ACTIVE;

    uint256 perc100 = 100 * 1 ether;

    // EVENTS

    event StatusUpdate(Status oldStatus, Status newStatus);

    event LevelUpdate(Level oldLevel, Level newLevel);

    event TokenUpdate(Token oldToken, Token newToken);

    event StartEndTimeUpdate(uint256 oldStart, uint256 oldEnd, uint256 newStart, uint256 newEnd);

    event LevelAdd(Level newLevel);

    event Contribute(address collaborator, address token, uint256 amount, uint256 usdAmount);

    event Cancel(address canceller, Token[] tokens);

    // Getters
    function getCollaboratorId(address _token, address _collaborator) public view returns (uint256) {
        for (uint256 i = 0; i < collaborators[_token].length; i++) {
            if (collaborators[_token][i].adrs == _collaborator) {
                return i;
            }
        }

        return collaborators[_token].length;
    }

    function getTokenByAddress(address _token) public view returns (Token memory token) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token) {
                return tokens[i];
            }
        }
    }

    function getActiveLevel() public view returns (Level memory level) {
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

    function getNumberOfTokesn() public view returns (uint256) {
        return tokens.length;
    }
}
