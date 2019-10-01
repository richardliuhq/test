pragma solidity ^0.4.24;

import "./Roles.sol";

contract PauserRole {
  using Roles for Roles.Role;

  event AdministratorAdded(uint datetime,address by,address indexed owner);
  event AdministratorRemoved(uint datetime,address by,address indexed account);

  Roles.Role private pausers;

  constructor() internal {
    _addPauser(msg.sender);
  }

  modifier onlyPauser() {
    require(isPauser(msg.sender));
    _;
  }

  modifier onlyAdministrators() {
    require(isPauser(msg.sender));
    _;
  }
  
  function isPauser(address account) public view returns (bool) {
    return pausers.has(account);
  }

  function addPauser(address account) public onlyPauser {
    _addPauser(account);
  }

  function renouncePauser() public {
    _removePauser(msg.sender);
  }

  function _addPauser(address account) internal {
    pausers.add(account);
    emit AdministratorAdded(now,msg.sender,account);
    /*emit PauserAdded(account);*/
  }

  function _removePauser(address account) internal {
    pausers.remove(account);
    /*emit PauserRemoved(account);*/
    emit AdministratorRemoved(now,msg.sender,account);
    
  }
}
