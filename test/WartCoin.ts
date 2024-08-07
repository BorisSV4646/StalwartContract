import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("WartCoin", function () {
  async function deployOneYearLockFixture() {
    const [owner, otherAccount1, otherAccount2] = await hre.ethers.getSigners();

    const Wart = await hre.ethers.getContractFactory("StalwartToken");
    const wart = await Wart.deploy(otherAccount1);

    const wartAddress = await wart.getAddress();

    return { wart, wartAddress, otherAccount1, otherAccount2 };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { wart, otherAccount1, wartAddress } = await loadFixture(
        deployOneYearLockFixture
      );

      const sendAmount = await hre.ethers.parseEther("400000000");

      expect(await wart.SENDER()).to.equal(otherAccount1);
      expect(await wart.balanceOf(wartAddress)).to.equal(sendAmount);
    });
  });

  describe("BatchTransfer", function () {
    it("BatchTransfer work correct", async function () {
      const { wart, otherAccount1, otherAccount2, wartAddress } =
        await loadFixture(deployOneYearLockFixture);

      const sendAmount = await hre.ethers.parseEther("40000000");

      const sender = await wart.connect(otherAccount1);

      await sender.batchTransfer(
        [otherAccount1, otherAccount2],
        [sendAmount, sendAmount]
      );

      expect(await wart.balanceOf(wartAddress)).to.equal(
        await hre.ethers.parseEther("320000000")
      );

      await expect(
        wart.batchTransfer(
          [otherAccount1, otherAccount2],
          [sendAmount, sendAmount]
        )
      ).to.be.reverted;
    });
  });
});
