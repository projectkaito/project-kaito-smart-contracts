import { ProjectKaito } from "../typechain-types";

const { utils, constants } = require("ethers");
const { ethers } = require("hardhat");
const hre = require("hardhat");

const ROUTERS = {
  PANCAKE: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
  PANCAKE_TESTNET: "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3",
  UNISWAP: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  SUSHISWAP_TESTNET: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
  PANGALIN: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106",
};

const sleep = async (s: number) => {
  for (let i = s; i > 0; i--) {
    process.stdout.write(`\r \\ ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r | ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r / ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r - ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    if (i === 1) process.stdout.clearLine(0);
  }
};

const verify = async (contractAddress: string, args: (string | number)[] = [], name?: string, wait: number = 100) => {
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    return true;
  } catch (e) {
    if (
      String(e).indexOf(`${contractAddress} has no bytecode`) !== -1 ||
      String(e).indexOf(`${contractAddress} does not have bytecode`) !== -1
    ) {
      console.log(`Verification failed, waiting ${wait} seconds for etherscan to pick the deployed contract`);
      await sleep(wait);
    }

    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
      });
      return true;
    } catch (e) {
      if (String(e).indexOf("Already Verified") !== -1 || String(e).indexOf("Already verified") !== -1) {
        console.log(name ?? contractAddress, "is already verified!");
        return true;
      } else {
        console.log(e);
        return false;
      }
    }
  }
};

const getDeployed = async (name: string, address: string) => {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = await contractFactory.attach(address);
  return contract;
};

const deploy = async (name: string, args: (string | number)[] = [], verificationWait = 100) => {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = await contractFactory.deploy(...args);
  await contract.deployed();
  console.log(`${name}: ${contract.address}`);

  if (hre.network.name === "localhost") return contract;

  console.log("Verifying...");
  await verify(contract.address, args, name);

  return contract;
};

const owner = "0xE7EEE4aA7c0e1f300a912223eFc42E4d74daD172";
const baseURI = "https://projectkaito-api.herokuapp.com/api/unrevealed/";

async function main() {
  const [deployer] = await ethers.getSigners();

  const kaito: ProjectKaito = await deploy("ProjectKaito", [
    229, // batch size
    7777, // collection size
    baseURI, // base token uri
    1662019200,
    1662040800,
    1662127200,
    owner,
  ]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
