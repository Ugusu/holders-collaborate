// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Elements} from "./Elements.sol";

contract HoldersCollaborate is Admin(msg.sender), Ownable(msg.sender) {
    constructor() {}
    type Level is Elements.Level;
    type Token is Elements.Token;
    type Status is Elements.Status;
    type Competitor is Elements.Competitor;
    type Competition is Elements.Competition;

    // Competition ID => Competition
    uint256 public last_competitions_id;
    mapping(uint256 => Competition) public competitions;

    // EVENTS
    event competitionCreated(
        uint256 competitions_id,
        address creator,
        address owner,
        Token[] tokens,
        uint256 start,
        uint256 end,
        Level[] levels,
        uint256 reward_percentage
    );

    event competitionStatusChanged(
        uint256 competitions_id,
        Status oldStatus,
        Status newStatus
    );

    event competitionOwnerChanged(
        uint256 competitions_id,
        address oldOwner,
        address newOwner
    );

    // Creates new competitions.
    function createCompetition(
        address[] memory tokens,
        uint256 start,
        uint256 end,
        uint256 reward_percentage,
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) external returns(bool){
        require(block.timestamp<start, "Can't create competition in the past");
        require(block.timestamp<end, "Can't create finished competition");
        require(reward_percentage>=0 && reward_percentage<=10000, "Reward must be between 0.00 and 100.00 (0-10000)");
        
        Token[] memory newTokens = createTokens(tokens);
        Level[] memory newLevels = createLevels(level_treshholds, level_minimums, level_maximums);

        Competition memory newCompetition = Competition({
            creator: msg.sender,
            owner: msg.sender,
            tokens: newTokens,
            start: start,
            end: end,
            levels: newLevels,
            reward_percentage: reward_percentage,
            competitors: new Competitor[](0),
            competitor_indexes: new mapping(address => uint256),
            total_usd: 0,
            status: Status.Upcoming
        });

        last_competitions_id++;
        competitions[last_competitions_id] = newCompetition;

        // Emit event with details
        emit competitionCreated(
            last_competitions_id,
            msg.sender,
            newCompetition.owner,
            newCompetition.tokens,
            newCompetition.start,
            newCompetition.end,
            newCompetition.levels,
            newCompetition.reward_percentage
        );

        return true;
    }

    // Creates array of Tokens, with value 0 for each.
    function createTokens(
        address[] memory tokens
    ) external returns(Token[]){
        require(tokens.length >= 2, "At least 2 tokens required");
        
        Token[] memory newTokens = new Token[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++){
            require(tokens[i]!=address(0), "Zero address can't be a token");
            newTokens[i] = Token(tokens[i], 0);
        }

        return newTokens;
    }

    // Creates array of Levels, puts first level as active.
    function createLevels(
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) external returns(Level[]){
        require(level_treshholds.length >= 1, "At least one level is required");
        require(
            level_minimums.length == level_treshholds.length &&
            level_maximums.length == level_treshholds.length,
            "Number of level parameters must match"
        );

        Level[] memory newLevels = new Level[](level_treshholds.length);
        
        for (uint256 i = 0; i < level_treshholds.length; i++){
            if (i > 0){
                require(level_treshholds[i]>level_treshholds[i-1], "Next level must have higher treshhold than previous");
            }
            require(level_minimum[i]<=level_maximum[i], "Level minimum must be lower or equal to level maximum");

            newLevels[i] = Level(
                i,
                level_treshholds[i],
                level_minimums[i],
                level_maximums[i],
                false
            );
        }
        newLevels[0].active=true;

        return newLevels;
    }

    // Changes status of the competition
    function changeCompetitionStatus(
        uint256 competition_id,
        uint256 newStatus
    ) external returns(bool){
        require(newStatus >= uint256(Status.Upcoming) && status <= uint256(Status.Finished), "Invalid status value, must be between 0 and 3");
        Status oldStatus = competitions[competition_id].status;

        require(block.timestamp<end, "Competition has already finished");
        require(oldStatus!=Status.Finished, "Competition has already finished");

        if (newStatus==uint256(Status.Finished)){
            require(block.timestamp>=end, "Can't finish competition before the end time");
        }

        if(newStatus==uint256(Status.Active)){
            require(block.timestamp>=start, "Can't start competition before the start time");
        }

        if(newStatus==uint256(Status.Upcoming)){
            require(block.timestamp<start, "Can't declare upcoming after the start time");
        }

        competitions[competition_id].status = Status(newStatus);

        emit competitionStatusChanged(
            competition_id,
            oldStatus,
            competitions[competition_id].status
        );

        return true;
    }

    // Changes the owner of the competition
    function changeCompetitionOwner(
        uint256 competition_id,
        address newOwner
    ) external returns(bool){
        require(msg.sender==competitions[competition_id].owner, "Only owner can change owner");
        
        require(
            competitions[competition_id].status==Status.Upcoming ||
            competitions[competition_id].status==Status.Paused,
            "Can't change owner of active or finished competition"
        );

        require(newOwner!=address(0), "Can't asing zero address as owner");
        require(newOwner!=competitions[competition_id].owner, "Address is already owner");

        address oldOwner = competitions[competition_id].owner;
        competitions[competition_id].owner = newOwner;

        // New owner should start the competition
        competitions[competition_id].status = Status.Paused;

        emit competitionOwnerChanged(
            competition_id,
            oldOwner,
            newOwner
        );

        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
