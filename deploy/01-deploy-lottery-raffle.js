const { network, ethers } = require("hardhat");
const { verify } = require("../utils/verify");

const deployFunc = async (hre) => {
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [ethers.utils.parseEther("0.001"), "60"];

  const raffle = await deploy("Raffle", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 6,
  });
  log("--- Deployment completed ---");

  await verify(raffle.address, args);
  log("--- Verification done ---");
};

module.exports = deployFunc;
module.exports.tags = ["Raffle"];
