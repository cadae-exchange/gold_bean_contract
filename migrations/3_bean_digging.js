const ZzbToken = artifacts.require("ZzbToken");
const BeanDigging = artifacts.require("BeanDigging");

module.exports = async function (deployer) {
  await deployer.deploy(ZzbToken);
  const token = await ZzbToken.deployed();
  await deployer.deploy(BeanDigging, token.address);
};
