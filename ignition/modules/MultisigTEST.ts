import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MultiSigWalletTestModule = buildModule(
  "MultiSigWalletTestModule",
  (m) => {
    const owners = m.getParameter("_owners", [
      "0xbE6B1920CAf6CB6f94f6FE14a52736081477f07F",
    ]);
    const requiredSignatures = m.getParameter("_requiredSignatures", 1);

    const multiSigWalletTest = m.contract("MultiSigWalletTest", [
      owners,
      requiredSignatures,
    ]);

    const tokenReciever = m.getParameter(
      "tokenReciever",
      "0xbE6B1920CAf6CB6f94f6FE14a52736081477f07F"
    );
    const token = m.contract("MultisigToken", [tokenReciever]);

    return { multiSigWalletTest };
  }
);

export default MultiSigWalletTestModule;
