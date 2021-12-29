// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "./ICnydToken.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
abstract contract Ownable is IOwnable
{
    address private _owner;
    address private _proposedOwner;

    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() {
        _owner = msg.sender;
    }

    function owner() public view virtual override returns(address) {
        return _owner;
    }

    function proposedOwner() public view virtual override returns(address) {
        return _proposedOwner;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    /**
    * @dev Throws if called by any account other than the proposed owner.
    */
    modifier onlyProposedOwner() {
        require(_proposedOwner != address(0) && msg.sender == _proposedOwner, 
            "Ownable: caller is not the proposed owner");
        _;
    }

    modifier onlyNonZeroAccount(address account) {
        require(account != address(this), "Governable: zero account not allowed" );
        _;
    }

    /**
    * @dev propose a new owner by an existing owner
    * @param newOwner The address proposed to transfer ownership to.
    */
    function proposeOwner(address newOwner) public virtual override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _proposedOwner = newOwner;
        emit OwnershipProposed(newOwner);
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    */
    function takeOwnership() public virtual override onlyProposedOwner {
        _transferOwnership(_proposedOwner);
        _proposedOwner = address(0);
    }

    /**
    * @dev Transfers control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: zero address not allowed");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}
