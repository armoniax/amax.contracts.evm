// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
abstract contract Ownable
{
    address public owner;
    address private proposedOwner;

    event OwnershipProposed(address indexed newOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() {
        owner = msg.sender;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
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
    function proposeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        proposedOwner = newOwner;
        emit OwnershipProposed(newOwner);
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    */
    function takeOwnership() public {
        require(proposedOwner == msg.sender, "Ownable: not the proposed owner");
        _transferOwnership(proposedOwner);
    }

    /**
    * @dev Transfers control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: zero address not allowed");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

abstract contract Administrable is Ownable
{
    address public admin;

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor() {
        admin = msg.sender;
    }

    /**
    * @dev Throws if called by any account other than the admin.
    */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Administrable: caller is not the admin");
        _;
    }

    function setAdmin(address newAdmin) public onlyOwner() onlyNonZeroAccount(newAdmin) {
        emit OwnershipTransferred(owner, newAdmin);
        admin = newAdmin;
    }

}

/**
 * @title Frozenable Token
 * @dev Illegal address that can be frozened.
 */
abstract contract FrozenableToken is Administrable
{
    event AccountFrozen(address indexed to);
    event AccountUnfrozen(address indexed to);

    mapping (address => bool) public frozenAccounts;


    modifier whenNotFrozen(address account) {
      require(!frozenAccounts[msg.sender] && !frozenAccounts[account], "account frozen");
      _;
    }

    function freezeAccount(address account) public 
        onlyAdmin()
        onlyNonZeroAccount(account) 
        returns(bool) 
    {
        require(!frozenAccounts[account], "FrozenableToken: account has been frozen");
        frozenAccounts[account] = true;
        emit AccountFrozen(account);
        return true;
    }

    function unfreezeAccount(address account) public 
        onlyAdmin()
        onlyNonZeroAccount(account) 
        returns(bool) 
    {
        require(frozenAccounts[account], "FrozenableToken: account not been frozen");
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
        return true;
    }
}

contract Cnyd is ERC20, Pausable, Ownable, FrozenableToken {

    event ForceTransfer(address indexed from, address indexed to, uint256 amount);

    uint8 private constant _decimals = 4;

    constructor() ERC20("cnyd", "CNYD") {
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    /** @dev Creates `amount` tokens and assigns them to `to`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(address to, uint256 amount) public onlyAdmin {
        _mint(to, amount);
    }


    /**
     * @dev Destroys `amount` tokens from contract account, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 amount) public onlyAdmin {
        _burn(address(this), amount);
    }

    function forceTransfer(address from, address to, uint256 amount) public onlyAdmin() {
        super._transfer(from, to, amount); // ignore the paused and frozen strategy
        emit ForceTransfer(from, to, amount);
    }

   function _transfer(address sender, address recipient, uint256 amount) internal override
        whenNotPaused  
        whenNotFrozen(sender)
        whenNotFrozen(recipient)
    {
        super._transfer(sender, recipient, amount);
    }

}