const ZzbToken = artifacts.require("ZzbToken");
const BeanDigging = artifacts.require("BeanDigging");
const gbtoken = require('../build/contracts/GBToken.json')
const zzbtoken = require('../build/contracts/ZzbToken.json')

contract("BeanDigging", (accounts) => {
    let [alice, bob] = accounts;

    function toWei(number_str) {
      return number_str + '000000000000000000'
    }

    async function purchase(number) {
      for(let i = 0; i < number; i++ ) {
        // 调用购买矿机的方法
        await contractInstance.purchase_bean_digging_machine({from: alice, gas: 16159159 })
      }

      totalMachines = await contractInstance.getTotalMachines()
      currentMember = await contractInstance.getMembersInfo(alice)
      memberMachinesInfo = await contractInstance.getMemberMachinesInfo()

      console.log('totalMachines == ')
      console.log(totalMachines)
      console.log('memberMachineInfo')
      console.log(memberMachinesInfo)
      console.log('currentMember == ')
      console.log(currentMember)
    }

    beforeEach(async () => {
        TOTALBONUS = 400 // 全部奖励
        PRE_MINING = 100 // 预挖
        CNY_PRICE = 5000;
        tokenContract = await ZzbToken.new();
        contractInstance = await BeanDigging.new(tokenContract.address);
        bonusToken = new web3.eth.Contract(gbtoken['abi'], await contractInstance.getBonusToken())
        purchaseToken = new web3.eth.Contract(zzbtoken['abi'], await contractInstance.getPurchaseToken())
        await purchaseToken.methods.approve(contractInstance.address, toWei('3000000000')).send({from: alice})
    });

    xit("初始余额确认: ", async () => {
      // 合约GB余额400万
      let contract_gb_balance = await bonusToken.methods.balanceOf(contractInstance.address).call()
      assert.equal(web3.utils.fromWei(contract_gb_balance), TOTALBONUS)

      // 发行人GB余额100万
      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_gb_balance), PRE_MINING)
    })

    xit("确认合约初始值: ", async () => {
      let totalBonus = await contractInstance.getRemainingBonus() // 全部发放奖励
      let alreadyReleasedBonus = await contractInstance.getAlreadyReleasedBonus()
      let boomNumber = await contractInstance.getBoomNumber()
      let isEnd = await contractInstance.getIsEnd()

      let currentSection = await contractInstance.getCurrentSection() // 默认的阶段
      let currentSectionBonus = await contractInstance.getCurrentSectionBonus()
      let currentSectionTotalBonus = await contractInstance.getCurrentSectionTotalBonus()
      let currentSectionReleasedBonus = await contractInstance.getCurrentSectionReleasedBonus()
      let currentSectionParticipationNumber = await contractInstance.getCurrentSectionParticipationNumber()
      let currentSectionBoomNumber = await contractInstance.getCurrentSectionBoomNumber()
      let machineUnitPrice = await contractInstance.getMachineUnitPrice()

      assert.equal(web3.utils.fromWei(totalBonus), TOTALBONUS)
      assert.equal(alreadyReleasedBonus, 0)
      assert.equal(boomNumber, 0)
      assert.equal(isEnd, false)
      assert.equal(currentSection, 1)
      assert.equal(web3.utils.fromWei(currentSectionBonus), 50)
      assert.equal(web3.utils.fromWei(currentSectionTotalBonus), TOTALBONUS / 2)
      assert.equal(currentSectionReleasedBonus, 0)
      assert.equal(currentSectionParticipationNumber, 0)
      assert.equal(currentSectionBoomNumber, 0)
      assert.equal(web3.utils.fromWei(machineUnitPrice), 5000)

    })

    it("购买一台矿机: ", async () => {

      await purchase(1) // 购买一次

      assert.equal(totalMachines.length, 1)      // 校验挖豆机是否保存
      assert.equal(memberMachinesInfo.length, 1)
      assert.equal(memberMachinesInfo[0].id, totalMachines[0].id)  // 保存的校验挖豆机是否一致
      assert.equal(web3.utils.fromWei(currentMember.totalCost), CNY_PRICE) //校验花费ZZB

      let currentSectionParticipationNumber = await contractInstance.getCurrentSectionParticipationNumber() // 初始阶段的奖励
      assert.equal(currentSectionParticipationNumber, 1) //校验花费ZZB
    })

    it("购买5台矿机: 应该爆块2次 获得95GB", async () => {

      await purchase(5) // 再购买4次
      assert.equal(totalMachines.length, 5)      // 校验挖豆机是否保存
      assert.equal(memberMachinesInfo.length, 5)

      assert.equal(web3.utils.fromWei(currentMember.totalCost), 5 * CNY_PRICE) //校验花费ZZB

      let currentSectionParticipationNumber = await contractInstance.getCurrentSectionParticipationNumber() // 初始阶段的奖励
      assert.equal(currentSectionParticipationNumber, 5)

      let totalBoomBonusRecords = await contractInstance.getTotalBoomBonusRecords()
      let totalHoldingBonusRecords = await contractInstance.getMapHoldingBonusRecords(1)
      let totalDestroyedBonusRecords = await contractInstance.getTotalDestroyedBonusRecords()

      console.log('totalBoomBonusRecords === ')
      console.log(totalBoomBonusRecords)
      console.log('totalHoldingBonusRecords === ')
      console.log(totalHoldingBonusRecords)
      console.log('totalDestroyedBonusRecords === ')
      console.log(totalDestroyedBonusRecords)

      // 发行人GB余额100万
      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_gb_balance), 95 + PRE_MINING)

    })

    it("购买10台矿机: alice应该爆块4次 获得190GB", async () => {

      await purchase(10) // 购买10次

      assert.equal(totalMachines.length, 10)      // 校验挖豆机是否保存
      assert.equal(memberMachinesInfo.length, 10)
      assert.equal(web3.utils.fromWei(currentMember.totalCost), 10 * CNY_PRICE) //校验花费ZZB

      // 发行人GB余额100万
      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_gb_balance), 190 + PRE_MINING)
    })

    it("购买16台矿机: alice应该爆块6次 获得190 + 47.5GB", async () => {

      await purchase(16) // 购买16次

      assert.equal(totalMachines.length, 16)      // 校验挖豆机是否保存
      assert.equal(memberMachinesInfo.length, 16)
      assert.equal(web3.utils.fromWei(currentMember.totalCost), 16 * CNY_PRICE) //校验花费ZZB

      // 发行人GB余额100万
      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_gb_balance), 237.5 + PRE_MINING)

      let eth_balance = await web3.eth.getBalance(alice)
      console.log(eth_balance)
    })

    it("购买20台矿机: alice应该爆块10次 获得190 + 95GB", async () => {

      await purchase(20) // 购买20次

      assert.equal(totalMachines.length, 20)      // 校验挖豆机是否保存
      assert.equal(memberMachinesInfo.length, 20)
      assert.equal(web3.utils.fromWei(currentMember.totalCost), 20 * CNY_PRICE) //校验花费ZZB

      // 发行人GB余额100万
      let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      assert.equal(web3.utils.fromWei(alice_gb_balance), 285 + PRE_MINING)

      console.log(alice_gb_balance)
    })

    xit("四舍五入看看有没有问题", async () => {


      await purchase(41)
      //let is_end = await contractInstance.getIsEnd()

      console.log("totalMachines.length")
      console.log(totalMachines.length)
      console.log("last totalMachines")
      console.log(totalMachines[totalMachines.length - 1])

      //let alice_gb_balance = await bonusToken.methods.balanceOf(alice).call()
      //assert.equal(web3.utils.fromWei(alice_gb_balance), 380 + PRE_MINING)
    })





})
