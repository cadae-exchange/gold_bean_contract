pragma solidity >=0.4.22 <0.9.0;

import "./BeanDiggingInterface.sol";

contract ZzbusdtPriceOracle {
  uint private randNonce = 0;
  uint private modulus = 1000000;
  address private _owner;
  SetZzbusdtPriceRecord[] private totalSetZzbusdtPriceRecords;      // 全部爆块奖励发放记录列表

  mapping(uint256=>bool) pendingRequests;
  event GetLatestZzbusdtPriceEvent(address callerAddress, uint id);
  event SetLatestZzbusdtPriceEvent(uint256 zzbusdtPrice, uint256 createdDate, address callerAddress);

  constructor() public {
    _owner = msg.sender;
  }

  // 更改ZZB价格记录
  struct SetZzbusdtPriceRecord {
    uint zzbusdtPrice;      // 价格
    uint createdDate;       // 创建日期
  }

  function getLatestZzbusdtPrice() public returns (uint256) {
    randNonce++;
    uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % modulus;
    pendingRequests[id] = true;
    emit GetLatestZzbusdtPriceEvent(msg.sender, id);
    return id;
  }

  // 获取全部设置ZZB价格的记录
  function getTotalSetZzbusdtPriceRecords() view public returns(SetZzbusdtPriceRecord[] memory) {
    return totalSetZzbusdtPriceRecords;
  }

  function setLatestZzbusdtPrice(uint256 _zzbusdtPrice, address _callerAddress, uint256 _id) public onlyOwner {
    require(pendingRequests[_id], "This request is not in my pending list.");
    delete pendingRequests[_id];
    BeanDiggingInterface callerContractInstance;
    callerContractInstance = BeanDiggingInterface(_callerAddress);
    callerContractInstance.oracleCallback(_zzbusdtPrice, _id);
    uint256 createdDate = block.timestamp;
    totalSetZzbusdtPriceRecords.push(SetZzbusdtPriceRecord(_zzbusdtPrice, createdDate));
    emit SetLatestZzbusdtPriceEvent(_zzbusdtPrice, createdDate, _callerAddress);
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


