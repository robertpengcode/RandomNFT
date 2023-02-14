const { network } = require("hardhat");
const {
  networkConfig,
  developmentChains,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  const daySVG = fs.readFileSync("./images/svgNFT/day.svg", {
    encoding: "utf8",
  });
  const nightSVG = fs.readFileSync("./images/svgNft/night.svg", {
    encoding: "utf8",
  });

  log("----------------------------------------------------");
  arguments = ["10000000000000000", daySVG, nightSVG];
  const dynamicSvgNft = await deploy("SvgNFT", {
    from: deployer,
    args: arguments,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  // Verify the deployment
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying...");
    await verify(dynamicSvgNft.address, arguments);
  }
};

module.exports.tags = ["all", "svgNFT", "main"];
