// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

struct Level {
    /*
        Levels of the competition:
            order - to order levels in array
            treshhold - treshhold needed, to be active
            minimum - minimum contribution value
            maximum - maximum contribution value
            active - if the level is currently active
    */
    uint256 treshhold;
    uint256 minimum;
    uint256 maximum;
    uint256 reward;
}

struct Token {
    /* 
        Allowed tokens for the competition and current USD balance of each:
            token_address - address of the token
            token_usd_price - usd price of the token on create
    */
    address tokenAddress;
    uint256 tokenUsdPrice;
    uint256 value;
}

struct Competitor {
    /*
        Participants of the competition and current USD contribution of each:
            competitior_address - address of competitor/contributor user
            value - value contributed in usd
    */
    address competitorAddress;
    uint256 value;
}

// Status of the competitions
enum Status {
    Upcoming,
    Active,
    Paused,
    Finished
}

struct Competition {
    /*
        Competition:
            creator - creator of the competition
            owner - current owner of the competition
            tokens - allowed tokens for the competition
            start - start timestamp of the competition
            end - end timestamp of the competition
            levels - levels in the competition
            reward_percentage - rewards for the competitors
            competitors - participants of the competition
            total_usd - current total USD value of the competition
            status - status of the competition (Upcoming, Active, Paused, Finished)
    */
    Token[] tokens;
    uint256 start;
    uint256 end;
    Level[] levels;
    uint256 rewardPercentage;
    Competitor[] competitors;
    mapping(address => uint256) competitorIndexes;
    uint256 totalUsd;
    Status status;
}
