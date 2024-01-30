// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Admin} from "./Admin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HoldersCollaborate is Admin(msg.sender), Ownable(msg.sender) {
    constructor() {}

    function setAdmin(address admin, bool value) public override onlyOwner {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }
}
