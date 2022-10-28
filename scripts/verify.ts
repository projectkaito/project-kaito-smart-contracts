import { ethers, utils } from "ethers";

const signWhitelist = async (
  contract: string,
  account: string,
  quantity: number,
  deadline: number,
  userType: "whitelist" | "team"
) => {
  const provider = await ethers.getDefaultProvider("https://mainnet.infura.io/v3/832efcccfe9c457eb255d893f2eab5b0");
  const chainId = (await provider.getNetwork()).chainId;
  const wallet = new ethers.Wallet("06d31722a299dc7437617435be753572ceece6c323ab08f064c4e4e28aa426a0", provider);
  const domain = {
    name: "ProjectKaito",
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
  const signature = await wallet._signTypedData(domain, type, message);

  const recoveredAddress = utils.verifyTypedData(
    domain,
    type,
    message,
    "0x18b5c177d3fd51287d28e528e47a512d781dd60149621a1175a1e75fd14461a13d3544d3ca7df711d9e87540ae37dcf07d601c15d9ef76030c33d01eeb2123cf1b"
  );
  if (wallet.address != recoveredAddress) {
    console.log(wallet.address, recoveredAddress);
    throw new Error("Signature is not valid");
  }

  if (wallet.address === recoveredAddress) {
    console.log("congo");
  }

  return signature;
};

signWhitelist(
  "0x31A7D612788277457c03e34ecD4Efe4d6E6a8e39",
  "0x4780b139E806c63355ec401eC3b361b1Da182416",
  1,
  1662125934,
  "whitelist"
);
