pragma solidity ^0.4.24;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";
import "./ReentrancyGuard.sol";

/**
 * @title AlkemiMessaging - Authorized players to add/remove messages
 * @dev Implementation of AlkemiMessaging contract.
 *  Requirementy: Create a smart contract that facilitates the storage of messages on-chain. The smart contract owner should be able to authorize new addresses to store messages on the chain.
 *    Each newly added user will have a certain credit amount that they are assigned on add. From there each time they add or remove a message they should lose a credit.
 *   Users who are authorized should be able to purchase extra credits by sending funds to the smart contract. If a user is done they should be able to withdrawal any remaining credit funds.
*/
contract AlkemiMessaging is Pausable, ReentrancyGuard {
  using SafeMath for uint256;
  uint8 public constant COST = 1;  // credit cost to add/remove a message
  uint256 public CREDITPRICE = 3;  //One Wei can buy this number of Credit tokens
  uint256 public CREDITSONAUTHORIZED = 10;     //Assigned credits tokens on authorized by the owner
         
  address public owner;   // Owner of this contract
 
  IERC20 private creditTokens;  // The Alkemi ERC Token(Credit)

   //Credit Token Global Status
   struct CreditStatus {
       uint256 cap;  //Total credit token supply
       uint256 authorizedPlayers;  //Total authorized players
       uint256 assignedCreditTokens; //Total assigned credit tokens on authorized new player
       uint256 remainingCreditTokens; //Total remaining credits (It is total supply credits by default)
       uint256 arisedCredits; //Total paid credits when player try to add/remove messages
       uint256 arisedEth;      //Total Arised Ether in Wei (Ether collected when player buy credits)
   }
   CreditStatus creditStatus; 

   //Message Info
    struct MessageInfo {
        uint CreatDate;    //Message creation date/time in UNIX datetime format
        address Creator;   //Message owner(creator). only message creator can remove this message
        string MessageContent;  //message content
        bool isRemoved;   //Message remove flag (0 - Active 1 -Removed)
    }
    mapping(uint => MessageInfo) messageinfo;  
    
    /* PLAYER */
    struct Player {
        uint creditBalance;  //Player credit token balancer
        uint ethBalance;     //Player ether in Wei balance
        uint8 isAuthorized;  //Is authorized (0 - not authorized 1 - Authorized?
    }
    mapping(address => Player) player; 
   
   uint256 public messageCount;  //Message count. this number increate 1 when a new message is added
   
   event evt_MessageAction(address indexed by,uint messageID, string action);
   event evt_AuthorizedNewPlayer(address indexed by,address newplayer);
   event evt_TokenAction(address indexed by,uint256 amount, string action);
   
   // only human is allowed to call this contract. this modifier block all other contracts to avoid any attack from other contracts 
   modifier isHuman() {
       require((bytes32(msg.sender)) == (bytes32(tx.origin)));
       _;
   }
   
   constructor(IERC20 token) public {
        require(address(token) != address(0));  //Make sure credit token address is provided
        owner = msg.sender;   //Current player will be owner by default
        creditStatus.cap =  token.totalSupply();   //Total credit tokens supply
        creditStatus.assignedCreditTokens =0;   //the number of credit tokens has been assigned.
        creditStatus.remainingCreditTokens  =creditStatus.cap ;  //number of tokens remaining 
        creditStatus.arisedEth = 0; // total arised Ether in Wei
        creditTokens = token;     //Credit token contract address
   }
   
  //Authorized a new player (Oener only / Not allow Reentrancy / block contract call / Contract is not paused)
  function authorizeNewPlayer(address _newplayer) external onlyAdministrators nonReentrant isHuman whenNotPaused payable {
        require(_newplayer != address(0),"Please specify new player address");
        require(player[_newplayer].isAuthorized == 0,"This player already was authorized");
        require(creditStatus.remainingCreditTokens > CREDITSONAUTHORIZED ,"Run out of credits, Please contact owner");
        require(player[owner].creditBalance >= CREDITSONAUTHORIZED , "Owner don't have enough balance");  
        
         //Transfer credit tokens from owner account to new player account at this contract
         player[owner].creditBalance = player[owner].creditBalance.sub(CREDITSONAUTHORIZED);
         player[_newplayer].creditBalance = player[_newplayer].creditBalance.add(CREDITSONAUTHORIZED);
         //Update global credit status
         creditStatus.remainingCreditTokens = creditStatus.remainingCreditTokens.sub(CREDITSONAUTHORIZED);
         creditStatus.assignedCreditTokens = creditStatus.assignedCreditTokens.add(CREDITSONAUTHORIZED);
         creditStatus.authorizedPlayers++;
         
         player[_newplayer].isAuthorized = 1;   //Assign 1 to authorized new player.
        
        emit evt_AuthorizedNewPlayer(msg.sender,_newplayer);
  }

 /* ========Messaging facilitates \ Create new Message (Not allow Reentrancy / block contract call / Contract is not paused)============= */      
 function createMessage(string _messagecontent) external whenNotPaused isHuman nonReentrant returns (uint256) {
    require(player[msg.sender].isAuthorized == 1,"This player was not authorized yet");
    require(player[msg.sender].creditBalance >= COST  ,"You don't have enough credit tokens to add a new message");   

    messageCount++;  

    player[msg.sender].creditBalance = player[msg.sender].creditBalance.sub(COST);   //Pay the credit before adding the message
  
    creditStatus.arisedCredits = creditStatus.arisedCredits.add(COST);  //Update global credit status
    
    //Record added message info  
    messageinfo[messageCount].CreatDate = now;
    messageinfo[messageCount].Creator = msg.sender;
    messageinfo[messageCount].MessageContent =_messagecontent; 

    emit evt_MessageAction(msg.sender, messageCount, "Add");
    return messageCount;   //return added message ID
 }
 
 /* ========Messaging facilitates \ Remove an existing Message(Not allow Reentrancy / block contract call / Contract is not paused)=========================== */      
 function removeMessage(uint256  _messageID) external whenNotPaused isHuman nonReentrant returns (bool) {
    require(_messageID <= messageCount,"Invalid Message ID");
    require(player[msg.sender].isAuthorized == 1,"This player was not authorized yet");
    require(messageinfo[_messageID].isRemoved == false,"This message already removed");
    require(player[msg.sender].creditBalance >= COST  ,"You don't have no enough credit tokens to remove a new message");  
    require(messageinfo[messageCount].Creator == msg.sender ,"Only message creator can remove this message");

    player[msg.sender].creditBalance = player[msg.sender].creditBalance.sub(COST);     //Pay the credit before adding the message
  
    creditStatus.arisedCredits = creditStatus.arisedCredits.add(COST); //Update global credit status
      
    messageinfo[messageCount].isRemoved = true;   //Leave message remove flag

    emit evt_MessageAction(msg.sender, _messageID, "Remove");
    return true;
 }
 
 /* ========Credit tokens Operation \ Deposit credit token from ERC20 contract to this contract=========================== */
 function depositCredits(uint _amount) external whenNotPaused nonReentrant payable returns (bool){
        require(creditTokens.transferFrom(msg.sender, address(this), _amount) == true); //Transfer credit tokens from current player account at ERC20 Token contract to thos contract
        player[msg.sender].creditBalance = player[msg.sender].creditBalance.add(_amount);  //Record the transfered amounts to current player address at this contract
        emit  evt_TokenAction(msg.sender,_amount, "Deposit");
        return true;
 }
 
 /* ========Credit tokens Operation \ Withdraw credit token from current contract to ERC20 contract=========================== */
 function withdrawCredits(uint _amount) external whenNotPaused nonReentrant payable returns (bool){
        require(player[msg.sender].creditBalance >= _amount,"You don't have enough credits");
        require(creditTokens.transfer(msg.sender, _amount) == true);  //Transfer credit tokens from current contract to this player account at ERC20 token contract
        
        player[msg.sender].creditBalance = player[msg.sender].creditBalance.sub(_amount);  //remove transfered amount from current player account at current contract
        
        emit  evt_TokenAction(msg.sender,_amount, "Withdraw");
 }
 
  /* ========Credit tokens Operation \ Buy credit tokens using Ether (Wei)=========================== */
  function buyCredits() external nonReentrant isHuman whenNotPaused payable {
        require(player[msg.sender].isAuthorized == 1,"This player was not authorized yet");
        require(msg.value > 0,"Ether amount is zero");
        require(creditStatus.remainingCreditTokens > 0 ,"All credits sold out");


        uint256 weiAmount = msg.value;   //Ether in Wei amount
        uint256 credits = weiAmount.mul(CREDITPRICE); // Calculate credit tokens to sell based on base price

        require(credits <= creditStatus.remainingCreditTokens,"No enough remaining credit tokens");

        owner.transfer(weiAmount);    // Send Eth from buyer to contract owner before any status changes      

        //Update Credit global status 
        creditStatus.arisedEth = creditStatus.arisedEth.add(weiAmount); // 
        creditStatus.remainingCreditTokens = creditStatus.remainingCreditTokens.sub(credits);

        require(creditTokens.transferFrom(owner, msg.sender, credits) == true);         //Process token purchase in the ERC20 Tokeb contract
     
        emit  evt_TokenAction(msg.sender,credits, "Buy");
  }      

  function getPlayerInfo(address _player) external view returns (uint,uint,uint8) {
    return (player[_player].creditBalance,player[_player].ethBalance,player[_player].isAuthorized);
  }
  
   function getCreditStatus() external view returns (uint256,uint256,uint256,uint256,uint256,uint256) {
    return (creditStatus.cap,creditStatus.authorizedPlayers,creditStatus.assignedCreditTokens,creditStatus.remainingCreditTokens,creditStatus.arisedCredits,creditStatus.arisedEth);
  } 

   function getMessageInfo(uint _messageid) external view returns (uint,address,string,bool) {
    return (messageinfo[_messageid].CreatDate,messageinfo[_messageid].Creator,messageinfo[_messageid].MessageContent,messageinfo[_messageid].isRemoved);
  } 
  

  function kill() external onlyAdministrators { //onlyOwner can kill this contract
    selfdestruct(owner);  // `owner` is the owners address
  }

  function () public payable {
        // nothing to do
  }
}
