import hre from "hardhat";

async function deployContract() {
  const ContractFactory = await hre.ethers.getContractFactory("Kaito");
  const constructorArguments: [string,string,string,string] = [
    "1",
    "7777",
    "5",
    "1",
  ];
  const contract = await ContractFactory.deploy(...constructorArguments);

  await contract.deployed();

  console.log("Contract deployed to:", contract.address);

  await contract.deployTransaction.wait();

  hre.network.name === "hardhat"
    ? console.log("Skipping verify")
    : await verifyContract(contract.address, constructorArguments);
}

// async function deployContract() {
//   const ContractFactory = await hre.ethers.getContractFactory("PoolFactory");
//   const contract = await ContractFactory.deploy();

//   await contract.deployed();

//   console.log("Contract deployed to:", contract.address);

//   await contract.deployTransaction.wait();

//   hre.network.name === "hardhat" ? console.log("Skipping verify") : await verifyContract(contract.address, []);
// }

async function main() {
  // console.log("Uncomment to deploy");
  // console.log("Deploying Pool");
  // await deployPool();
  console.log("Deploying...");
  await deployContract()
}

function verifyContract(contractAddress: string, constructorArguments: string[], intervalSec: number = 10) {
  return new Promise<void>(async (res, rej) => {
    (async function verify() {
      try {
        console.log("Verifying Contract");
        await hre.run("verify:verify", {
          address: contractAddress,
          constructorArguments,
        });
        console.log("Verify Success");
        res();
      } catch (error) {
        console.log("Verify Error");
        let timer = intervalSec;
        let int = setInterval(() => {
          console.log("Trying again in " + timer);
          timer--;
          if (timer === 0) {
            clearInterval(int);
            verify();
          }
        }, 1000);
      }
    })();
    setTimeout(rej, 1000 * 60 * 5); // 5 minutes timeout
  });
}

// async function getGasEstimate(contractInstance, methodName, ...args) {
//   let gasPriceBigNumberWei = await hre.ethers.provider.getGasPrice();
//   let gasPriceGwei = hre.ethers.utils.formatUnits(gasPriceBigNumberWei, 'gwei');

//   let gasUnitsEstimate = await contractInstance.estimateGas[methodName](...args);
//   let estimate = Number(gasPriceGwei) * Number(gasUnitsEstimate)
//   // gwei to eth
//   estimate = estimate / 1000000000;
//   console.log("Estimated gas eth:", estimate);
// }

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// main()
