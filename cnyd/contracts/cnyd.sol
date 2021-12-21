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

    // TODO: set PROPOSAL_DURATION
    uint256 public constant PROPOSAL_DURATION = 24 * 3600; // one day in second
    uint256 public constant APPROVER_COUNT = 3;

    enum ApprovedStatus { NONE, STARTED, APPROVED, OPPOSED }

    event ApproverChanged(uint256 idndex, address indexed newAccount, address indexed oldAccount);
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

    /**
    * @dev Throws if called by any account other than the approver and owner.
    */
    modifier onlyApproverAndOwner() {
        require(_isApprover(msg.sender) || msg.sender == owner, "Governable: caller is not an approver or owner");
        _;
    }

    function _isApproverDuplicated(address[APPROVER_COUNT] memory _approvers) internal pure returns(bool) {
        for (uint256 i = 0; i < _approvers.length; i++) {
            for (uint256 j = i + 1; j < _approvers.length; j++) {
                if (_approvers[i] == _approvers[j]) {
                    return true;
                }
            }
        }
        return false;
    }

    function _setApprovers(address[APPROVER_COUNT] memory _approvers) internal {
        require(!_isApproverDuplicated(_approvers), "approvers duplicated");
        approvers = _approvers; 
        for (uint256 i = 0; i < _approvers.length; i++) {
            emit ApproverChanged(i, _approvers[i], address(0));
        }               
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

    function _isBalanceEnough(address account, uint256 amount) internal view virtual returns(bool);
}

abstract contract Mintable is Governable {

    event MintProposed(address indexed proposer, uint256 amount);
    event MintApproved(address indexed approver, address indexed proposer, bool approved, uint256 amount);

    struct MintProposalData {
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => MintProposalData) public mintProposals; /** proposer -> MintProposalData */

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
        require(!_isMintApprovable(msg.sender), "Mintable: proposal is approving" );

        delete mintProposals[msg.sender];
        //mint by a proposer for once only otherwise would be overwritten
        mintProposals[msg.sender].amount = amount;
        mintProposals[msg.sender].startTime = block.timestamp;
        emit MintProposed(msg.sender, amount);

        return true;
    }

    function approveMint(address proposer, bool approved, uint256 amount) public onlyApprover() returns(bool) {

        require( _isMintApprovable(proposer), "Mintable: proposal is not approvable" );
        require( mintProposals[proposer].amount == amount, "Mintable: amount mismatch" );
        require( !_accountExistIn(msg.sender, mintProposals[proposer].approvers),
            "Mintable: approver has already approved" );

        emit MintApproved(msg.sender, proposer, approved, amount); 

        if (approved) {
            mintProposals[proposer].approvers.push(msg.sender);
            if (mintProposals[proposer].approvers.length == APPROVER_COUNT) {
                _doMint(holder, amount);
                delete mintProposals[proposer];  
            }
        } else {
            delete mintProposals[proposer];           
        }

        return true;
    }

    function _doMint(address to, uint256 amount) internal virtual;


    function _isMintApprovable(address proposer) internal view returns(bool) {
        return mintProposals[proposer].amount > 0 
            && !_isProposalExpired(mintProposals[proposer].startTime);
    }
}

abstract contract Burnable is Governable {

    event BurnProposed(address indexed proposer, uint256 amount);
    event BurnApproved(address indexed approver, address indexed proposer, bool approved, uint256 amount);
    // event BurnEmitted(address indexed proposer, uint256 amount, address indexed emitter);

    struct BurnProposalData {
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => BurnProposalData) public burnProposals; /** proposer -> BurnProposalData */

    /**
    * @dev propose to burn
    * @param amount amount to burn
    * @return burn propose ID
    */
    function proposeBurn(uint256 amount) public onlyProposer() returns(bool) {
        require(amount > 0, "Burnable: zero amount not allowed" );
        require(_isBalanceEnough(address(this), amount), "Burnable: burn amount exceeds contract balance");
        require(!_isBurnApprovable(msg.sender), "Burnable: proposal is approving" );

        delete burnProposals[msg.sender];
        //burn by a proposer for once only otherwise would be overwritten
        burnProposals[msg.sender].amount = amount;
        burnProposals[msg.sender].startTime = block.timestamp;
        emit BurnProposed(msg.sender, amount);

        return true;
    }

    function approveBurn(address proposer, bool approved, uint256 amount) public onlyApprover() returns(bool) {

        require( _isBurnApprovable(proposer), "Burnable: proposal is not approvable" );
        require( burnProposals[proposer].amount == amount, "Burnable: amount mismatch" );
        require(_isBalanceEnough(address(this), amount), "Burnable: burn amount exceeds contract balance");
        require( !_accountExistIn(msg.sender, burnProposals[proposer].approvers),
            "Burnable: approver has already approved" );

        emit BurnApproved(msg.sender, proposer, approved, amount); 

        if (approved) {
            burnProposals[proposer].approvers.push(msg.sender);
            if (burnProposals[proposer].approvers.length == APPROVER_COUNT) {
                _doBurn(address(this), amount);
                delete burnProposals[proposer];  
            }
        } else {
            delete burnProposals[proposer];           
        }

        return true;
    }

    function _doBurn(address to, uint256 amount) internal virtual;


    function _isBurnApprovable(address proposer) internal view returns(bool) {
        return burnProposals[proposer].amount > 0 
            && !_isProposalExpired(burnProposals[proposer].startTime);
    }

}

abstract contract ForceTransferProposal is Governable {

    event ForceTransferProposed(address indexed proposer, address indexed from, address indexed to, uint256 amount);
    event ForceTransferApproved(address indexed approver, address indexed proposer, bool approved, uint256 amount);
    // event ForceTransferEmitted(address indexed proposer, uint256 amount, address indexed emitter);

    struct ForceTransferProposalData {
        address                     from;
        address                     to;
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => ForceTransferProposalData) public forceTransferProposals; /** proposer -> ForceTransferProposalData */

    /**
    * @dev propose to forceTransfer
    * @param amount amount to forceTransfer
    * @return forceTransfer propose ID
    */
    function proposeForceTransfer(address from, address to, uint256 amount) public onlyProposer() returns(bool) {
        require(amount > 0, "ForceTransferProposal: zero amount not allowed" );
        require(_isBalanceEnough(from, amount), "Burnable: transfer amount exceeds balance of from");
        require(!_isForceTransferApprovable(msg.sender), "ForceTransferProposal: proposal is approving" );

        delete forceTransferProposals[msg.sender];
        //forceTransfer by a proposer for once only otherwise would be overwritten
        forceTransferProposals[msg.sender].from = from;
        forceTransferProposals[msg.sender].to = to;
        forceTransferProposals[msg.sender].amount = amount;
        forceTransferProposals[msg.sender].startTime = block.timestamp;
        emit ForceTransferProposed(msg.sender, from, to, amount);

        return true;
    }

    function approveForceTransfer(address proposer, bool approved, address from, address to, uint256 amount) public onlyApprover() returns(bool) {

        ForceTransferProposalData memory proposal = forceTransferProposals[proposer];
        require( _isForceTransferApprovable(proposer), "ForceTransferProposal: proposal is not approvable" );
        require( proposal.from == from && proposal.to == to && proposal.amount == amount, 
            "ForceTransferProposal: amount mismatch" );
        require(_isBalanceEnough(from, amount), "Burnable: transfer amount exceeds balance of from");
        require( !_accountExistIn(msg.sender, proposal.approvers),
            "ForceTransferProposal: approver has already approved" );

        emit ForceTransferApproved(msg.sender, proposer, approved, amount); 

        bool needExec = false;
        if (approved) {
            forceTransferProposals[proposer].approvers.push(msg.sender);
            if (forceTransferProposals[proposer].approvers.length == APPROVER_COUNT) {
                needExec = true;
                delete forceTransferProposals[proposer];  
            }
        } else {
            delete forceTransferProposals[proposer];           
        }

        if (needExec)
            _doForceTransfer(proposal.from, proposal.to, amount);

        return true;
    }

    function _doForceTransfer(address from, address to, uint256 amount) internal virtual;


    function _isForceTransferApprovable(address proposer) internal view returns(bool) {
        return forceTransferProposals[proposer].from != address(0)
            && forceTransferProposals[proposer].to != address(0)
            && forceTransferProposals[proposer].amount > 0 
            && !_isProposalExpired(forceTransferProposals[proposer].startTime);
    }
}

/**
 * approved by owner or approvers
 */
abstract contract SetApproverProposal is Governable {

    event SetApproverProposed(address indexed proposer, uint256 index, address indexed newApprover);
    event SetApproverApproved(address indexed approver, address indexed proposer, uint256 index, address indexed newApprover);

    struct SetApproverProposalData {
        uint256                     index;
        address                     newApprover;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => SetApproverProposalData) public setApproverProposals; /** proposer -> SetApproverProposalData */

    /**
    * @dev propose to setApprover
    * @param index index of approver
    * @param newApprover new approver
    * @return setApprover propose ID
    */
    function proposeSetApprover(uint256 index, address newApprover) public onlyProposer() returns(bool) {
        require(index < APPROVER_COUNT, "SetApproverProposal: index invalid" );
        require(newApprover != address(0), "SetApproverProposal: new approver is zero address");
        require(!_isSetApproverApprovable(msg.sender), "SetApproverProposal: proposal is approving" );

        delete setApproverProposals[msg.sender];
        //setApprover by a proposer for once only otherwise would be overwritten
        setApproverProposals[msg.sender].index = index;
        setApproverProposals[msg.sender].newApprover = newApprover;
        setApproverProposals[msg.sender].startTime = block.timestamp;
        emit SetApproverProposed(msg.sender, index, newApprover);

        return true;
    }

    function approveSetApprover(address proposer, bool approved, uint256 index, address newApprover) 
        public onlyApproverAndOwner() returns(bool) {

        SetApproverProposalData memory proposal = setApproverProposals[proposer];
        require( _isSetApproverApprovable(proposer), "SetApproverProposal: proposal is not approvable" );
        require( proposal.index == index && proposal.newApprover == newApprover, 
            "SetApproverProposal: propose data mismatch" );
        require( !_accountExistIn(msg.sender, proposal.approvers),
            "SetApproverProposal: approver has already approved" );

        emit SetApproverApproved(msg.sender, proposer, index, newApprover); 

        bool needExec = false;
        if (approved) {
            setApproverProposals[proposer].approvers.push(msg.sender);
            if (setApproverProposals[proposer].approvers.length == APPROVER_COUNT) {
                needExec = true;
                delete setApproverProposals[proposer];  
            }
        } else {
            delete setApproverProposals[proposer];           
        }

        if (needExec)
            _setApprover(index, newApprover);

        return true;
    }

    function _isSetApproverApprovable(address proposer) internal view returns(bool) {
        return setApproverProposals[proposer].newApprover != address(0)
            && !_isProposalExpired(setApproverProposals[proposer].startTime);
    }
}

contract Cnyd is ERC20, ERC20Burnable, Pausable, Governable, 
    Mintable, Burnable, ForceTransferProposal, SetApproverProposal {


    uint8 private constant _decimals = 4;

    constructor(address[APPROVER_COUNT] memory _approvers) ERC20("cnyd", "CNYD") {
        setHolder(msg.sender);
        _setApprovers(_approvers);
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

    function _doBurn(address to, uint256 amount) internal override {
        _burn(to, amount);
    }

    function _doForceTransfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, amount); // ignore the paused and frozen strategy
    }

    function _isBalanceEnough(address account, uint256 amount) internal view override returns(bool) {
        return balanceOf(account) >= amount;
    }

   function _transfer(address sender, address recipient, uint256 amount) internal whenNotPaused override {
        super._transfer(sender, recipient, amount);
    }

}