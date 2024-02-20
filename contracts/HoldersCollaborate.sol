// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Level, Token, Status, Collaborator, LevelTemplate, TokenTemplate} from "./Elements.sol";
import "./HoldersFactory.sol";
import "./HoldersService.sol";

contract HoldersCollaborate is HoldersFactory, HoldersService {
    constructor(
        TokenTemplate[] memory _tokens,
        LevelTemplate[] memory _levels,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) {
        require(block.timestamp < _startTimestamp, "HoldersCollaborate: start in past");
        require(_startTimestamp < _endTimestamp, "HoldersCollaborate: Must be start < end");
        start = _startTimestamp;
        end = _endTimestamp;
        setTokens(_tokens);
        setLevels(_levels);
    }

    // Contribute to the collaboration
    function contribute(address _token, uint256 _amount) public returns (bool) {
        require(_token != address(0), "HoldersCollaborate: Invalid token");
        require(tokenIsPresent(_token), "HoldersCollaborate: Invalid token");
        require(getStatus() == Status.ACTIVE, "HoldersCollaborate: Not active");
        require(matchesLevelExtremes(_token, _amount), "HoldersCollaborate: Wrong amount");

        uint256 collaboratorId = getCollaboratorId(_token, msg.sender);
        if (collaboratorId == collaborators[_token].length) {
            require(!inAnotherToken(_token, msg.sender), "HoldersCollaborate: Not same token");
            collaborators[_token].push(Collaborator(msg.sender, 0));
        }

        uint256 tokenUsdAmount = tokenToUsd(_token, _amount);
        collaborators[_token][collaboratorId].amount += tokenUsdAmount;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token) {
                tokens[i].amount += tokenUsdAmount;
            }
        }

        emit Contribute(msg.sender, _token, _amount, tokenUsdAmount);

        return true;
    }

    // Changes status of the collaboration (between ACTIVE and PAUSED)
    // see getStatus() function.
    function updateStatus(Status _status) public onlyOwner returns (bool) {
        require(_status == Status.PAUSED || _status == Status.ACTIVE, "HoldersCollaborate: Only paused/active");
        require(getStatus() != Status.FINISHED, "HoldersCollaborate: Finished");

        Status oldStatus = status;
        status = _status;

        emit StatusUpdate(oldStatus, status);

        return true;
    }

    // Changes levels of the collaboration
    function updateLevel(Level memory _level) public onlyOwner onlyUpcoming returns (bool) {
        require(_level.id < levels.length, "HoldersCollaborate: No level");
        checkLevelParamsConsistency(_level);

        uint256 levelId = _level.id;
        Level memory oldLevel = levels[levelId];

        levels[levelId].name = _level.name;
        levels[levelId].minimum = _level.minimum;
        levels[levelId].maximum = _level.maximum;
        levels[levelId].threshold = _level.threshold;
        levels[levelId].reward = _level.reward;

        emit LevelUpdate(oldLevel, levels[levelId]);
        return true;
    }

    // Changes tokens of the collaboration
    function updateToken(TokenTemplate memory _token) public onlyOwner onlyUpcoming returns (bool) {
        require(_token.price != 0, "HoldersCollaborate: price 0");

        bool exists = tokenIsPresent(_token.adrs);
        require(exists, "HoldersCollaborate: No token");

        Token memory oldToken;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token.adrs) {
                oldToken = tokens[i];
                tokens[i].price = _token.price;
                break;
            }
        }

        emit TokenUpdate(oldToken, Token(oldToken.adrs, _token.price, oldToken.amount));

        return true;
    }

    // Changes start and end time
    function updateStartEndTime(
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) public onlyOwner onlyUpcoming returns (bool) {
        require(_startTimestamp < _endTimestamp, "HoldersCollaborate: Must be start < end");
        uint256 oldStart = start;
        uint256 oldEnd = end;

        start = _startTimestamp;
        end = _endTimestamp;

        emit StartEndTimeUpdate(oldStart, oldEnd, start, end);

        return true;
    }

    // Adds new level
    function addLevel(LevelTemplate memory _level) public onlyOwner returns (bool) {
        Level memory newLevel = Level(
            levels.length,
            _level.name,
            _level.threshold,
            _level.minimum,
            _level.maximum,
            _level.reward
        );
        checkLevelParamsConsistency(newLevel);

        levels.push(newLevel);

        emit LevelAdd(newLevel);

        return true;
    }

    function setAdmin(address _admin, bool _value) public override onlyOwner {
        admins[_admin] = _value;
        emit AdminSet(_admin, _value);
    }
}
