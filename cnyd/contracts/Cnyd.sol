// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ICnyd.sol";

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

    function owner() external view virtual override returns(address) {
        return _owner;
    }

    function proposedOwner() external view virtual override returns(address) {
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

abstract contract Administrable is Ownable, IAdministrable {

    address private _admin;

    constructor() {
        _admin = msg.sender;
    }

    /**
    * @dev Throws if called by any account other than the admin.
    */
    modifier onlyAdmin() {
        require(msg.sender == _admin, "Administrable: caller is not the admin");
        _;
    }

    function admin() external view virtual override returns(address) {
        return _admin;
    }

    function setAdmin(address newAdmin) public virtual override 
        onlyOwner() 
        onlyNonZeroAccount(newAdmin) 
    {
        emit AdminChanged(_admin, newAdmin);
        _admin = newAdmin;
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

abstract contract AdminFee is Administrable {
    
    struct FeeRatioData {
        uint256 ratio;
        bool    enabled;
    }

    uint256 public constant RATIO_PRECISION = 1000;

    uint256 private _adminFeeRatio;
    address private _feeRecipient;
    mapping(address => bool) private _adminFeeWhiteList;

    event AdminFeeRatioChanged(uint256 oldRatio, uint256 newRatio);
    event FeeRecipientChanged(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event AdminFeeWhiteListAdded(address[] accounts);
    event AdminFeeWhiteListDeleted(address[] accounts);


    function adminFeeRatio() public view returns(uint256) {
        return _adminFeeRatio;
    }
    function setAdminFeeRatio(uint256 ratio) public onlyAdmin {
        emit AdminFeeRatioChanged(_adminFeeRatio, ratio);
        _adminFeeRatio = ratio;
    }

    function feeRecipient() public view returns(address) {
        return _feeRecipient;
    }

    function setFeeRecipient(address recipient) public onlyAdmin {
        emit FeeRecipientChanged(_feeRecipient, recipient);
        _feeRecipient = recipient;
    }

    function adminFeeWhiteList(address account) public view returns(bool) {
        return _adminFeeWhiteList[account];
    }

    function addAdminFeeWhiteList(address[] memory accounts) public onlyAdmin {
        require(accounts.length > 0, "empty accounts not allowed");
        for (uint i = 0; i < accounts.length; i++) {
            _adminFeeWhiteList[accounts[i]] = true;
        }
        emit AdminFeeWhiteListAdded(accounts);
    }

    function delAdminFeeWhiteList(address[] memory accounts) public onlyAdmin {
        require(accounts.length > 0, "empty accounts not allowed");
        for (uint i = 0; i < accounts.length; i++) {
            delete _adminFeeWhiteList[accounts[i]];
        }
        emit AdminFeeWhiteListDeleted(accounts);
    }

    function _getAccountFeeRatio(address account) internal view returns(uint256) {
        return _feeRecipient != address(0) && _adminFeeRatio != 0 && !_adminFeeWhiteList[account] ? _adminFeeRatio : 0;
    }
    
}

contract Cnyd is ERC20, Pausable, Ownable, FrozenableToken, AdminFee {

    event ForceTransfer(address indexed from, address indexed to, uint256 amount);

    uint8 private constant _decimals = 6;

    constructor() ERC20("CNY Digital", "CNYD") {
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
        require(amount > 0, "Cnyd: non-positive amount not allowed");
        uint256 fee = amount * _getAccountFeeRatio(sender) / RATIO_PRECISION;
        if (fee > 0) {
            require(balanceOf(sender) >= amount + fee, "Cnyd: insufficient balance for admin fee");
        }

        super._transfer(sender, recipient, amount);

        if (fee > 0) {
            // transfer admin fee to feeRecipient
            super._transfer(sender, feeRecipient(), fee);
        }
    }

}