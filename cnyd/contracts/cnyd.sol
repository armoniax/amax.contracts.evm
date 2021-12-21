// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
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
    * @dev Returns the bep token owner.
    */
    function getOwner() external view returns (address) {
        return owner;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
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


abstract contract Governable is Ownable {

    // uint256 public constant RATIO_DECIMALS = 4;  /** ratio decimals */
    // uint256 public constant RATIO_PRECISION = 10 ** RATIO_DECIMALS /** ratio precision， 10000 */;
    // uint256 public constant MAX_FEE_RATIO = 1 * RATIO_PRECISION - 1; /** max fee ratio, 100% */
    // uint256 public constant MIN_APPROVE_RATIO = 6666 ; /** min approve ratio, 66.66% */
    uint256 public constant PROPOSAL_DURATION = 24 * 3600; // one day in second
    uint256 public constant APPROVER_COUNT = 3;

    enum ApprovedStatus { NONE, STARTED, APPROVED, OPPOSED }

    event ApproverChanged(uint256 id, address indexed newAccount, address indexed oldAccount);
    event ProposerChanged(address indexed account, bool enabled);

    address[APPROVER_COUNT] public approvers;

    mapping (address => bool) public proposers;

    /**
    * @dev Throws if called by any account other than the approver.
    */
    modifier onlyApprover() {
        require(_isApprover(msg.sender), "Governable: caller is not an approver");
        _;
    }

    /**
    * @dev Throws if called by any account other than the proposer.
    */
    modifier onlyProposer() {
        require(proposers[msg.sender], "Governable: caller is not a proposer");
        _;
    }

    function _isApprover(address account) internal view returns(bool) {
        for (uint256 i = 0; i < approvers.length; i++) {
            if (approvers[i] == account)
                return true;
        }
        return false;
    }

    function _setApprover(uint256 id, address account) internal onlyOwner {
        require(id < APPROVER_COUNT, "Governable: approver id is out of range");
        require(account != approvers[id], "Governable: the account is same as the old one");
        require(!_isApprover(account), "Governable: the account is already an approver");

        address oldAccount = approvers[id];
        approvers[id] = account;
        emit ApproverChanged(id, account, oldAccount);
    }

    function setProposer(address account, bool enabled) public onlyApprover() {
        require(proposers[account] != enabled, "Governable: no change of enabled");
        proposers[account] = enabled;
        emit ProposerChanged(account, enabled);
    }

    function _accountExistIn(address account, address[] memory accounts) internal pure returns(bool) {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (account == accounts[i]) return true;
        }
        return false;
    }

    function _isProposalExpired(uint startTime) internal view returns(bool) {   
        return block.timestamp > startTime + PROPOSAL_DURATION;    
    }
}

abstract contract Mintable is Governable {

    event MintProposed(address indexed proposer, uint256 amount);
    event MintApproved(address indexed approver, address indexed proposer, bool approved, uint256 amount);
    // event MintEmitted(address indexed proposer, uint256 amount, address indexed emitter);

    struct ProposalMintData {
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => ProposalMintData) public proposalMints; /** proposer -> ProposalMintData */

    address public holder;

    function setHolder(address newHolder) public onlyOwner() {
        require(newHolder != address(0), "Mintable: zero address not allowed");
        holder = newHolder;
    }

    /**
    * @dev propose to mint
    * @param amount amount to mint
    * @return mint propose ID
    */
    function proposeMint(uint256 amount) public onlyProposer() returns(bool) {
        require(amount > 0, "Mintable: zero amount not allowed" );
        require(!_isApprovable(msg.sender), "Mintable: proposal is approving" );

        delete proposalMints[msg.sender];
        //mint by a proposer for once only otherwise would be overwritten
        proposalMints[msg.sender].amount = amount;
        proposalMints[msg.sender].startTime = block.timestamp;
        emit MintProposed(msg.sender, amount);

        return true;
    }

    function approveMint(address proposer, bool approved, uint256 amount) public onlyApprover() returns(bool) {

        require( _isApprovable(proposer), "Mintable: proposal is not approvable" );
        require( proposalMints[proposer].amount == amount, "Mintable: amount mismatch" );
        require( !_accountExistIn(msg.sender, proposalMints[proposer].approvers),
            "Mintable: approver has already approved" );

        emit MintApproved(msg.sender, proposer, approved, amount); 

        if (approved) {
            proposalMints[proposer].approvers.push(msg.sender);
            if (proposalMints[proposer].approvers.length == APPROVER_COUNT) {
                _doMint(holder, amount);
                delete proposalMints[proposer];  
            }
        } else {
            delete proposalMints[proposer];           
        }

        return true;
    }

    function _doMint(address to, uint256 amount) internal virtual;


    function _isApprovable(address proposer) internal view returns(bool) {
        return proposalMints[proposer].amount > 0 
            && !_isProposalExpired(proposalMints[proposer].startTime);
    }
}


abstract contract Burnable is Governable {
}

contract Cnyd is ERC20, ERC20Burnable, Pausable, Mintable, Burnable{


    uint8 private constant _decimals = 4;

    constructor(address[3] memory _approvers) ERC20("cnyd", "CNYD") {
        holder = msg.sender;
        approvers = _approvers;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


    function _doMint(address to, uint256 amount) internal override {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}