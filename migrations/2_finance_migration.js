const Finance = artifacts.require("Finance");

module.exports = function (deployer) {
  deployer.deploy(
    Finance,
    "0xc046ebd630350fe961b55fcfd40f6137e27aeb664292d62af7eecde34a422f25"
  );
};
