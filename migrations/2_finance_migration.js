const Finance = artifacts.require("Finance");

module.exports = function (deployer) {
  deployer.deploy(
    Finance,
    "0xbe001abf3d32b5738da3c6c8f9e80bf01365739569319ea8a16fc0d8bf0fe72c"
  );
};
