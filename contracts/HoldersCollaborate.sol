// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Competitor} from "./Elements.sol";

contract HoldersCollaborate is Admin(msg.sender), Ownable(msg.sender) {
    constructor(
        address[] memory tokensAddresses,
        uint256[] memory tokenUsdPrices,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 rewardPercentage,
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums
    ) {
        require(block.timestamp < startTimestamp, "Can't create competition in the past");
        require(startTimestamp < endTimestamp, "End time should be after start time");
        // TODO: in theory, the rewardPercentage can be any percentage. But this is also a good approach
        require(rewardPercentage >= 0 && rewardPercentage <= 10000, "Reward must be between 0.00 and 100.00 (0-10000)");
        //
        createTokens(tokensAddresses, tokenUsdPrices);
        createLevels(levelsTreshholds, levelsMinimums, levelsMaximums);
        start = startTimestamp;
        end = endTimestamp;
        reward = rewardPercentage;

        competitionAlreadyCreated = true;
    }

    bool competitionAlreadyCreated = false;

    Token[] public tokens;
    Level[] public levels;
    Competitor[] public competitors;

    mapping(address => uint256) public competitorIndexes;

    uint256 public start = 0;
    uint256 public end = 0;
    uint256 public reward = 0;

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

        uint256 competitorId = getCompetitorId(msg.sender);
        if (competitorId == competitors.length) {
            competitors.push(Competitor(msg.sender, 0));
            competitorIndexes[msg.sender] = competitorId;
        }

        uint256 tokenUsdAmount = tokenToUsd(token, amount);
        competitors[competitorId].value += tokenUsdAmount;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == token) {
                tokens[i].value += tokenUsdAmount;
            }
        }

        emit Contributed(msg.sender, token, amount, tokenUsdAmount);

        return true;
    }

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

    // Check if token is in competition
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
        // find the value of the token if it exists
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                tokenValue = tokens[i].value;
            }
        }

        // check if the amount is in the level boundaries
        for (uint256 i = 0; i < levels.length; i++) {
            if (tokenValue <= levels[i].treshhold) {
                if (amountUsd >= levels[i].minimum && amountUsd <= levels[i].maximum) {
                    return true;
                }
            }
        }

        // if last level, if current value + contribute value less equals last level treshhold + it's minumum, allowed
        if (
            tokenValue < levels[levels.length - 1].treshhold &&
            tokenValue + amountUsd <= levels[levels.length - 1].treshhold + levels[levels.length - 1].minimum
        ) {
            return true;
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

    // Changes levels of the competition
    function changeLevels(
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change existing levels after start time");

        competitionAlreadyCreated = false;
        delete levels;
        createLevels(levelsTreshholds, levelsMinimums, levelsMaximums);
        competitionAlreadyCreated = true;

        return true;
    }

    // Changes tokens of the competition
    function changeTokens(
        address[] memory tokensAddresses,
        uint256[] memory tokenUsdPrices
    ) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change tokens after start time");

        competitionAlreadyCreated = false;
        delete tokens;
        createTokens(tokensAddresses, tokenUsdPrices);
        competitionAlreadyCreated = true;

        return true;
    }

    // Changes reward percentage
    function changeRewardPercentage(uint256 rewardPercentage) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change reward after start time");

        reward = rewardPercentage;

        return true;
    }

    // Changes start and end time
    function changeStartEndTime(uint256 startTimestamp, uint256 endTimestamp) public onlyOwner returns (bool) {
        require(block.timestamp < start, "Can't change start and end times after start time");

        start = startTimestamp;
        end = endTimestamp;

        return true;
    }

    // Adds new level
    function addLevel(
        uint256 levelTreshhold,
        uint256 levelMinimum,
        uint256 levelMaximum
    ) public onlyOwner returns (bool) {
        require(competitionAlreadyCreated, "First a competition has to be created");
        require(
            levelTreshhold > levels[levels.length - 1].treshhold,
            "New level's treshhold must be higher than last existing level's treshhold"
        );
        require(levelMinimum <= levelMaximum, "Level minimum must be lower or equal to level maximum");

        levels.push(Level(levelTreshhold, levelMinimum, levelMaximum));

        return true;
    }

    // Getters
    function getCompetitorId(address competitorAddress) public view returns (uint256) {
        uint256 competitorId = 0;

        if (competitorAddress != competitors[0].competitorAddress) {
            if (competitorIndexes[competitorAddress] > 0) {
                competitorId = competitorIndexes[competitorAddress];
            } else {
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

    function getCompetitorById(uint256 competitorId) public view returns (Competitor memory) {
        return competitors[competitorId];
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
    }

    function getLevel(uint256 levelOrder) public view returns (Level memory) {
        return levels[levelOrder];
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

    // One time functions

    // Creates array of Tokens, with value 0 for each.
    function createTokens(
        address[] memory tokensAddresses,
        uint256[] memory tokenUsdPrices
    ) public onlyOwner returns (bool) {
        require(!competitionAlreadyCreated, "Competition already created");
        require(tokensAddresses.length >= 2, "At least 2 tokens required");
        require(tokensAddresses.length == tokenUsdPrices.length, "Number of token and USD prices must be same");

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            require(tokensAddresses[i] != address(0), "Zero address can't be a token");
            require(tokenUsdPrices[i] != 0, "Token USD price can't be zero");
            tokens.push(Token(tokensAddresses[i], tokenUsdPrices[i], 0));
        }

        return true;
    }

    // Creates array of Levels, puts first level as active.
    function createLevels(
        uint256[] memory levelsTreshholds,
        uint256[] memory levelsMinimums,
        uint256[] memory levelsMaximums
    ) public onlyOwner returns (bool) {
        require(!competitionAlreadyCreated, "Competition already created");
        require(levelsTreshholds.length >= 1, "At least one level is required");
        require(
            levelsMinimums.length == levelsTreshholds.length && levelsMaximums.length == levelsTreshholds.length,
            "Number of level parameters must match"
        );

        for (uint256 i = 0; i < levelsTreshholds.length; i++) {
            require(levelsTreshholds[i] > levelsTreshholds[i - 1], "Next level must have higher treshhold than previous");
            require(levelsMinimums[i] <= levelsMaximums[i], "Level minimum must be lower or equal to level maximum");

            levels.push(Level(levelsTreshholds[i], levelsMinimums[i], levelsMaximums[i]));
        }

        return true;
    }

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
