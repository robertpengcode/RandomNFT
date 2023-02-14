const { network } = require("hardhat");
const {
  networkConfig,
  developmentChains,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const {
  storeImages,
  storeTokenUriMetadata,
} = require("../utils/uploadToPinata");

const BASE_FEE = "250000000000000000"; // 0.25 is this the premium in LINK?
const GAS_PRICE_LINK = 1e9; // link per gas, is this the gas lane? // 0.000000001 LINK per gas

const FUND_AMOUNT = "1000000000000000000000";
const imagesLocation = "./images/randomNft/";

let tokenUris = [
  "ipfs://QmWJcanVAhHkVAf5GDGrVHw283GJfongt6uXyDL5WdWGpv",
  "ipfs://QmayjTnrQEmGBXnXZGBSf9A6Xb2ShqYeoThLuHrSzAoQBb",
  "ipfs://QmX56yzbA6oSNkkqYV5om9T82p9fzPD9GNHgHfC5e3GBCB",
  "ipfs://QmdPC6FKj8Cehs2syRFQ2MATirUtK2Zn6NHphzZAhxU8Dp",
  "ipfs://Qmag4gyrFrUgLM6o6ragMMdt2haLM8hecN8XsDm2m5XExT",
];

const metadataTemplate = {
  name: "",
  description: "",
  image: "",
  attributes: [
    {
      personality: "test personality",
      skill: "test skill",
    },
  ],
};

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let vrfCoordinatorV2Address, subscriptionId, vrfCoordinatorV2Mock;

  if (process.env.UPLOAD_TO_PINATA == "true") {
    tokenUris = await handleTokenUris();
  }

  if (chainId == 31337) {
    log("Local network detected! Deploying mocks...");
    const VRFCoordinatorV2Mock = await ethers.getContractFactory(
      "VRFCoordinatorV2Mock"
    );
    vrfCoordinatorV2Mock = await VRFCoordinatorV2Mock.deploy(
      BASE_FEE,
      GAS_PRICE_LINK
    );
    vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address;

    const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
    const transactionReceipt = await transactionResponse.wait();
    subscriptionId = transactionReceipt.events[0].args.subId;
    // Fund the subscription
    // Our mock makes it so we don't actually have to worry about sending fund
    await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT);
    log("Mocks Deployed!");
    log("----------------------------------------------------");
    log(
      "You are deploying to a local network, you'll need a local network running to interact"
    );
    log(
      "Please run `yarn hardhat console --network localhost` to interact with the deployed smart contracts!"
    );
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2;
    subscriptionId = networkConfig[chainId].subscriptionId;
  }

  log("----------------------------------------------------");
  arguments = [
    //vrfCoordinatorV2Address,
    subscriptionId,
    //networkConfig[chainId]["gasLane"],
    networkConfig[chainId]["mintFee"],
    //networkConfig[chainId]["callbackGasLimit"],
    tokenUris,
  ];
  const randomNFT = await deploy("RandomNFT", {
    from: deployer,
    args: arguments,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (chainId == 31337) {
    await vrfCoordinatorV2Mock.addConsumer(subscriptionId, randomNFT.address);
  }

  // Verify the deployment
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying...");
    await verify(randomNFT.address, arguments);
  }
};

async function handleTokenUris() {
  // uploading to the raw IPFS-daemon from https://docs.ipfs.io/how-to/command-line-quick-start/
  // pinata https://www.pinata.cloud/
  tokenUris = [];
  const { responses: imageUploadResponses, files } = await storeImages(
    imagesLocation
  );
  for (imageUploadResponseIndex in imageUploadResponses) {
    let tokenUriMetadata = { ...metadataTemplate };
    const [name, personality, skill] = files[imageUploadResponseIndex]
      .replace(".png", "")
      .split("_");
    tokenUriMetadata.name = name;
    tokenUriMetadata.description = `Adventure with ${name}!`;
    tokenUriMetadata.image = `ipfs://${imageUploadResponses[imageUploadResponseIndex].IpfsHash}`;
    tokenUriMetadata.attributes[0].personality = personality;
    tokenUriMetadata.attributes[0].skill = skill;
    console.log(`Uploading ${tokenUriMetadata.name}...`);
    const metadataUploadResponse = await storeTokenUriMetadata(
      tokenUriMetadata
    );
    tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`);
  }
  console.log("Token URIs uploaded! They are:");
  console.log("finally...", tokenUris);
  return tokenUris;
}

module.exports.tags = ["all", "randomNFT", "main"];
