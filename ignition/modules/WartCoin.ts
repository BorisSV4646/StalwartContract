import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WartModule = buildModule("WartModule", (m) => {
  const sender = m.getParameter(
    "_sender",
    "0xF60cEbF2C6806863038D1d9526d2Df633664fb3d"
  );

  const wart = m.contract("StalwartToken", [sender]);

  return { wart };
});

export default WartModule;
