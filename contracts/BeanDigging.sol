pragma solidity >=0.4.22 <0.9.0;

import "./token/ERC20/IERC20.sol";
import "./token/ERC20/ERC20.sol";
import "./utils/math/SafeMath.sol";
import "./GBToken.sol";
import "./ZzbusdtPriceOracleInterface.sol";

contract BeanDigging {
  /*
     第一阶段: 200wGB   每次爆块50个    爆块几率40% 总共爆块40000次 总共活动10万次
     第二阶段: 100wGB   每次爆块25个    爆块几率40% 总共爆块40000次 总共活动10万次
     第三阶段: 50wGB    每次爆块12.5个  爆块几率40% 总共爆块40000次 总共活动10万次
     第四阶段: 25wGB    每次爆块6.25个  爆块几率40% 总共爆块40000次 总共活动10万次
     第五阶段: 12.5wGB  每次爆块3.125个 爆块几率40% 总共爆块40000次 总共活动10万次
     第六阶段: .....
  */

  using SafeMath for uint;

  ZzbusdtPriceOracleInterface private oracleInstance;
  address private oracleAddress;

  uint constant private WINNING_RATE = 40;              // 中签几率40%
  uint constant private BOOM_BONUS_RATE = 80;           // 爆块奖励比率
  uint constant private HOLDING_BONUS_RATE = 15;        // 持有矿机奖励比率
  uint constant private COMMON_DENOMINATOR = 100;       // 通用分母
  uint constant private CNY_PRICE = 5000;               // CNY价值
  uint constant private MIN_BONUS = 10000000000;        // 最小奖励 0.00000001
  uint constant private TO_WEI = 1000000000000000000;   // 1e18

  uint private TOTAL = _toWei(400);                 // 初始奖励400WGB
  uint private BONUS = _toWei(50);                      // 初始爆块奖励50GB
  uint private ROUNDS = TOTAL.div(BONUS).div(2);        // 每阶段需要爆块的次数
  uint private PARTICIPATION_NUMBER_OF_EVERY_SECTION = ROUNDS.mul(COMMON_DENOMINATOR).div(WINNING_RATE);  // 每个阶段可以参与活动的次数

  uint private miningPoolAmount = TOTAL;                // 合约矿池数量400w
  uint private preMiningAmount = _toWei(100);           // 预挖数量100w

  uint private totalRemaining = TOTAL;                  // 当前剩余奖励   origin: 400 GB
  uint private alreadyReleasedBonus = 0;                // 已经释放的奖励 origin: 0 GB
  uint private boomNumber = 0;                          // 爆块的次数
  uint private boomTriggerNumber = 0;                   // 当前阶段触发爆块事件次数(爆块次数的1/2) 触发一次爆块2次
  bool private isEnd = false;                           // 是否活动已经结束
  uint private outOfDateMachineCount = 0;               // 过期的挖豆机个数

  uint private currentSection = 1;                    // 当前阶段数
  uint private currentSectionBonus = _rounding(BONUS.div(( 2 ** (currentSection.sub(1)))));  // 初始奖励 50 GB
  uint private currentSectionTotalBonus = _rounding(totalRemaining.div(2));                     // 当前阶段的奖励
  uint private currentSectionReleasedBonus = 0;       // 当前阶段已经释放的奖励
  uint private currentSectionParticipationNumber = 0; // 当前阶段已经参加的次数
  uint private currentSectionBoomNumber = 0;          // 当前阶段爆块次数

  IERC20 private bonusToken;    // GB token  (爆块获得奖励)
  ERC20  private purchaseToken; // ZZB token (购买矿机消耗)
  address private publisher;    // 发布人

  Member[] private totalMemberRecords;                                         // 全部用户列表
  mapping (address => Member) private membersInfo;                             // 全部用户mapping

  BeanDiggingMachine[] private totalMachines;                                  // 全部挖豆机列表
  //mapping (address => BeanDiggingMachine[]) private memberMachinesInfo;        // 用户矿机持有列表

  BoomBonusRecord[] private totalBoomBonusRecords;                             // 全部爆块奖励发放记录列表
  //mapping (address => BoomBonusRecord[]) private memberBoomBonusInfo;          // 指定用户爆块奖励发放记录

  HoldingBonusRecord[] private totalHoldingBonusRecords;                       // 全部持有矿机分红记录列表
  //mapping (uint => HoldingBonusRecord[]) private mapHoldingBonusRecords;       // 全部持有矿机分红记录列表(按照阶段)
  //mapping (address => HoldingBonusRecord[]) private memberHoldingBonusInfo;    // 指定用户持有矿机分红记录

  DestroyedBonusRecord[] private totalDestroyedBonusRecords;                   // 全部销毁奖励记录列表

  UnhandledHoldingBonusRecord[] private totalUnhandledHoldingBonusRecords;     // 全部未完成发放持矿机奖励

  mapping(uint256=>bool) myRequests;      // oracle  调用请求
  uint private zzbusdtPrice = _toWei(1);  // zzbusdt 价格(默认是0) TODO

  // 事件
  event PurchaseMachineSuccessEvent(uint256 machineId, uint256 cost, uint256 createdDate, uint256 expirationDate);
  event HandleHoldingBonusSuccessEvent();
  event PriceUpdatedEvent(uint256 zzbusdtPrice, uint256 id);
  event ReceivedNewRequestIdEvent(uint256 id);
  event TestEvent(uint256 a, uint256 b);

  constructor(address _purchaseTokenAddress, address _oracleAddress) public {
    bonusToken = new GBToken(msg.sender, miningPoolAmount, preMiningAmount);                // 发行GB合约
    purchaseToken = ERC20(_purchaseTokenAddress);         // 初始化ZZB合约
    publisher = msg.sender;
    oracleAddress = _oracleAddress;
    oracleInstance = ZzbusdtPriceOracleInterface(_oracleAddress); // 初始化Oracle
  }

  // 80% 爆块奖励发放记录
  struct BoomBonusRecord {
    uint id;                // ID
    uint machineId;         // 挖豆机ID
    address memberAddress;  // 奖励接收人
    uint bonusAmount;       // 奖励数量
    uint boomId;            // 爆块ID
    uint createdDate;       // 创建日期
    uint number;            // 用户持有挖豆机器序号
  }

  // 15% 持有矿机分红记录
  struct HoldingBonusRecord {
    uint id;                // ID
    uint machineId;         // 挖豆机ID
    address memberAddress;  // 奖励接收人
    uint bonusAmount;       // 奖励数量
    uint boomId;            // 爆块ID
    uint createdDate;       // 创建日期
    uint number;            // 用户持有挖豆机器序号
  }

  // 5% 销毁奖励记录
  struct DestroyedBonusRecord {
    uint id;                // ID
    uint machineId;         // 挖豆机ID
    address memberAddress;  // 奖励接收人
    uint bonusAmount;       // 销毁奖励数量
    uint boomId;            // 爆块ID
    uint createdDate;       // 创建日期
    uint number;            // 用户持有挖豆机器序号
  }

  // 挖豆机
  struct BeanDiggingMachine {
    uint id;                      // ID
    uint uuid;                    // 挖豆机编号
    address owner;                // 所属用户
    uint expirationDate;          // 截止日期
    uint createdDate;             // 创建日期
    uint cost;                    // 总计花费的ZZB
    uint purchaseTokenPrice;      // ZZB单价
    uint machineUnitPrice;        // 挖豆机单价
    uint number;                  // 用户持有挖豆机器序号
  }

  struct UnhandledHoldingBonusRecord {
    uint id;                      // ID
    uint boomId;                  // 爆块轮次
    uint holdingBonus;            // 全部奖励
    uint totalMachinesLength;     // 全部矿机数量
    uint sentHoldingBonus;        // 已发放持有奖励
    uint sentCount;               // 已发放数量
    uint createdDate;             // 创建时间
    bool isFinished;              // 是否完成
  }

  // 用户
  struct Member {
    uint id;                      // ID
    uint totalCost;               // 总计花费的ZZB
    address addr;                 // 地址
    uint createdDate;             // 创建日期
    uint machineCount;            // 持有挖矿机的个数
  }

  function getBonusToken() view public returns(IERC20) {
    return bonusToken;
  }

  function getPurchaseToken() view public returns(ERC20) {
    return purchaseToken;
  }

  function getZzbusdtPriceOracleToken() view public returns(ZzbusdtPriceOracleInterface) {
    return oracleInstance;
  }

  function getMiningPoolAmount() view public returns(uint) {
    return miningPoolAmount;
  }

  function getPreMiningAmount() view public returns(uint) {
    return preMiningAmount;
  }

  function getRemainingBonus() view public returns(uint) {
    return totalRemaining;
  }

  function getAlreadyReleasedBonus() view public returns(uint) {
    return alreadyReleasedBonus;
  }

  function getBoomNumber() view public returns(uint) {
    return boomNumber;
  }

  function getBoomTriggerNumber() view public returns(uint) {
    return boomTriggerNumber;
  }

  function getIsEnd() view public returns(bool) {
    return isEnd;
  }

  function getCurrentSection() view public returns(uint) {
    return currentSection;
  }

  function getCurrentSectionBonus() view public returns(uint) {
    return currentSectionBonus;
  }

  function getCurrentSectionTotalBonus() view public returns(uint) {
    return currentSectionTotalBonus;
  }

  function getCurrentSectionReleasedBonus() view public returns(uint) {
    return currentSectionReleasedBonus;
  }

  function getCurrentSectionParticipationNumber() view public returns(uint) {
    return currentSectionParticipationNumber;
  }

  function getCurrentSectionBoomNumber() view public returns(uint) {
    return currentSectionBoomNumber;
  }

  function getMembersInfo(address _memberAddress) view public returns(Member memory) {
    return membersInfo[_memberAddress];
  }

  // 获取全部矿机列表
  function getTotalMachines() view public returns(BeanDiggingMachine[] memory) {
    return totalMachines;
  }

  // 获取全部爆块奖励发放记录
  function getTotalBoomBonusRecords() view public returns(BoomBonusRecord[] memory) {
    return totalBoomBonusRecords;
  }

  // 获取全部持有矿机分红记录
  function getTotalHoldingBonusRecords() view public returns(HoldingBonusRecord[] memory) {
    return totalHoldingBonusRecords;
  }

  // 获取未处理分红记录
  function getTotalUnhandledHoldingBonusRecords() view public returns(UnhandledHoldingBonusRecord[] memory) {
    return totalUnhandledHoldingBonusRecords;
  }

  // 根据批次获取全部持有矿机分红记录
  function getMapHoldingBonusRecords(uint _boomId) view public returns(HoldingBonusRecord[] memory) {
    // -- return mapHoldingBonusRecords[_boomId]; // 按批次来查看
    uint number = 0;
    for (uint i = 0; i < totalHoldingBonusRecords.length; i ++) {
      if (totalHoldingBonusRecords[i].boomId == _boomId) {
        number = number.add(1);
      }
    }
    HoldingBonusRecord[] memory tempRecords = new HoldingBonusRecord[](number);
    uint j = 0;
    for (uint i = 0; i < totalHoldingBonusRecords.length; i ++) {
      if (totalHoldingBonusRecords[i].boomId == _boomId) {
        tempRecords[j] = totalHoldingBonusRecords[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  // 获取全部销毁奖励记录列表
  function getTotalDestroyedBonusRecords() view public returns(DestroyedBonusRecord[] memory) {
    return totalDestroyedBonusRecords;
  }

  // 显示当前登录用户的所有矿机
  function getMemberMachinesInfo() view public returns(BeanDiggingMachine[] memory) {
    // -- return memberMachinesInfo[msg.sender];
    uint number = 0;
    for (uint i = 0; i < totalMachines.length; i ++) {
      if (totalMachines[i].owner == msg.sender) {
        number = number.add(1);
      }
    }
    BeanDiggingMachine[] memory tempRecords = new BeanDiggingMachine[](number);
    uint j = 0;
    for (uint i = 0; i < totalMachines.length; i ++) {
      if (totalMachines[i].owner == msg.sender) {
        tempRecords[j] = totalMachines[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  // 当前登录用户所有的爆块奖励信息
  function getAllMemberBoomBonusInfo() view public returns(BoomBonusRecord[] memory) {
    uint number = 0;
    for (uint i = 0; i < totalBoomBonusRecords.length; i ++) {
      if (totalBoomBonusRecords[i].memberAddress == msg.sender) {
        number = number.add(1);
      }
    }
    BoomBonusRecord[] memory tempRecords = new BoomBonusRecord[](number);
    uint j = 0;
    for (uint i = 0; i < totalBoomBonusRecords.length; i ++) {
      if (totalBoomBonusRecords[i].memberAddress == msg.sender) {
        tempRecords[j] = totalBoomBonusRecords[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  // 显示当前登录用户爆块信息
  function getMemberBoomBonusInfo(uint uuid) view public returns(BoomBonusRecord[] memory) {
    BoomBonusRecord[] memory totalBonusInfo = getAllMemberBoomBonusInfo();
    if (uuid == 0) {
      return totalBonusInfo;
    }
    uint number = 0;
    for (uint i = 0; i < totalBonusInfo.length; i ++) {
      if (totalBonusInfo[i].machineId == uuid) {
        number = number.add(1);
      }
    }
    BoomBonusRecord[] memory tempRecords = new BoomBonusRecord[](number);
    uint j = 0;
    for (uint i = 0; i < totalBonusInfo.length; i ++) {
      if (totalBonusInfo[i].machineId == uuid) {
        tempRecords[j] = totalBonusInfo[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  function getAllMemberHoldingBonusInfo() view public returns(HoldingBonusRecord[] memory) {
    // -- memberHoldingBonusInfo[msg.sender];
    uint number = 0;
    for (uint i = 0; i < totalHoldingBonusRecords.length; i ++) {
      if (totalHoldingBonusRecords[i].memberAddress == msg.sender) {
        number = number.add(1);
      }
    }
    HoldingBonusRecord[] memory tempRecords = new HoldingBonusRecord[](number);
    uint j = 0;
    for (uint i = 0; i < totalHoldingBonusRecords.length; i ++) {
      if (totalHoldingBonusRecords[i].memberAddress == msg.sender) {
        tempRecords[j] = totalHoldingBonusRecords[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  // 显示当前登录用户持有矿机信息
  function getMemberHoldingBonusInfo(uint uuid) view public returns(HoldingBonusRecord[] memory) {
    HoldingBonusRecord[] memory totalBonusInfo = getAllMemberHoldingBonusInfo();
    if (uuid == 0) {
      return totalBonusInfo;
    }
    uint number = 0;
    for (uint i = 0; i < totalBonusInfo.length; i ++) {
      if (totalBonusInfo[i].machineId == uuid) {
        number = number.add(1);
      }
    }
    HoldingBonusRecord[] memory tempRecords = new HoldingBonusRecord[](number);
    uint j = 0;
    for (uint i = 0; i < totalBonusInfo.length; i ++) {
      if (totalBonusInfo[i].machineId == uuid) {
        tempRecords[j] = totalBonusInfo[i];
        j = j.add(1);
      }
    }
    return tempRecords;
  }

  // 获得机器单价
  function getMachineUnitPrice() view public returns(uint) {
    require(zzbusdtPrice > 0, 'zzbusdtPrice is zero !');
    uint unitPrice = _rounding(_toWei(CNY_PRICE).div(zzbusdtPrice).mul(TO_WEI));
    require(unitPrice > 0, 'unit price is illegal!');
    return unitPrice;
  }

  // 更新价格
  function updateZzbusdtPrice() public {
      uint256 id = oracleInstance.getLatestZzbusdtPrice();
      myRequests[id] = true;
      emit ReceivedNewRequestIdEvent(id);
  }

  function oracleCallback(uint _zzbusdtPrice, uint _id) public onlyOracle {
      require(myRequests[_id], "This request is not in my pending list.");
      zzbusdtPrice = _zzbusdtPrice;
      delete myRequests[_id];
      emit PriceUpdatedEvent(_zzbusdtPrice, _id);
  }

  // 购买矿机
  function purchase_bean_digging_machine() public {
    require(!isEnd, 'Game is over!');

    // 扣除价值CNY_PRICE的zzb
    uint deductionAmount = getMachineUnitPrice(); // 每次扣5000个zzb
    uint256 allowance = purchaseToken.allowance(msg.sender, address(this));
    require(allowance >= deductionAmount, string(abi.encodePacked("Check the token allowance: ", uint2str(allowance), ' deductionAmount: ', uint2str(deductionAmount))));

    currentSectionParticipationNumber = currentSectionParticipationNumber.add(1); // 活动参与次数+1

    Member storage currentMember = membersInfo[msg.sender]; // 获取当前用户


    if (currentMember.totalCost == 0) {
      // 初始化
      currentMember.id = totalMemberRecords.length.add(1);
      currentMember.addr = msg.sender;
      currentMember.createdDate = block.timestamp;
      totalMemberRecords.push(currentMember);
    }
    currentMember.totalCost = currentMember.totalCost.add(deductionAmount);

    uint newMachineId = totalMachines.length.add(1);

    BeanDiggingMachine memory newMachine = BeanDiggingMachine(
      newMachineId,
      uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, newMachineId))), // ID
      msg.sender,                                // 挖豆机的持有人
      (block.timestamp + 365 days),              // 挖豆机的有效期
      block.timestamp,                           // 创建时间
      deductionAmount,                           // 挖豆机购买时消耗token的数量
      zzbusdtPrice,                              // ZZB/USDT 价格
      getMachineUnitPrice(),                     // 挖豆机单价
      currentMember.machineCount                 // 用户挖豆机编号
    );

    totalMachines.push(newMachine);

    if (currentSectionParticipationNumber % 5 == 0) { // 每5次触发2次爆块

      emit TestEvent(totalRemaining, currentSectionBonus);

      boomTriggerNumber = boomTriggerNumber.add(1);   // 记录触发次数
      _boom();
      _boom();
    }

    purchaseToken.transferFrom(msg.sender, address(0x0), deductionAmount); // 销毁ZZB

    if (currentSectionParticipationNumber == PARTICIPATION_NUMBER_OF_EVERY_SECTION ) { // 当前活动参与次数达到本阶段上限
      _reload_section_settings();
    }

    emit PurchaseMachineSuccessEvent(newMachine.uuid, newMachine.cost, newMachine.createdDate, newMachine.expirationDate);
  }

  // 爆块
  function _boom() private {

    if (ROUNDS == currentSectionBoomNumber.add(1)) { // 每一阶段最后一次爆块保证奖励一定能发完
      currentSectionBonus = currentSectionTotalBonus.sub(currentSectionReleasedBonus);
    }


    totalRemaining = totalRemaining.sub(currentSectionBonus);
    boomNumber = boomNumber.add(1);
    alreadyReleasedBonus = alreadyReleasedBonus.add(currentSectionBonus);
    currentSectionBoomNumber = currentSectionBoomNumber.add(1);
    currentSectionReleasedBonus = currentSectionReleasedBonus.add(currentSectionBonus);

    // 有效矿机查找
    uint machineIndex = _rand_machine_index();
    BeanDiggingMachine memory bonusMachine = totalMachines[machineIndex];
    Member storage winner = membersInfo[bonusMachine.owner];

    // 爆块奖励发放
    uint boomBonus = _rounding(currentSectionBonus.mul(BOOM_BONUS_RATE).div(COMMON_DENOMINATOR));
    bonusToken.transfer(winner.addr, boomBonus); // 真实发放
    totalBoomBonusRecords.push(BoomBonusRecord(totalBoomBonusRecords.length.add(1), bonusMachine.uuid, winner.addr, boomBonus, boomTriggerNumber, block.timestamp, bonusMachine.number) ); // 记录奖励发放

    // 记录持有矿机奖励
    uint holdingBonus = _rounding(currentSectionBonus.mul(HOLDING_BONUS_RATE).div(COMMON_DENOMINATOR));
    if (holdingBonus >= MIN_BONUS) {
      UnhandledHoldingBonusRecord memory unhandledRecord = UnhandledHoldingBonusRecord(totalUnhandledHoldingBonusRecords.length + 1, boomTriggerNumber, holdingBonus, totalMachines.length, 0, 0, block.timestamp, false);
      totalUnhandledHoldingBonusRecords.push(unhandledRecord);
    }

    // 销毁奖励
    uint destroyedBonus = currentSectionBonus.sub(boomBonus).sub(holdingBonus);
    if (destroyedBonus >= MIN_BONUS) {
      // 销毁
      bonusToken.transfer(address(0x0), destroyedBonus);
      totalDestroyedBonusRecords.push(DestroyedBonusRecord(totalDestroyedBonusRecords.length.add(1), bonusMachine.uuid, address(0x0), destroyedBonus, boomTriggerNumber, block.timestamp, bonusMachine.number));
    }

  }

  // 发放持有奖励
  function handle_holding_bonus(uint _id, uint _amount) public onlyOwner {
    require(_id >= 1, 'id must be more than one');
    require(_amount >= 1, 'amount must be more than one');

    UnhandledHoldingBonusRecord storage record = totalUnhandledHoldingBonusRecords[_id.sub(1)];
    uint _holdingBonus = record.holdingBonus; // 总计奖励
    uint _remainingBonus = _holdingBonus - record.sentHoldingBonus;
    uint thatDatetime = record.createdDate; // 标记时间

    uint number = 0;
    for (uint i = 0; i < record.totalMachinesLength; i ++) {
      if (totalMachines[i].expirationDate >= thatDatetime ) {
        // 未过期
        number = number.add(1);
      }
    }
    BeanDiggingMachine[] memory tempRecords = new BeanDiggingMachine[](number); // 未过期的挖豆机数组

    uint j = 0;
    for (uint i = 0; i < record.totalMachinesLength; i ++) {
      if (totalMachines[i].expirationDate >= thatDatetime) {
        tempRecords[j] = totalMachines[i];
        j = j.add(1);
      }
    }

    uint _bonusMachineNumber = record.totalMachinesLength.div(2); // 前一半小数取整 比如：5 / 2 = 2
    uint _holdingBonusOfMachine = _rounding(_holdingBonus.div(_bonusMachineNumber));
    if (_holdingBonusOfMachine < MIN_BONUS) {
      _holdingBonusOfMachine = MIN_BONUS;  // 最小发放奖励 0.00000001
    }

    for (uint i = 0; i < tempRecords.length; i ++ ) {
      if (i < record.sentCount ) {
        // 已经发过的跳过
        continue;
      }

      if (_remainingBonus > 0 && _remainingBonus < _holdingBonusOfMachine) {
        _holdingBonusOfMachine = _remainingBonus ; // 剩余奖励不够发放一次奖励
      }

      if (_remainingBonus > 0 && _holdingBonusOfMachine > 0) {
        // 奖励发放
        _remainingBonus = _remainingBonus.sub(_holdingBonusOfMachine);
        bonusToken.transfer(tempRecords[i].owner, _holdingBonusOfMachine); // 真实发放
        _amount = _amount.sub(1);

        record.sentCount = record.sentCount.add(1);
        record.sentHoldingBonus = record.sentHoldingBonus.add(_holdingBonusOfMachine);

        totalHoldingBonusRecords.push(HoldingBonusRecord(totalHoldingBonusRecords.length.add(1), tempRecords[i].uuid, tempRecords[i].owner, _holdingBonusOfMachine, record.boomId, block.timestamp, tempRecords[i].number));
      }

      if (_remainingBonus == 0) {
        record.isFinished = true;
        break;
      }

      if (_amount == 0) {
        // 阶段性发放完毕
        break;
      }

    }

    emit HandleHoldingBonusSuccessEvent();

  }

  // 重置阶段配置
  function _reload_section_settings() private {
    currentSection = currentSection.add(1);
    currentSectionBonus = _rounding(BONUS.div(( 2 ** (currentSection.sub(1)) )));
    currentSectionTotalBonus = _rounding(totalRemaining.div(2));
    currentSectionReleasedBonus = 0;
    currentSectionParticipationNumber = 0;
    currentSectionBoomNumber = 0;

    if (currentSectionBonus == 0) {
      isEnd = true; // 结算奖励变为0后游戏结束
    }

  }

  // 保留8位小数
  function _rounding(uint _number) private view returns (uint) {
    return (_number.add(MIN_BONUS.div(2))).div(MIN_BONUS).mul(MIN_BONUS);
  }

  // 转换成Wei为单位
  function _toWei(uint _number) private view returns (uint) {
    return _number.mul(TO_WEI);
  }

  // 未过期的挖豆机中随机抽取一个 Gas消耗太大
  // function _rand_machine() private view returns (BeanDiggingMachine memory) {
  //  BeanDiggingMachine[] memory tempMachines = new BeanDiggingMachine[](totalMachines.length);
  //  uint tempIndex = 0;
  //  for (uint i = 0; i < totalMachines.length; i ++) {
  //    BeanDiggingMachine memory machine = totalMachines[i];
  //    if (machine.expirationDate >= block.timestamp) { // 每5个矿机爆块2次算一轮，一个矿机不会在同一轮中奖两次
  //      if (!(totalBoomBonusRecords.length > 0 && totalBoomBonusRecords[totalBoomBonusRecords.length.sub(1)].machineId == machine.uuid && totalBoomBonusRecords[totalBoomBonusRecords.length.sub(1)].boomId == boomTriggerNumber)) {
  //        tempMachines[tempIndex] = machine;
  //        tempIndex = tempIndex.add(1);
  //      }
  //    }
  //  }
  //  uint index = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % tempIndex;
  //  return tempMachines[index];
  //}

  function _rand_machine_index() private returns (uint) {
    BeanDiggingMachine storage machine = totalMachines[outOfDateMachineCount];
    if (machine.expirationDate < block.timestamp) {
      // 过期
      outOfDateMachineCount = outOfDateMachineCount.add(1);
      _rand_machine_index();
    }
    // 例子：300 过期 150个
    // 随机数：0 - 149
    // 索引：299 ... 150
    uint index = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % (totalMachines.length - outOfDateMachineCount);
    return (totalMachines.length.sub(index).sub(1));
  }

  // uint转字符串
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
  }

  function transferOwnership(address newOwner) public virtual onlyOwner {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      publisher = newOwner;
  }

  modifier onlyOracle() {
    require(msg.sender == oracleAddress, "You are not authorized to call this function.");
    _;
  }

  modifier onlyOwner() {
    require(publisher == msg.sender, "Ownable: caller is not the owner");
    _;
  }

}
