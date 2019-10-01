pragma solidity ^0.4.24;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

/**
 * @title ALAKEMI ERC20 token - This is the ERC20 credit token used by players to add/remove messages.
 * @dev Implementation of the ERC20 standard token.
 * Requirementy: Create a smart contract that facilitates the storage of messages on-chain. The smart contract owner should be able to authorize new addresses to store messages on the chain.
 *   Each newly added user will have a certain credit amount that they are assigned on add. From there each time they add or remove a message they should lose a credit.
 *   Users who are authorized should be able to purchase extra credits by sending funds to the smart contract. If a user is done they should be able to withdrawal any remaining credit funds.
*/
contract ALAKEMI is IERC20, Pausable {

  string public constant symbol = "ALAKEMI";
  //   uint8 public constant decimals = 6;
  uint256 initialSupply = 1000000000;   //Total Supply 1 billion
  string public constant name = "ALAKEMI";

  using SafeMath for uint256;

  // Owner of this contract
  address public owner;

  //Balance per address
  mapping (address => uint256) private _balances;

  //Allowance amount 
  mapping (address => mapping (address => uint256)) private _allowed;

  //Total supply
  uint256 private _totalSupply;
  
  constructor() public {
        owner = msg.sender;
        _totalSupply = initialSupply;
        _balances[msg.sender] = _totalSupply;      // Give the creator all initial tokens
  }

  /**
  * @dev Total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }


  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256) {
    return _balances[_owner];
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner,address spender) public view returns (uint256) {
    return _allowed[_owner][spender];
  }

  /**
  * @dev Transfer token for a specified address
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
    require(spender != address(0));

    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param from address The address which you want to send tokens from
   * @param to address The address which you want to transfer to
   * @param value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address from,address to,uint256 value) public whenNotPaused returns (bool) {
    require(value <= _allowed[from][msg.sender]);

    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }


  /**
  * @dev Transfer token for a specified addresses
  * @param from The address to transfer from.
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function _transfer(address from, address to, uint256 value) internal whenNotPaused {
    require(value <= _balances[from]);
    require(to != address(0));

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }

}
