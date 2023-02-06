// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
// access control lets us know more about the user that whether the user is a stakeholder or not by getting its address
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// helps in security purpose => don't let recursively call a function

contract DominionDAO is ReentrancyGuard,AccessControl{
  bytes32 private CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR");
  bytes32 private STAKEHOLDER_ROLE = keccak256("STAKEHOLDER");
  uint256  MIN_STAKEHOLDER_CONTRIBUTION = 1 ether;
  uint32  MIN_VOTE_DURATION = 2 minutes;
  uint256 totalProposals;
  uint256 public daoBalance;

  mapping(uint256 => ProposalStruct) private raisedProposals;
  mapping(address => uint256[]) private stakeholderVotes;
  mapping(uint256 => VotedStruct[]) private votedOn;
  mapping(address => uint256) private contributors;
  mapping(address => uint256) private stakeholders;

  struct ProposalStruct{
    uint256 id;
    uint256 amount;
    uint256 duration;
    uint256 upvotes;
    uint256 downvotes;
    string title;
    string description;
    bool passed;
    bool paid;
    address payable beneficiary;
    address proposer;
    address executor;
  }

  struct VotedStruct {
    address voter;
    uint256 timestamp;
    bool choosen;
  }

  event Action(
    address indexed initiator,
    bytes32 role,
    string message,
    address indexed beneficiary,
    uint256 amount
  );

  modifier stakeholderOnly(string memory message){
    require(hasRole(STAKEHOLDER_ROLE,msg.sender),message);
    _;
  }

  modifier contributorOnly(string memory message){
    require(hasRole(CONTRIBUTOR_ROLE,msg.sender),message);  // hasRole is coming from accessControl
    _;
  }

  function createProposal(
    string memory title,
    string memory description,
    address beneficiary,
    uint256 amount
  ) external stakeholderOnly("Proposal creation allowed for stakeholder only") {
    uint256 proposalId = totalProposals++;
    ProposalStruct storage proposal = raisedProposals[proposalId];

    proposal.id = proposalId;
    proposal.proposer = payable(msg.sender);
    proposal.title = title;
    proposal.description = description;
    proposal.beneficiary = payable(beneficiary);
    proposal.amount = amount;
    proposal.duration = block.timestamp + MIN_VOTE_DURATION;

    emit Action(
      msg.sender,
      CONTRIBUTOR_ROLE,
      "PROPOSAL RAISED",
      beneficiary,
      amount
    );
  }

  function performVote(uint256 proposalId, bool choosen) public stakeholderOnly("Unauthorized: stakeholders only"){
    ProposalStruct storage proposal = raisedProposals[proposalId];
    handleVoting(proposal);
    if(choosen) proposal.upvotes++;
    else proposal.downvotes++;

    stakeholderVotes[msg.sender].push(proposal.id);

    votedOn[proposal.id].push(
      VotedStruct(
        msg.sender,
        block.timestamp,
        choosen
      )
    );
    emit Action(
      msg.sender,
      STAKEHOLDER_ROLE,
      "PROPOSAL VOTE",
      proposal.beneficiary,
      proposal.amount
    );
  }

  function handleVoting(ProposalStruct storage proposal) private {
    if(proposal.passed || proposal.duration <= block.timestamp){
      proposal.passed = true;
      revert("Proposal duration expired");
    }
    uint256[] memory tempVotes = stakeholderVotes[msg.sender];
    for(uint256 votes = 0; votes < tempVotes.length; votes++){
      if(proposal.id == tempVotes[votes]){
      revert("Double voting not allowed");
      }
    }
  }

  function payBeneficiary(uint256 proposalId) public stakeholderOnly("Unauthorized: stakeholders only") nonReentrant(){
    ProposalStruct storage proposal = raisedProposals[proposalId];
    require(daoBalance >= proposal.amount,"insufficient balance");
    if(proposal.paid) revert("payment sent before");
    if(proposal.upvotes <= proposal.downvotes) revert("insufficient votes");

    proposal.paid = true;
    proposal.executor = msg.sender;
    daoBalance -= proposal.amount;

    payTo(proposal.beneficiary,proposal.amount);

    emit Action(msg.sender,STAKEHOLDER_ROLE,"PAYMENT TRANSFERED",proposal.beneficiary,proposal.amount);
  }

  function payTo(address to,uint256 amount) internal returns(bool){
    (bool success, ) = payable(to).call{value:amount}("");
    require(success,"Payment Failed");
    return true;
  }
 
  function contribute() payable public {
    require(msg.value> 0 ether, "Contributing zero is not allowed");
    if(!hasRole(STAKEHOLDER_ROLE, msg.sender)){
      uint256 totalContribution = contributors[msg.sender] + msg.value;

      if(totalContribution >= MIN_STAKEHOLDER_CONTRIBUTION){
        stakeholders[msg.sender] = totalContribution;
        _setupRole(STAKEHOLDER_ROLE,msg.sender);
      }
        contributors[msg.sender] += msg.value;
        _setupRole(CONTRIBUTOR_ROLE,msg.sender);
    }else{
        contributors[msg.sender] += msg.value;
        stakeholders[msg.sender] += msg.value;
    }

    daoBalance += msg.value;
    emit Action(
      msg.sender,
      STAKEHOLDER_ROLE,
      "CONTRIBUTION RECEIVED",
      address(this),
      msg.value
    );

  }

  function getProposals() public view returns(ProposalStruct[] memory props){
    props = new ProposalStruct[](totalProposals);
    for(uint256 i = 0; i< totalProposals; i++){
      props[i] = raisedProposals[i];
    }
  }

  function getProposal(uint256 proposalId) public view returns (ProposalStruct memory) {
    return raisedProposals[proposalId];
  } 

  function getVotesOf(uint256 proposalId) public view returns(VotedStruct[] memory){
    return votedOn[proposalId];
  }
  
  function getStakeholderVotes() public view stakeholderOnly("Unauthorized: stakeholders only") returns(uint256[] memory){
    return stakeholderVotes[msg.sender];
  }

  function getStakeholderBalance() public view stakeholderOnly("Unauthorized: stakeholders only") returns(uint256){
    return stakeholders[msg.sender];
  }

  function isStakeholder() public view returns (bool){
    return stakeholders[msg.sender]>0;
  }

  function getContributorBalance() public view contributorOnly("Denied: user is not a contributor") returns(uint256){
    return contributors[msg.sender];
  }

  function isContributor() public view returns (bool){
    return contributors[msg.sender]>0;
  }

  function getBalance() public view returns(uint256){
    return contributors[msg.sender];
  }

  

}
