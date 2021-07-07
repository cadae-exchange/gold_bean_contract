const ZzbToken = artifacts.require("ZzbToken");
const BeanDigging = artifacts.require("BeanDigging");
const ZzbusdtOracle = artifacts.require("ZzbusdtPriceOracle");

module.exports = async function (deployer) {
  await deployer.deploy(ZzbusdtOracle);
  await deployer.deploy(ZzbToken);
  const token = await ZzbToken.deployed();
  const oracle = await ZzbusdtOracle.deployed();
  await deployer.deploy(BeanDigging, token.address, oracle.address);
};
