import { expect } from "chai";
import { utils } from "ethers";
import { ethers } from "hardhat";
import { Kaito } from "../typechain-types";

describe("Kaito test", () => {
  let Kaito: Kaito;

  it("It should deploy Kaito", async () => {
    const [deployer] = await ethers.getSigners();

    const kaitoContract = await ethers.getContractFactory("Kaito");
    Kaito = await kaitoContract.deploy(
      2, // batch size
      7777, // collection size
      50, // max team mint
      100, // max whitelist mint
      "", // base token uri
      0,
      0,
      parseInt(String(Date.now() / 1000 + 60 * 60)),
      deployer.address
    );
  });

  it("It should mint whitelist", async () => {
    const [deployer, user] = await ethers.getSigners();
    const quantity = 1;
    const deadline = parseInt(String(Date.now() / 1000 + 60 * 60 * 24));
    const signature = await signWhitelist(Kaito.address, user.address, quantity, deadline, "whitelist");
    const splitSignature = utils.splitSignature(signature);

    expect(
      await Kaito.connect(user).mintWhitelist(deadline, quantity, splitSignature.v, splitSignature.r, splitSignature.s),
      "Team mint failed"
    );
  });

  it("It should mint team", async () => {
    const [deployer, user] = await ethers.getSigners();
    const quantity = 1;
    const deadline = parseInt(String(Date.now() / 1000 + 60 * 60 * 24));
    const signature = await signWhitelist(Kaito.address, user.address, quantity, deadline, "team");
    const splitSignature = utils.splitSignature(signature);

    expect(
      await Kaito.connect(user).mintTeam(deadline, quantity, splitSignature.v, splitSignature.r, splitSignature.s),
      "Team mint failed"
    );
  });
});

const signWhitelist = async (
  contract: string,
  account: string,
  quantity: number,
  deadline: number,
  userType: "whitelist" | "team"
) => {
  const [deployer] = await ethers.getSigners();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const domain = {
    name: "Kaito",
    version: "1",
    chainId: chainId,
    verifyingContract: contract,
  };
  const teamType = {
    TeamMint: [
      { name: "user", type: "address" },
      { name: "quantity", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };

  const whitelistType = {
    WhitelistMint: [
      { name: "user", type: "address" },
      { name: "quantity", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };
  const message = {
    user: account,
    quantity: quantity,
    deadline: deadline,
  };
  const type = userType === "team" ? teamType : whitelistType;
  const signature = await deployer._signTypedData(domain, type, message);

  const recoveredAddress = utils.verifyTypedData(domain, type, message, signature);
  if (deployer.address != recoveredAddress) {
    console.log(deployer.address, recoveredAddress);
    throw new Error("Signature is not valid");
  }

  return signature;
};
