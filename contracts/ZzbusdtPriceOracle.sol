pragma solidity >=0.4.22 <0.9.0;

import "./BeanDiggingInterface.sol";

contract ZzbusdtPriceOracle {
  uint private randNonce = 0;
  uint private modulus = 1000000;
  address private _owner;

  mapping(uint256=>bool) pendingRequests;
  event GetLatestZzbusdtPriceEvent(address callerAddress, uint id);
  event SetLatestZzbusdtPriceEvent(uint256 zzbusdtPrice, address callerAddress);
  function getLatestZzbusdtPrice() public returns (uint256) {
    randNonce++;
    uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % modulus;
    pendingRequests[id] = true;
    emit GetLatestZzbusdtPriceEvent(msg.sender, id);
    return id;
  }

  function setLatestZzbusdtPrice(uint256 _zzbusdtPrice, address _callerAddress, uint256 _id) public onlyOwner {
    require(pendingRequests[_id], "This request is not in my pending list.");
    delete pendingRequests[_id];
    BeanDiggingInterface callerContractInstance;
    callerContractInstance = BeanDiggingInterface(_callerAddress);
    callerContractInstance.oracleCallback(_zzbusdtPrice, _id);
    emit SetLatestZzbusdtPriceEvent(_zzbusdtPrice, _callerAddress);
  }

  function owner() public view virtual returns (address) {
    return _owner;
  }

  function transferOwnership(address newOwner) public virtual onlyOwner {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      _owner = newOwner;
  }

  modifier onlyOwner() {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
    _;
  }
}


