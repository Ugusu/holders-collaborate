// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Competitor} from "./Elements.sol";

contract HoldersCollaborate is Admin(msg.sender), Ownable(msg.sender) {
    constructor() {}

    bool competitionAlreadyCreated = false;
    
    Token[] public tokens;
    Level[] public levels;
    Competitor[] public competitors;
    
    mapping(address=>uint256) public competitor_indexes;

    uint256 public start = 0;
    uint256 public end = 0;
    uint256 public reward = 0;
    uint256 public total_usd = 0;
    
    Status public status = Status.Upcoming;

    // EVENTS
    event CompetitionCreated(
        Token[] tokens,
        uint256 start,
        uint256 end,
        Level[] levels,
        uint256 rewardPercentage
    );

    event CompetitionStatusChanged(
        Status oldStatus,
        Status newStatus
    );

    event Contributed(
        address competitor,
        address token,
        uint256 amount,
        uint256 usdAmount
    );

    // Contribute to the competition
    function contribute(
        address token,
        uint256 amount
    ) public returns(bool){
        require(token!=address(0), "Invalid token");
        require(tokenIsPresent(token), "No such token in competition");
        require(status==Status.Active, "Competition isn't active");
        require(matchesLevelExtremes(amount), "Amount doesn't match level minimum-maximum requirements");

        uint256 competitor_id = getCompetitorId(msg.sender);
        if(competitor_id == competitors.length){
            competitors.push(Competitor(
                msg.sender,
                0
            ));
            competitor_indexes[msg.sender] = competitor_id;
        }

        uint256 token_usd_amount = tokenToUsd(token, amount);
        competitors[competitor_id].value += token_usd_amount;

        for (uint256 i = 0; i < tokens.length; i++){
            if(tokens[i].token_address==token){
                tokens[i].value+=token_usd_amount;
            }
        }


        emit Contributed(
            msg.sender,
            token,
            amount,
            token_usd_amount
        );

        return true;
    }

    // Creates new competitions.
    function createCompetition(
        address[] memory tokens_addresses,
        uint256[] memory token_usd_prices,
        uint256 start_timestamp,
        uint256 end_timestamp,
        uint256 reward_percentage,
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) public returns(bool){
        require(!competitionAlreadyCreated, "Competition already created");
        require(block.timestamp<start, "Can't create competition in the past");
        require(block.timestamp<end, "Can't create finished competition");
        require(reward_percentage>=0 && reward_percentage<=10000, "Reward must be between 0.00 and 100.00 (0-10000)");
        
        createTokens(tokens_addresses, token_usd_prices);
        createLevels(level_treshholds, level_minimums, level_maximums);
        start = start_timestamp;
        end = end_timestamp;
        reward = reward_percentage;


        competitionAlreadyCreated = true;

        // Emit event with details
        emit CompetitionCreated(
            tokens,
            start,
            end,
            levels,
            reward_percentage
        );

        return true;
    }

    // Convert token amount to USD
    function tokenToUsd(
        address token,
        uint256 amount
    ) public view returns(uint256){
        bool found = false;
        uint256 usd_amount = 0;
        for (uint256 i = 0; i < tokens.length; i++){
            if(tokens[i].token_address==token){
                usd_amount = amount*tokens[i].token_usd_price;
                found = true;
            }
        }
        require(found, "Error while converting token to USD");

        return usd_amount;
    }

    // Check if token is in competition
    function tokenIsPresent(
        address token
    ) public view returns(bool){
        for (uint256 i = 0; i<tokens.length; i++){
            if(token == tokens[i].token_address){
                return true;
            }
        }
        return false;
    }

    // Check if amount is in level min and max boundaries
    function matchesLevelExtremes(
        uint256 amount
    ) public view returns(bool){
        for (uint256 i = 0; i < levels.length; i++){
            if(levels[i].active){
                if(
                    amount >= levels[i].minimum &&
                    amount <= levels[i].maximum
                ){
                    return true;
                }
            }
        }

        return false;
    }

    // Changes status of the competition
    function changeCompetitionStatus(
        uint256 newStatus
    ) public returns(bool){
        require(newStatus >= uint256(Status.Upcoming) && uint256(status) <= uint256(Status.Finished), "Invalid status value, must be between 0 and 3");
        Status oldStatus = status;

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

        status = Status(newStatus);

        emit CompetitionStatusChanged(
            oldStatus,
            status
        );

        return true;
    }

    // Getters
    function getCompetitorId(
        address competitor_address
    ) public view returns(uint256){
        uint256 competitor_id = 0;

        if(competitor_address!=competitors[0].competitor_address){
            if(competitor_indexes[competitor_address]>0){
                competitor_id = competitor_indexes[competitor_address];
            }else{
                competitor_id = competitors.length;
            }
        }

        return competitor_id;
    }

    function getCompetitorValue(
        address competitor_address
    ) public view returns(uint256) {
        uint256 competitor_id = getCompetitorId(competitor_address);
        if (competitor_id != competitors.length){
            return competitors[competitor_id].value;
        }
        return 0;
    }

    function getCompetitorByAddress(
        address competitor_address
    ) public view returns(Competitor memory) {
        uint256 competitor_id = getCompetitorId(competitor_address);
        if (competitor_id != competitors.length){
            return competitors[competitor_id];
        }
    }

    function getCompetitorById(
        uint256 competitor_id
    ) public view returns(Competitor memory) {
        return competitors[competitor_id];
    }

    function getCurrentStatus() public view returns(Status){
        return status;
    }

    function getStart() public view returns(uint256){
        return start;
    }

    function getEnd() public view returns(uint256){
        return end;
    }

    function getRewardPercentage() public view returns(uint256){
        return reward;
    }

    function getTotalValue() public view returns(uint256){
        return total_usd;
    }

    function getTokenValue(
        address token_address
    ) public view returns(uint256) {
        for (uint256 i = 0; i < tokens.length; i++){
            if (tokens[i].token_address == token_address){
                return tokens[i].value;
            }
        }
        return 0;
    }

    function getTokens() public view returns(Token[] memory){
        return tokens;
    }

    function getToken(
        address token_address
    ) public view returns(Token memory) {
        for (uint256 i = 0; i < tokens.length; i++){
            if (tokens[i].token_address == token_address){
                return tokens[i];
            }
        }
    }

    function getLevels() public view returns(Level[] memory){
        return levels;
    }

    function getActiveLevel() public view returns(Level memory){
        for (uint256 i = 0; i < levels.length; i++){
            if(levels[i].active){
                return levels[i];
            }
        }
    }

    function getLevel(
        uint256 level_order
    ) public view returns(Level memory) {
        return levels[level_order];
    }

    function getLevelMinimum(
        uint256 level_order
    ) public view returns(uint256) {
        return levels[level_order].minimum;
    }

    function getLevelMaximum(
        uint256 level_order
    ) public view returns(uint256) {
        return levels[level_order].maximum;
    }

    function getLevelTreshhold(
        uint256 level_order
    ) public view returns(uint256) {
        return levels[level_order].treshhold;
    }

    // Creates array of Tokens, with value 0 for each.
    function createTokens(
        address[] memory tokens_addresses,
        uint256[] memory token_usd_prices
    ) public returns(bool){
        require(!competitionAlreadyCreated, "Competition already created");
        require(tokens_addresses.length >= 2, "At least 2 tokens required");
        
        
        for (uint256 i = 0; i < tokens_addresses.length; i++){
            require(tokens_addresses[i]!=address(0), "Zero address can't be a token");
            require(token_usd_prices[i]!=0, "Token USD price can't be zero");
            tokens.push(Token(tokens_addresses[i], token_usd_prices[i], 0));
        }

        return true;
    }

    // Creates array of Levels, puts first level as active.
    function createLevels(
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) public returns(bool){
        require(!competitionAlreadyCreated, "Competition already created");
        require(level_treshholds.length >= 1, "At least one level is required");
        require(
            level_minimums.length == level_treshholds.length &&
            level_maximums.length == level_treshholds.length,
            "Number of level parameters must match"
        );
        
        for (uint256 i = 0; i < level_treshholds.length; i++){
            if (i > 0){
                require(level_treshholds[i]>level_treshholds[i-1], "Next level must have higher treshhold than previous");
            }
            require(level_minimums[i]<=level_maximums[i], "Level minimum must be lower or equal to level maximum");

            levels.push(Level(
                i,
                level_treshholds[i],
                level_minimums[i],
                level_maximums[i],
                false
            ));
        }
        levels[0].active=true;

        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
