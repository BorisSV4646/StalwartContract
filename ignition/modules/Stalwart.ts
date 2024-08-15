import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StalwartModule = buildModule("StalwartModule", (m) => {
  const ownersArray = [
    "0x6D61C52b41272e23927A8Dd622d00e6502469274",
    "0x19F058dE8B6e75B89e41036E5C8254Ec8457C8fC",
    "0xfA731D351DdF67A9E2Fa829B3eF91FBdDC71C0Cb",
    "0xDbfEEa0fc1F1F2f43F7DbaD7827Cccad8C47c337",
  ];

  const owners = m.getParameter("_owners", ownersArray);
  const requiredSignatures = m.getParameter("_requiredSignatures", 4);

  const stalwart = m.contract("Stalwart", [owners, requiredSignatures]);

  return { stalwart };
});

export default StalwartModule;
