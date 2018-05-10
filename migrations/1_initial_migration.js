var Migrations = artifacts.require("./Migrations.sol");
var Token = artifacts.require("./Token.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(Token, web3.toWei(45534000, "ether"));
};
