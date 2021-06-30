const ZzbusdtOracle = artifacts.require("ZzbusdtPriceOracle");

module.exports = async function (deployer) {
  deployer.deploy(ZzbusdtOracle);
};
