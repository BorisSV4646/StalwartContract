import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { time, mine } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Stalwart", function () {
  async function deployOneYearLockFixture() {
    const [
      owner,
      otherAccount1,
      otherAccount2,
      otherAccount3,
      otherAccount4,
      otherAccount5,
    ] = await hre.ethers.getSigners();

    const usdtRebalancer = "0xCF86c768E5b8bcc823aC1D825F56f37c533d32F9";
    const usdcRebalancer = "0x6eAFd6Ae0B766BAd90e9226627285685b2d702aB";
    const daiRebalancer = "0x5A0F7b7Ea13eDee7AD76744c5A6b92163e51a99a";

    const owners = [owner, otherAccount1, otherAccount2, otherAccount3];
    const requireSignatures = 4;

    const Stalwart = await hre.ethers.getContractFactory("Stalwart");
    const stalwart = await Stalwart.deploy(owners, requireSignatures);

    const stalwartAddress = await stalwart.getAddress();

    // Send USDT
    const USDT = "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9";
    const amount = hre.ethers.parseUnits("100", 6);

    const impersonatedSigner = await hre.ethers.getImpersonatedSigner(
      "0x483848D2C8f7F69b51cB7B39C7D8c3C30F333d79"
    );
    const tokenUSDT = await hre.ethers.getContractAt("IERC20", USDT);
    await tokenUSDT.connect(impersonatedSigner).transfer(owner, amount);

    // Send UNI
    const UNI = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0";
    const amountUni = hre.ethers.parseEther("100");

    const impersonatedSignerUni = await hre.ethers.getImpersonatedSigner(
      "0xAF1c30f7E8CE075205714CaA88203243B60b297F"
    );
    const tokenUNI = await hre.ethers.getContractAt("IERC20", UNI);
    await tokenUNI.connect(impersonatedSignerUni).transfer(owner, amountUni);

    return {
      stalwart,
      stalwartAddress,
      owner,
      otherAccount1,
      otherAccount2,
      otherAccount3,
      otherAccount4,
      otherAccount5,
      tokenUSDT,
      tokenUNI,
      UNI,
      impersonatedSigner,
      usdtRebalancer,
    };
  }

  describe("BuyStalwartForStable", function () {
    it("buyStalwartForStable and soldStalwart work correct", async function () {
      const {
        stalwart,
        tokenUSDT,
        stalwartAddress,
        owner,
        usdtRebalancer,
        impersonatedSigner,
      } = await loadFixture(deployOneYearLockFixture);

      const amount = hre.ethers.parseEther("10");
      const amountUSDT = hre.ethers.parseUnits("10", 6);

      await tokenUSDT.approve(stalwartAddress, amount);
      const buy = await stalwart.buyStalwartForStable(amount, 1);

      await expect(buy).to.changeTokenBalances(
        tokenUSDT,
        [owner, stalwartAddress, usdtRebalancer],
        [-amountUSDT, amountUSDT / 2n, 0]
      );

      await expect(buy).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress, usdtRebalancer],
        [amount, 0, 0]
      );

      // добавляем 5000 так как снимает комиссия при отправке в пул
      await tokenUSDT
        .connect(impersonatedSigner)
        .transfer(stalwartAddress, amountUSDT - 9995000n);

      const sell = await stalwart.soldStalwart(amount);

      await expect(sell).to.changeTokenBalances(
        tokenUSDT,
        [owner, stalwartAddress, usdtRebalancer],
        [amountUSDT, -amountUSDT / 2n - 5000n, 0]
      );

      await expect(sell).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress, usdtRebalancer],
        [-amount, 0, 0]
      );
    });
  });

  describe("BuyStalwartForToken", function () {
    it("buyStalwartForToken and soldStalwart work correct", async function () {
      const {
        stalwart,
        tokenUNI,
        tokenUSDT,
        UNI,
        stalwartAddress,
        owner,
        usdtRebalancer,
        impersonatedSigner,
      } = await loadFixture(deployOneYearLockFixture);

      const amount = hre.ethers.parseEther("10");

      await tokenUNI.approve(stalwartAddress, amount);
      const buy = await stalwart.buyStalwartForToken(amount, UNI);

      await expect(buy).to.changeTokenBalances(
        tokenUNI,
        [owner, stalwartAddress, usdtRebalancer],
        [-amount, 0, 0]
      );

      const usdtAfterSwap = 38957103n;
      const stalwartAfterSwap = usdtAfterSwap * 10n ** 12n;
      await expect(buy).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress, usdtRebalancer],
        [stalwartAfterSwap, 0, 0]
      );

      // добавляем 19479 так как снимает комиссия при отправке в пул
      await tokenUSDT
        .connect(impersonatedSigner)
        .transfer(stalwartAddress, 19479n);

      const sell = await stalwart.soldStalwart(stalwartAfterSwap);

      await expect(sell).to.changeTokenBalances(
        tokenUSDT,
        [owner, stalwartAddress, usdtRebalancer],
        [usdtAfterSwap, -usdtAfterSwap / 2n - 19480n, 0]
      );

      await expect(sell).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress, usdtRebalancer],
        [-stalwartAfterSwap, 0, 0]
      );
    });
  });

  describe("BuyStalwartForEth", function () {
    it("buyStalwartForEth and soldStalwart work correct", async function () {
      const {
        stalwart,
        tokenUSDT,
        stalwartAddress,
        owner,
        usdtRebalancer,
        impersonatedSigner,
      } = await loadFixture(deployOneYearLockFixture);
      const stalwartAfterSwap = 2681830981000000000000n;
      const amountETH = hre.ethers.parseEther("1");

      const buy = await stalwart.buyStalwartForEth({
        value: amountETH,
      });

      await expect(buy).to.changeEtherBalances(
        [owner, stalwartAddress],
        [-amountETH, 0]
      );

      await expect(buy).to.changeTokenBalances(
        tokenUSDT,
        [owner, stalwartAddress],
        [0, 1340915491n]
      );

      await expect(buy).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress, usdtRebalancer],
        [stalwartAfterSwap, 0, 0]
      );

      // добавляем 1340912n так как снимает комиссия при отправке в пул
      await tokenUSDT
        .connect(impersonatedSigner)
        .transfer(stalwartAddress, 1340912n);

      const sell = await stalwart.soldStalwart(stalwartAfterSwap);

      await expect(sell).to.changeTokenBalances(
        tokenUSDT,
        [owner, stalwartAddress],
        [stalwartAfterSwap / 10n ** 12n, -1342256399n]
      );

      await expect(sell).to.changeTokenBalances(
        stalwart,
        [owner, stalwartAddress],
        [-stalwartAfterSwap, 0]
      );
    });
  });

  describe("Multisig work correct", function () {
    it("changeBalancerToAave work correct", async function () {
      const {
        stalwart,
        otherAccount1,
        otherAccount2,
        otherAccount3,
        otherAccount4,
      } = await loadFixture(deployOneYearLockFixture);

      await stalwart.changeBalancerToAave(true);

      await expect(stalwart.signTransaction(0)).to.be.reverted;

      await stalwart.connect(otherAccount1).signTransaction(0);
      await stalwart.connect(otherAccount2).signTransaction(0);

      await expect(stalwart.executeChangeBalancerToAaae(true)).to.be.reverted;
      const transaction = await stalwart
        .connect(otherAccount3)
        .signTransaction(0);

      await expect(await stalwart.useAave()).to.be.true;
    });
  });
});
