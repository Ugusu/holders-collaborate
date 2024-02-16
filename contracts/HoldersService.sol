// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Level, Token, Status, Collaborator, LevelTemplate, TokenTemplate} from "./Elements.sol";
import "./HoldersFactory.sol";

interface ERC20 {
    function balanceOf(address _account) external view returns (uint256);
    function allowance(address holder, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract HoldersService is HoldersFactory, Admin(msg.sender), Ownable(msg.sender) {
    modifier onlyUpcoming() {
        require(getStatus() == Status.UPCOMING, "HoldersService: Not UPCOMING");
        _;
    }

    // Checks, if user alredy contributed to another token
    function inAnotherToken(address _token, address _collaborator) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token) {
                continue;
            }

            address currentToken = tokens[i].adrs;

            for (uint256 j = 0; j < collaborators[currentToken].length; j++) {
                if (collaborators[currentToken][j].adrs == _collaborator) {
                    return true;
                }
            }
        }

        return false;
    }

    // If after end, FINISHED. If internal status ACTIVE, before start UPCOMING
    // after start, if balance complete ACTIVE, else PENDING
    // If internal PAUSED (not ACTIVE) PAUSED.
    function getStatus() public view returns (Status) {
        if (block.timestamp >= end) {
            return Status.FINISHED;
        }
        if (status == Status.PAUSED){
            return Status.PAUSED;
        }  
        if (block.timestamp < start) {
            return Status.UPCOMING;
        } 
        if (checkBalances(levels[levels.length - 1])) {
            return Status.ACTIVE;
        } else {
            return Status.PENDING;
        }
    }

    // Convert token amount to USD
    function tokenToUsd(address _token, uint256 _amount) public view returns (uint256) {
        bool found = false;
        uint256 usdAmount = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].adrs == _token) {
                usdAmount = _amount * tokens[i].price;
                found = true;
            }
        }
        require(found, "HoldersService: token/USD error");

        return usdAmount;
    }

    // Check if token is in collaboration
    function tokenIsPresent(address _token) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (_token == tokens[i].adrs) {
                return true;
            }
        }
        return false;
    }

    // Check if amount is in level min and max boundaries
    function matchesLevelExtremes(address _token, uint256 _amount) public view returns (bool) {
        Token memory operationToken = getTokenByAddress(_token);
        uint256 tokenAmount = operationToken.amount;
        uint256 amountUsd = tokenToUsd(_token, _amount);
        uint256 lastLevelId = levels.length - 1;

        Level memory currentLevel = getActiveLevel();
        // Must be between min and max, must be not last level or if last level, within treshhold + minimum
        if (
            amountUsd >= currentLevel.minimum &&
            amountUsd <= currentLevel.maximum &&
            (currentLevel.id < lastLevelId || tokenAmount + amountUsd <= currentLevel.treshhold + currentLevel.minimum)
        ) {
            return true;
        }

        return false;
    }

    // Check if tokens can be transfered
    function isTranferAllowed(address _token, address _holder, uint256 _amount) public view returns (bool) {
        ERC20 tokenContract = ERC20(_token);
        uint256 allowedAmount = tokenContract.allowance(_holder, address(this));
        uint256 holderBalance = tokenContract.balanceOf(_holder);
        return allowedAmount >= _amount && holderBalance >= _amount;
    }

    function acceptTranfer(address _token, address _holder, uint256 _amount) internal returns (bool) {
        require(isTranferAllowed(_token, _holder, _amount), "HoldersHelpers: tranfer not allowed");
        ERC20 tokenContract = ERC20(_token);
        return tokenContract.transferFrom(_holder, address(this), _amount);
    }

    // Check if treshholds for later levels are higher than for earlier levels
    function checkLevelParamsConsistency(Level memory _level) public view returns (bool) {
        uint256 levelId = _level.id;

        require(_level.minimum <= _level.maximum, "HoldersService: Must be min <= max");
        if (levelId > 0) {
            require(_level.id > levels[levelId - 1].id, "HoldersService: Order must increase");
            require(_level.treshhold > levels[levelId - 1].treshhold, "HoldersService: Treshhold must increase");
            require(_level.reward > levels[levelId - 1].reward, "HoldersService: Reward must increase");
        }
        if (levelId < levels.length - 1) {
            require(_level.id < levels[levelId + 1].id, "HoldersService: Order must increase");
            require(_level.treshhold < levels[levelId + 1].treshhold, "THoldersService: reshhold must increase");
            require(_level.reward < levels[levelId + 1].reward, "HoldersService: Reward must increase");
        } else {
            require(checkBalances(_level), "HoldersService: Insufficient balance");
        }

        return true;
    }

    // Check contract balance before collaboration start
    function checkBalances(Level memory _level) public view returns (bool) {
        uint256 levelTreshhold = _level.treshhold;
        uint256 levelMinimum = _level.minimum;
        uint256 levelReward = _level.reward;

        uint256 requiredAmountUsd = ((levelTreshhold + levelMinimum) * levelReward * (tokens.length - 1)) / 10000;

        // Ceil
        if (((levelTreshhold + levelMinimum) * levelReward * (tokens.length - 1)) % 10000 != 0) {
            requiredAmountUsd++;
        }

        // Iterate over tokens and check balance for each.
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20 tokenContract = ERC20(tokens[i].adrs);

            uint256 contractsTokenBalanceUsd = tokenToUsd(tokens[i].adrs, tokenContract.balanceOf(address(this)));

            if (contractsTokenBalanceUsd < requiredAmountUsd) {
                return false;
            }
        }

        return true;
    }

    // Creates array of Tokens, with amount 0 for each.
    function setTokens(TokenTemplate[] memory _tokens) public onlyOwner onlyUpcoming returns (bool) {
        delete tokens;

        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i].adrs != address(0), "HoldersService: adrs 0");
            require(_tokens[i].price > 0, "HoldersService: price 0");
            tokens.push(Token(_tokens[i].adrs, _tokens[i].price, 0));
        }

        return true;
    }

    // Creates array of Levels
    function setLevels(LevelTemplate[] memory _levels) public onlyOwner onlyUpcoming returns (bool) {
        delete levels;

        for (uint256 i = 0; i < _levels.length; i++) {
            _levels[i].treshhold = _levels[i].treshhold * 1 ether;
            _levels[i].minimum = _levels[i].minimum * 1 ether;
            _levels[i].maximum = _levels[i].maximum * 1 ether;

            require(_levels[i].minimum <= _levels[i].maximum, "HoldersService: Must be min <= max");
            require(
                _levels[i].reward >= 0 && _levels[i].reward <= 10000,
                "HoldersService: Must be 0 <= reward <= 10000"
            );
            if (i > 0) {
                require(_levels[i].treshhold > _levels[i - 1].treshhold, "HoldersService: Treshhold must increase");
                require(_levels[i].reward > _levels[i - 1].reward, "HoldersService: Reward must increase");
            }

            levels.push(Level(
                i,
                _levels[i].name,
                _levels[i].treshhold,
                _levels[i].minimum,
                _levels[i].maximum,
                _levels[i].reward
            ));
        }

        return true;
    }
}
