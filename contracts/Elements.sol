// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

struct Level {
    /*
        Levels of the Collaboration:
            id - id of the level in array
            levelName - the name of the level
            threshold - threshold needed, to be active
            minimum - minimum contribution value
            maximum - maximum contribution value
            active - if the level is currently active
    */
    uint256 id;
    string name;
    uint256 threshold;
    uint256 minimum;
    uint256 maximum;
    uint256 reward;
}

struct LevelTemplate {
    /*
        Levels of the Collaboration:
            levelName - the name of the level
            threshold - threshold needed, to be active
            minimum - minimum contribution value
            maximum - maximum contribution value
            active - if the level is currently active
    */
    string name;
    uint256 threshold;
    uint256 minimum;
    uint256 maximum;
    uint256 reward;
}

struct Token {
    /* 
        Allowed tokens for the Collaboration and current USD balance of each:
            adrs - address of the token
            price - usd price of the token on create
            amount - total collected amount for token in USD
    */
    address adrs;
    uint256 price;
    uint256 amount;
}

struct TokenTemplate {
    /* 
        Allowed tokens for the Collaboration and current USD balance of each:
            adrs - address of the token
            price - usd price of the token on create
    */
    address adrs;
    uint256 price;
}

struct Collaborator {
    /*
        Participants of the Collaboration and current USD contribution of each:
            adrs - address of Collaborator user
            amount - amount contributed in usd
    */
    address adrs;
    uint256 amount;
}

// Status of the Collaboration
enum Status {
    UPCOMING,
    PENDING,
    ACTIVE,
    PAUSED,
    FINISHED
}
