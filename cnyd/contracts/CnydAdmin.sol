// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICnydToken.sol";
import "./Ownable.sol";

abstract contract Governable is Ownable {

    uint256 public constant APPROVER_COUNT = 3;
    uint256 public constant APPROVED_THRESHOLD = 3;

    enum ApprovedStatus { NONE, STARTED, APPROVED, OPPOSED }

    event ApproverChanged(uint256 idndex, address indexed newAccount, address indexed oldAccount);
    event ProposerChanged(address indexed account, bool enabled);


    uint256 public proposalDuration = 6 * 3600; // in second

    address[APPROVER_COUNT] public approvers;

    mapping (address => bool) public proposers;

    modifier onlyInit() virtual {
        require(approvers[0] != address(0), "Token contract is not init");
        _;
    }

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
        require(_isApprover(msg.sender) || msg.sender == owner(), "Governable: caller is not an approver or owner");
        _;
    }

    modifier onlyPositiveAmount(uint256 amount) {
        require(amount > 0, "Governable: zero amount not allowed" );
        _;
    }

    modifier validApproverIndex(uint256 index) {
        require(index < APPROVER_COUNT, "Governable: approver index invalid" );
        _;
    }

    function isInit() public view virtual returns(bool) {
        return approvers[0] != address(0);
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

    function _setApprover(uint256 id, address account) internal {
        require(id < APPROVER_COUNT, "Governable: approver id is out of range");
        require(account != approvers[id], "Governable: the account is same as the old one");
        require(!_isApprover(account), "Governable: the account is already an approver");

        address oldAccount = approvers[id];
        approvers[id] = account;
        emit ApproverChanged(id, account, oldAccount);
    }

    function setProposer(address account, bool enabled) public onlyOwner() onlyInit() {
        require(proposers[account] != enabled, "Governable: no change of enabled");
        proposers[account] = enabled;
        emit ProposerChanged(account, enabled);
    }

    function setProposalDuration(uint duration) public onlyOwner() {
        proposalDuration = duration;
    }

    function _accountExistIn(address account, address[] memory accounts) internal pure returns(bool) {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (account == accounts[i]) return true;
        }
        return false;
    }

    function _isProposalExpired(uint startTime) internal view returns(bool) {   
        return block.timestamp > startTime + proposalDuration;    
    }

    function _isApprovable(uint startTime) internal view returns(bool) {
        return startTime > 0 && !_isProposalExpired(startTime);
    }

    function _isBurnBalanceEnough(uint256 amount) internal view virtual returns(bool);
}

abstract contract MintProposal is Governable {

    event MintProposed(address indexed proposer, address indexed to, uint256 amount);
    event MintApproved(address indexed approver, address indexed proposer, bool approved, address indexed to, uint256 amount);
    event HolderChanged(address indexed newHolder, address indexed oldHolder);

    struct MintProposalData {
        address                     to;
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => MintProposalData) private mintProposals; /** proposer -> MintProposalData */

    function getMintProposal(address proposer) public view returns(MintProposalData memory) {
        return mintProposals[proposer];
    }

    /**
    * @dev propose to mint
    * @param amount amount to mint
    * @return mint propose ID
    */
    function proposeMint(address to, uint256 amount) public 
        onlyInit()
        onlyProposer() 
        onlyNonZeroAccount(to)
        onlyPositiveAmount(amount) 
        returns(bool) 
    {
        require(!_isApprovable(mintProposals[msg.sender].startTime), "MintProposal: proposal is approving" );

        delete mintProposals[msg.sender];
        //mint by a proposer for once only otherwise would be overwritten
        mintProposals[msg.sender].to = to;
        mintProposals[msg.sender].amount = amount;
        mintProposals[msg.sender].startTime = block.timestamp;
        emit MintProposed(msg.sender, to, amount);

        return true;
    }

    function approveMint(address proposer, bool approved, address to, uint256 amount) public onlyInit() onlyApprover() returns(bool) {
        MintProposalData memory proposal = mintProposals[proposer];
        require( _isApprovable(proposal.startTime), "MintProposal: proposal is not approvable" );
        require( proposal.to == to && proposal.amount == amount, "MintProposal: proposal data mismatch" );
        require( !_accountExistIn(msg.sender, proposal.approvers), "MintProposal: approver has already approved" );

        bool needExec = false;
        if (approved) {
            mintProposals[proposer].approvers.push(msg.sender);
            if (mintProposals[proposer].approvers.length == APPROVER_COUNT) {
                needExec = true;
                delete mintProposals[proposer];  
            }
        } else {
            delete mintProposals[proposer];           
        }
        emit MintApproved(msg.sender, proposer, approved, to, amount); 

        if (needExec) 
            _doMint(to, amount);

        return true;
    }

    function _doMint(address to, uint256 amount) internal virtual;
}

abstract contract BurnProposal is Governable {

    event BurnProposed(address indexed proposer, uint256 amount);
    event BurnApproved(address indexed approver, address indexed proposer, bool approved, uint256 amount);

    struct BurnProposalData {
        uint256                     amount;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => BurnProposalData) private _burnProposals; /** proposer -> BurnProposalData */

    function getBurnProposal(address proposer) public view returns(BurnProposalData memory) {
        return _burnProposals[proposer];
    }
    /**
    * @dev propose to burn
    * @param amount amount to burn
    * @return burn propose ID
    */
    function proposeBurn(uint256 amount) public 
        onlyInit()
        onlyProposer()
        onlyPositiveAmount(amount) 
        returns(bool) 
    {
        require(_isBurnBalanceEnough(amount), "BurnProposal: burn amount exceeds contract balance");
        require( !_isApprovable(_burnProposals[msg.sender].startTime), "BurnProposal: proposal is approving" );

        delete _burnProposals[msg.sender]; // clear proposal data
        //burn by a proposer for once only otherwise would be overwritten
        _burnProposals[msg.sender].amount = amount;
        _burnProposals[msg.sender].startTime = block.timestamp;
        emit BurnProposed(msg.sender, amount);

        return true;
    }

    function approveBurn(address proposer, bool approved, uint256 amount) public onlyInit() onlyApprover() returns(bool) {
        BurnProposalData memory proposal = _burnProposals[proposer];
        require( _isApprovable(proposal.startTime), "BurnProposal: proposal is not approvable" );
        require( proposal.amount == amount, "BurnProposal: proposal data mismatch" );
        require(_isBurnBalanceEnough(amount), "BurnProposal: burn amount exceeds contract balance");
        require( !_accountExistIn(msg.sender, proposal.approvers),
            "BurnProposal: approver has already approved" );

        bool needExec = false;
        if (approved) {
            _burnProposals[proposer].approvers.push(msg.sender);
            if (_burnProposals[proposer].approvers.length == APPROVER_COUNT) {
                needExec = true;
                delete _burnProposals[proposer];  
            }
        } else {
            delete _burnProposals[proposer];           
        }
        emit BurnApproved(msg.sender, proposer, approved, amount); 

        if (needExec)
            _doBurn(amount);
        return true;
    }

    function _doBurn(uint256 amount) internal virtual;
}

/**
 * approved by owner or approvers
 */
abstract contract ApproverProposal is Governable {

    event ApproverProposed(address indexed proposer, uint256 index, address indexed newApprover);
    event ApproverApproved(address indexed approver, address indexed proposer, uint256 index, address indexed newApprover);

    struct ApproverProposalData {
        uint256                     index;
        address                     newApprover;
        uint                        startTime;
        address[]                   approvers;
    }

    mapping (address => ApproverProposalData) public _approverProposals; /** proposer -> ApproverProposalData */

    function getApproverProposal(address proposer) public view returns(ApproverProposalData memory) {
        return _approverProposals[proposer];
    }

    /**
    * @dev propose to set approver
    * @param index index of approver
    * @param newApprover new approver
    * @return approver propose ID
    */
    function proposeApprover(uint256 index, address newApprover) public
        onlyInit()
        onlyProposer() 
        validApproverIndex(index)
        onlyNonZeroAccount(newApprover)
        returns(bool) 
    {
        require(!_isApprovable(_approverProposals[msg.sender].startTime), "ApproverProposal: proposal is approving" );

        delete _approverProposals[msg.sender]; // clear proposal data
        //approver by a proposer for once only otherwise would be overwritten
        _approverProposals[msg.sender].index = index;
        _approverProposals[msg.sender].newApprover = newApprover;
        _approverProposals[msg.sender].startTime = block.timestamp;
        emit ApproverProposed(msg.sender, index, newApprover);

        return true;
    }


    /**
     * approver can not unapprove
     */
    function approveApprover(address proposer, uint256 index, address newApprover) public 
        onlyInit()
        onlyApproverAndOwner() 
        returns(bool) 
    {

        ApproverProposalData memory proposal = _approverProposals[proposer];
        require( _isApprovable(proposal.startTime), "ApproverProposal: proposal is not approvable" );
        require( proposal.index == index && proposal.newApprover == newApprover, 
            "ApproverProposal: propose data mismatch" );
        require( !_accountExistIn(msg.sender, proposal.approvers),
            "ApproverProposal: approver has already approved" );

        bool needExec = false;
        _approverProposals[proposer].approvers.push(msg.sender);
        if (_approverProposals[proposer].approvers.length == APPROVER_COUNT) {
            needExec = true;
            delete _approverProposals[proposer];  
        }
        emit ApproverApproved(msg.sender, proposer, index, newApprover); 

        if (needExec)
            _setApprover(index, newApprover);

        return true;
    }
}


contract CnydAdmin is Ownable, Governable, MintProposal, BurnProposal, ApproverProposal {

    address public token;

    modifier onlyInit() override {
        require(token != address(0), 
            "Token contract is not init");
        _;
    }

    function isInit() public view override returns(bool) {
        return token != address(0);
    }

    function init(address _token, address[APPROVER_COUNT] memory _approvers) public onlyOwner onlyNonZeroAccount(_token) { 
        require(token == address(0), "Token contract has been initialized");
        token = _token;
        _setApprovers(_approvers);
        
        require(IOwnable(_token).owner() != address(this), "This contract has been the owner of Token contract");
        require(IOwnable(_token).proposedOwner() == address(this), "This contract is not the proposed owner of Token contract");
        takeTokenOwnership();
        setTokenAdmin(address(this));
    }

    function pause() public onlyOwner onlyInit() {
        ICnydToken(token).pause();
    }

    function unpause() public onlyOwner onlyInit() {
        ICnydToken(token).unpause();
    }

    function forceTransfer(address from, address to, uint256 amount) public onlyOwner onlyInit() {
        ICnydToken(token).forceTransfer(from, to, amount);
    }

    function _doMint(address to, uint256 amount) internal override onlyInit() {
        ICnydToken(token).mint(to, amount);
    }

    function _doBurn(uint256 amount) internal override {
        ICnydToken(token).burn(amount);
    }

    function _isBurnBalanceEnough(uint256 amount) internal view override returns(bool) {
        return IERC20(token).balanceOf(token) >= amount;
    }

    function proposeTokenOwner(address newOwner) public onlyOwner onlyInit() {
        IOwnable(token).proposeOwner(newOwner);
    }

    function takeTokenOwnership() public onlyOwner onlyInit() {
        IOwnable(token).takeOwnership();
    }

    function setTokenAdmin(address newAdmin) public onlyOwner onlyInit() { 
        IAdministrable(token).setAdmin(newAdmin);
    }

    function setAdminFeeRatio(uint256 ratio) public onlyOwner onlyInit() {
        IAdminFee(token).setAdminFeeRatio(ratio);
    }

    function setFeeRecipient(address recipient) public onlyOwner onlyInit() {
        IAdminFee(token).setFeeRecipient(recipient);
    }

    function addFeeWhitelist(address[] memory accounts) public onlyOwner onlyInit() {
        IAdminFee(token).addFeeWhitelist(accounts);
    }

    function delFeeWhitelist(address[] memory accounts) public onlyOwner onlyInit() {
        IAdminFee(token).delFeeWhitelist(accounts);
    }
}