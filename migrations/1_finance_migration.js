const Finance = artifacts.require("Finance");

module.exports = function (deployer) {
  deployer.deploy(Finance);
};
