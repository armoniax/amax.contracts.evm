// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IOwnable {

    event OwnershipProposed(address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    function owner() external view returns(address);
    function proposedOwner() external view returns(address);

    /**
    * @dev propose a new owner by an existing owner
    * @param newOwner The address proposed to transfer ownership to.
    */
    function proposeOwner(address newOwner) external;

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    */
    function takeOwnership() external;
}

interface IAdministrable {

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    function admin() external view returns(address);

    function setAdmin(address newAdmin) external;
}

/**
 * @title Frozenable Token
 * @dev Illegal address that can be frozened.
 */
interface IFrozenableToken {

    event AccountFrozen(address indexed to);
    event AccountUnfrozen(address indexed to);

    function isAccountFrozen(address account) external view returns(bool);

    function freezeAccount(address account) external;

    function unfreezeAccount(address account) external;
}

interface IAdminFee {

    event AdminFeeRatioChanged(uint256 oldRatio, uint256 newRatio);
    event FeeRecipientChanged(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event FeeWhitelistAdded(address[] accounts);
    event FeeWhitelistDeleted(address[] accounts);


    function ratioPrecision() external view returns(uint256);

    function adminFeeRatio() external view returns(uint256);

    function setAdminFeeRatio(uint256 ratio) external;

    function feeRecipient() external view returns(address);

    function setFeeRecipient(address recipient) external;

    function isInFeeWhitelist(address account) external view returns(bool);

    function addFeeWhitelist(address[] memory accounts) external;

    function delFeeWhitelist(address[] memory accounts) external;
    
}

interface ICnydToken is IERC20 {

    event ForceTransfer(address indexed from, address indexed to, uint256 amount);

    function pause() external;

    function unpause() external;

    /** @dev Creates `amount` tokens and assigns them to `to`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(address to, uint256 amount) external;


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
    function burn(uint256 amount) external;

    function forceTransfer(address from, address to, uint256 amount) external;

    /**
     * A query function that returns the amount of tokens a receiver will get if a sender sends `sentAmount` tokens. 
     * Note the `to` and `from` addresses are present, the implementation should use those values to check for any whitelist.
     */
    function getReceivedAmount(
        address from,
        address to,
        uint256 sentAmount
    ) external view returns (uint256 receivedAmount, uint256 feeAmount);

    /**
     * Returns the amount of tokens the sender has to send if he wants the receiver to receive exactly `receivedAmount` tokens.
     * Note the `to` and `from` addresses are present, the implementation should use those values to check for any whitelist.
     */
    function getSentAmount(
        address from,
        address to,
        uint256 receivedAmount
    ) external view returns (uint256 sentAmount, uint256 feeAmount);
}
