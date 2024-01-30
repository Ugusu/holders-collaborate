// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

abstract contract Admin {
    error AdminUnauthorised(address msgSender);
    /**
     * @dev Mapping of admin addresses
     */
    mapping(address => bool) public admins;
    event AdminSet(address indexed admin, bool value);
    /**
     * @dev Modifier to make a function callable only when called by one of the admins
     */
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    /**
     * @dev Contract constructor
     */
    constructor(address initialAdmin) {
        admins[initialAdmin] = true;
        emit AdminSet(initialAdmin, true);
    }

    /**
     * @dev Function to set a new admin
     * @param admin admin address to add/remove
     * @param value set bool value
     */
    function setAdmin(address admin, bool value) public virtual {
        admins[admin] = value;
        emit AdminSet(admin, value);
    }

    function _checkAdmin() internal view {
        if (!admins[msg.sender]) {
            revert AdminUnauthorised(msg.sender);
        }
    }
}
