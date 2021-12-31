// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ICnydToken.sol";
import "./Ownable.sol";

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
abstract contract FrozenableToken is Administrable, IFrozenableToken
{

    mapping (address => bool) private _frozenAccounts;


    modifier whenNotFrozen(address account) {
      require(!_frozenAccounts[msg.sender] && !_frozenAccounts[account], "account frozen");
      _;
    }

    function isAccountFrozen(address account) public view virtual override returns(bool) {
        return _frozenAccounts[account];
    }

    function freezeAccount(address account) public virtual override
        onlyAdmin()
        onlyNonZeroAccount(account) 
    {
        require(!_frozenAccounts[account], "FrozenableToken: account has been frozen");
        _frozenAccounts[account] = true;
        emit AccountFrozen(account);
    }

    function unfreezeAccount(address account) public virtual override
        onlyAdmin()
        onlyNonZeroAccount(account) 
    {
        require(_frozenAccounts[account], "FrozenableToken: account not been frozen");
        _frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }
}

abstract contract AdminFee is Administrable, IAdminFee {
    
    struct FeeRatioData {
        uint256 ratio;
        bool    enabled;
    }

    uint256 internal constant _RATIO_PRECISION = 10000;

    uint256 private _adminFeeRatio;
    address private _feeRecipient;
    mapping(address => bool) private _adminFeeWhiteList;

    function ratioPrecision() external view virtual override returns(uint256) {
        return _RATIO_PRECISION;
    }

    function adminFeeRatio() public view virtual override returns(uint256) {
        return _adminFeeRatio;
    }

    function setAdminFeeRatio(uint256 ratio) public virtual override onlyAdmin {
        emit AdminFeeRatioChanged(_adminFeeRatio, ratio);
        _adminFeeRatio = ratio;
    }

    function feeRecipient() public view virtual override returns(address) {
        return _feeRecipient;
    }

    function setFeeRecipient(address recipient) public virtual override onlyAdmin {
        emit FeeRecipientChanged(_feeRecipient, recipient);
        _feeRecipient = recipient;
    }

    function isInFeeWhiteList(address account) public view virtual override returns(bool) {
        return _adminFeeWhiteList[account];
    }

    function addFeeWhiteList(address[] memory accounts) public virtual override onlyAdmin {
        require(accounts.length > 0, "empty accounts not allowed");
        for (uint i = 0; i < accounts.length; i++) {
            _adminFeeWhiteList[accounts[i]] = true;
        }
        emit FeeWhiteListAdded(accounts);
    }

    function delFeeWhiteList(address[] memory accounts) public virtual override onlyAdmin {
        require(accounts.length > 0, "empty accounts not allowed");
        for (uint i = 0; i < accounts.length; i++) {
            delete _adminFeeWhiteList[accounts[i]];
        }
        emit FeeWhiteListDeleted(accounts);
    }

    function _calcAdminFee(address account, uint256 amount) internal view returns(uint256) {
        if (_feeRecipient != address(0) && _adminFeeRatio != 0 && !_adminFeeWhiteList[account]) {
            return amount * _adminFeeRatio / _RATIO_PRECISION;
        }
        return 0;
    }
    
}

contract CnydToken is ERC20, Pausable, Ownable, FrozenableToken, AdminFee, ICnydToken {

    uint8 private constant _decimals = 6;

    constructor() ERC20("CNY Digital", "CNYD") {
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function pause() public virtual override onlyAdmin {
        _pause();
    }

    function unpause() public virtual override onlyAdmin {
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
    function mint(address to, uint256 amount) public virtual override onlyAdmin {
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
    function burn(uint256 amount) public virtual override onlyAdmin {
        _burn(address(this), amount);
    }

    function forceTransfer(address from, address to, uint256 amount) public virtual override onlyAdmin() {
        super._transfer(from, to, amount); // ignore the paused and frozen strategy
        emit ForceTransfer(from, to, amount);
    }

   function _transfer(address sender, address recipient, uint256 amount) internal override
        whenNotPaused  
        whenNotFrozen(sender)
        whenNotFrozen(recipient)
    {
        require(amount > 0, "CnydToken: non-positive amount not allowed");
        
        super._transfer(sender, recipient, amount);

        uint256 fee = _calcAdminFee(sender, amount);
        if (fee > 0) {
            // transfer admin fee to feeRecipient
            require(balanceOf(sender) >= fee, "CnydToken: insufficient balance for admin fee");
            super._transfer(sender, feeRecipient(), fee);
        }
    }

}