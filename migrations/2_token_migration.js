var Token = artifacts.require("./Token.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Token, web3.toWei(45534000, "ether"), web3.toWei(1000000, "ether"), {from: accounts[0]});
};