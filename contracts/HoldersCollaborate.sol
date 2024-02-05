// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Competitor} from "./Elements.sol";

contract HoldersCollaborate is Admin(msg.sender), Ownable(msg.sender) {
    constructor(
        address[] memory tokens_addresses,
        uint256[] memory token_usd_prices,
        uint256 start_timestamp,
        uint256 end_timestamp,
        uint256 reward_percentage,
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) {
        require(block.timestamp < start_timestamp, "Can't create competition in the past");
        require(start_timestamp < end_timestamp, "End time should be after start time");
        // TODO: in theory, the reward_percentage can be any percentage. But this is also a good approach
        require(
            reward_percentage >= 0 && reward_percentage <= 10000,
            "Reward must be between 0.00 and 100.00 (0-10000)"
        );
        //
        createTokens(tokens_addresses, token_usd_prices);
        createLevels(level_treshholds, level_minimums, level_maximums);
        start = start_timestamp;
        end = end_timestamp;
        reward = reward_percentage;

        competitionAlreadyCreated = true;
    }

    bool competitionAlreadyCreated = false;

    Token[] public tokens;
    Level[] public levels;
    Competitor[] public competitors;

    mapping(address => uint256) public competitor_indexes;

    uint256 public start = 0;
    uint256 public end = 0;
    uint256 public reward = 0;
    uint256 public totalUsd = 0;

    Status public status = Status.Upcoming;

    // EVENTS
    event CompetitionCreated(Token[] tokens, uint256 start, uint256 end, Level[] levels, uint256 rewardPercentage);

    event CompetitionStatusChanged(Status oldStatus, Status newStatus);

    event Contributed(address competitor, address token, uint256 amount, uint256 usdAmount);

    // Contribute to the competition
    function contribute(address token, uint256 amount) public returns (bool) {
        require(token != address(0), "Invalid token");
        require(tokenIsPresent(token), "No such token in competition");
        require(status == Status.Active, "Competition isn't active");
        require(matchesLevelExtremes(token, amount), "Amount doesn't match level minimum-maximum requirements");

        uint256 competitor_id = getCompetitorId(msg.sender);
        if (competitor_id == competitors.length) {
            competitors.push(Competitor(msg.sender, 0));
            competitor_indexes[msg.sender] = competitor_id;
        }

        uint256 token_usd_amount = tokenToUsd(token, amount);
        competitors[competitor_id].value += token_usd_amount;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token) {
                tokens[i].value += token_usd_amount;
            }
        }

        emit Contributed(msg.sender, token, amount, token_usd_amount);

        return true;
    }

    // Convert token amount to USD
    function tokenToUsd(address token, uint256 amount) public view returns (uint256) {
        bool found = false;
        uint256 usd_amount = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token) {
                usd_amount = amount * tokens[i].token_usd_price;
                found = true;
            }
        }
        require(found, "Error while converting token to USD");

        return usd_amount;
    }

    // Check if token is in competition
    function tokenIsPresent(address token) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (token == tokens[i].token_address) {
                return true;
            }
        }
        return false;
    }

    // Check if amount is in level min and max boundaries
    function matchesLevelExtremes(address token_address, uint256 amount) public view returns (bool) {
        // TODO: flatten the loop
        uint256 token_value = 0;
        // find the value of the token if it exists
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token_address) {
                token_value = tokens[i].value;
            }
        }

        // if the token doesn't exist, return false
        if (token_value == 0) {
            return false;
        }

        // check if the amount is in the level boundaries
        for (uint256 j = 0; j < tokens.length; j++) {
            if (token_value >= levels[j].treshhold) {
                if (amount >= levels[j].minimum && amount <= levels[j].maximum) {
                    return true;
                }
            }
        }

        return false;
    }

    // Changes status of the competition
    function changeCompetitionStatus(uint256 newStatus) public onlyOwner returns (bool) {
        require(
            newStatus >= uint256(Status.Upcoming) && uint256(status) <= uint256(Status.Finished),
            "Invalid status value, must be between 0 and 3"
        );
        Status oldStatus = status;

        require(block.timestamp < end, "Competition has already finished");
        require(oldStatus != Status.Finished, "Competition has already finished");

        if (newStatus == uint256(Status.Finished)) {
            require(block.timestamp >= end, "Can't finish competition before the end time");
        }

        if (newStatus == uint256(Status.Active)) {
            require(block.timestamp >= start, "Can't start competition before the start time");
        }

        if (newStatus == uint256(Status.Upcoming)) {
            require(block.timestamp < start, "Can't declare upcoming after the start time");
        }

        status = Status(newStatus);

        emit CompetitionStatusChanged(oldStatus, status);

        return true;
    }

    // Getters
    function getCompetitorId(address competitor_address) public view returns (uint256) {
        uint256 competitor_id = 0;

        if (competitor_address != competitors[0].competitor_address) {
            if (competitor_indexes[competitor_address] > 0) {
                competitor_id = competitor_indexes[competitor_address];
            } else {
                competitor_id = competitors.length;
            }
        }

        return competitor_id;
    }

    function getCompetitorValue(address competitor_address) public view returns (uint256) {
        uint256 competitor_id = getCompetitorId(competitor_address);
        if (competitor_id != competitors.length) {
            return competitors[competitor_id].value;
        }
        return 0;
    }

    function getCompetitorByAddress(address competitor_address) public view returns (Competitor memory) {
        uint256 competitor_id = getCompetitorId(competitor_address);
        if (competitor_id != competitors.length) {
            return competitors[competitor_id];
        }
    }

    function getCompetitorById(uint256 competitor_id) public view returns (Competitor memory) {
        return competitors[competitor_id];
    }

    function getTokenValue(address token_address) public view returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token_address) {
                return tokens[i].value;
            }
        }
        return 0;
    }

    function getTokens() public view returns (Token[] memory) {
        return tokens;
    }

    function getToken(address token_address) public view returns (Token memory) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token_address) {
                return tokens[i];
            }
        }
    }

    function getLevels() public view returns (Level[] memory) {
        return levels;
    }

    function getActiveLevel(address token_address) public view returns (Level memory) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token_address == token_address) {
                for (uint256 j = 0; j < tokens.length; j++) {
                    if (tokens[i].value >= levels[j].treshhold) {
                        return levels[j];
                    }
                }
            }
        }
    }

    function getLevel(uint256 level_order) public view returns (Level memory) {
        return levels[level_order];
    }

    function getLevelMinimum(uint256 level_order) public view returns (uint256) {
        return levels[level_order].minimum;
    }

    function getLevelMaximum(uint256 level_order) public view returns (uint256) {
        return levels[level_order].maximum;
    }

    function getLevelTreshhold(uint256 level_order) public view returns (uint256) {
        return levels[level_order].treshhold;
    }

    // One time functions

    // Creates array of Tokens, with value 0 for each.
    function createTokens(
        address[] memory tokens_addresses,
        uint256[] memory token_usd_prices
    ) public onlyOwner returns (bool) {
        require(!competitionAlreadyCreated, "Competition already created");
        require(tokens_addresses.length >= 2, "At least 2 tokens required");
        //TODO: check if the length of the arrays is the same

        for (uint256 i = 0; i < tokens_addresses.length; i++) {
            require(tokens_addresses[i] != address(0), "Zero address can't be a token");
            require(token_usd_prices[i] != 0, "Token USD price can't be zero");
            tokens.push(Token(tokens_addresses[i], token_usd_prices[i], 0));
        }

        return true;
    }

    // Creates array of Levels, puts first level as active.
    function createLevels(
        uint256[] memory level_treshholds,
        uint256[] memory level_minimums,
        uint256[] memory level_maximums
    ) public onlyOwner returns (bool) {
        require(!competitionAlreadyCreated, "Competition already created");
        require(level_treshholds.length >= 1, "At least one level is required");
        require(
            level_minimums.length == level_treshholds.length && level_maximums.length == level_treshholds.length,
            "Number of level parameters must match"
        );

        for (uint256 i = 0; i < level_treshholds.length; i++) {
            if (i > 0) {
                require(
                    level_treshholds[i] > level_treshholds[i - 1],
                    "Next level must have higher treshhold than previous"
                );
            } else {
                level_treshholds[0] = 0; // why?
            }
            require(level_minimums[i] <= level_maximums[i], "Level minimum must be lower or equal to level maximum");

            levels.push(Level(level_treshholds[i], level_minimums[i], level_maximums[i]));
        }

        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
