// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

struct Level {
    /*
        Levels of the Collaboration:
            levelOrder - to order levels in array
            levelName - the name of the level
            treshhold - treshhold needed, to be active
            minimum - minimum contribution value
            maximum - maximum contribution value
            active - if the level is currently active
    */
    uint256 levelOrder;
    string levelName;
    uint256 treshhold;
    uint256 minimum;
    uint256 maximum;
    uint256 reward;
}

struct Token {
    /* 
        Allowed tokens for the Collaboration and current USD balance of each:
            token_address - address of the token
            token_usd_price - usd price of the token on create
            amount - total collected amount for token in USD
    */
    address tokenAddress;
    uint256 tokenUsdPrice;
    uint256 amount;
}

struct Collaborator {
    /*
        Participants of the Collaboration and current USD contribution of each:
            competitior_address - address of Collaborator user
            amount - amount contributed in usd
    */
    address collaboratorAddress;
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
