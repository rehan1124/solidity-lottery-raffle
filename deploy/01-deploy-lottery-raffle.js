const { network } = require("hardhat");

const deployFunc = async (hre) => {
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Raffle", {
    from: deployer,
    args: [1000],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  log("---Deployment completed ---");
};

module.exports = deployFunc;
module.exports.tags = ["Raffle"];
