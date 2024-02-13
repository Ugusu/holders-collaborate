const { zeroAddress } = require("@nomicfoundation/ethereumjs-util");
const { expect } = require("chai");
const { ethers, waffle, upgrades } = require("hardhat");
const { parseUnits, parseEther } = ethers;

async function waitStart(holders){
  const startTimestamp = await holders.start();
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  const currentTimestamp = block.timestamp;
  const remainingTime = Number(startTimestamp) - Number(currentTimestamp);
  if (remainingTime > 0) {
    await new Promise(resolve => setTimeout(resolve, remainingTime * 1000));
  }
}

describe("Holders", function () {
  let holders;
  let owner;
  let holder1;
  let holder2;
  let token1;
  let token2;
  let token3;

  beforeEach(async function () {
    [owner, holder1, holder2, token1, token2, token3] = await ethers.getSigners();

    // Deploy tokens
    const ERC20 = await ethers.getContractFactory("erc20test");
    token1 = await ERC20.deploy("Token1", "T1", parseEther("10000000"));
    token2 = await ERC20.deploy("Token2", "T2", parseEther("10000000"));
    token3 = await ERC20.deploy("Token2", "T2", parseEther("10000000"));

    await token1.waitForDeployment();
    await token2.waitForDeployment();
    await token3.waitForDeployment();

    // Get current timestamp
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    const currentTimestamp = block.timestamp;

    // Deplot Holders contract
    const Holders = await ethers.getContractFactory("HoldersCollaborate");
    // Tokens, USD prices, start (in 20 seconds), end (in 5 minutes), level thresholds, minimums, maximums, rewards.
    holders = await Holders.deploy(
      [token1.target, token2.target],
      [2, 3],
      Number(currentTimestamp)+20,
      Number(currentTimestamp)+600,
      [1000, 2000],
      [10, 20],
      [100, 200],
      [1000, 2000]
    );

    await holders.waitForDeployment();

    // Calculate required initial balance
    requirePerTokenUSD = ((2000+20)*2000*1)/10000;
    token1Balance = String(requirePerTokenUSD*2);
    token2Balance = String(requirePerTokenUSD*3);
    await token1.transfer(holders.target, parseEther(token1Balance));
    await token2.transfer(holders.target, parseEther(token2Balance));

    // Transfer some tokens to collaborators
    await token1.transfer(holder1.address, parseEther("10000"));
    await token1.transfer(holder2.address, parseEther("10000"));
    await token2.transfer(holder1.address, parseEther("10000"));
    await token2.transfer(holder2.address, parseEther("10000"));

    // Give approval from collaborators to the contract (Holders doesn't transfer tokens to itself yet).
    await token1.connect(holder1).approve(holders.target, parseEther("1000"));
    await token2.connect(holder1).approve(holders.target, parseEther("1000"));
    await token1.connect(holder2).approve(holders.target, parseEther("1000"));
    await token2.connect(holder2).approve(holders.target, parseEther("1000"));
  });

  it("should have owner", async function () {
    expect(await holders.owner()).to.equal(owner.address);
  });

  it("should have owner as admin", async function () {
    expect(await holders.admins(owner)).to.be.true;
  });

  it("should not allow non-owner to set admin", async function () {
    await expect(
      holders.connect(holder1).setAdmin(holder2.address, true)
    ).to.be.revertedWithCustomError(holders, "OwnableUnauthorizedAccount");
  });

  it("should allow owner to set admin", async function () {
    await holders.setAdmin(holder1.address, true);
    expect(await holders.admins(holder1.address)).to.be.true;
  });

  it("should allow contribution when collaboration is active", async function () {
    await waitStart(holders);
    await holders.startCollaboration();
    await holders.connect(holder1).contribute(token1.target, parseEther("50"));
    const competitorId = await holders.getCompetitorId(holder1.address);
    expect(competitorId).to.equal(0);
  });

  it("should not allow contribution when collaboration is not active", async function () {
    await expect(holders.connect(holder1).contribute(token1.target, parseEther("50"))).to.be.revertedWith(
      "collaboration isn't active"
    );
  });

  it("should not allow contribution with invalid token", async function () {
    await waitStart(holders);
    await holders.startCollaboration();
    await expect(holders.contribute(zeroAddress(), parseEther("50"))).to.be.revertedWith("Invalid token");
  });

  it("should not allow contribution with token not in collaboration", async function () {
    await waitStart(holders);
    await holders.startCollaboration();
    await expect(holders.contribute(token3.target, parseEther("50"))).to.be.revertedWith(
      "No such token in collaboration"
    );
  });

  it("should allow changing collaboration status by owner", async function () {
    // Error message can be checked with:
    //holders.connect(holder1).changeStatus(1)
    await expect(holders.connect(holder1).changeStatus(1)).to.be.revertedWith("OwnableUnauthorizedAccount(\""+holder1.address+"\")");
    await holders.connect(owner).changeStatus(1);
    expect(await holders.status()).to.equal(1);
  });

  it("should allow updating levels by owner", async function () {
    await holders.updateLevels(
      [0, 1],
      [1500, 2500],
      [15, 25],
      [150, 250],
      [1500, 2500]
    );
    const newLevels0 = await holders.levels(0);
    const newLevels1 = await holders.levels(1);
    expect(newLevels0.treshhold).to.equal(1500);
    expect(newLevels1.treshhold).to.equal(2500);
    expect(newLevels0.minimum).to.equal(15);
    expect(newLevels1.minimum).to.equal(25);
    expect(newLevels0.maximum).to.equal(150);
    expect(newLevels1.maximum).to.equal(250);
    expect(newLevels0.reward).to.equal(1500);
    expect(newLevels1.reward).to.equal(2500);
  });

  it("should allow updating tokens by owner", async function () {
    await holders.updateTokens(
      [token2.target],
      [4]
    );
    const newTokens1 = await holders.tokens(1);
    expect(newTokens1.tokenUsdPrice).to.equal(4);
  });

  it("should allow updating start and end time by owner", async function () {
    const oldStart = await holders.start();
    const oldEnd = await holders.end();
    await holders.updateStartEndTime(
      Math.floor(Date.now() / 1000) + 120,
      Math.floor(Date.now() / 1000) + 3600
    );
    const newStart = await holders.start();
    const newEnd = await holders.end();
    expect(newStart).to.not.equal(oldStart);
    expect(newEnd).to.not.equal(oldEnd);
  });

  it("should allow adding new level by owner", async function () {
    await holders.addLevel(3000, 30, 300, 3000);
    const newLevels2 = await holders.levels(2);
    expect(newLevels2.treshhold).to.equal(3000);
    expect(newLevels2.minimum).to.equal(30);
    expect(newLevels2.maximum).to.equal(300);
    expect(newLevels2.reward).to.equal(3000);
  });

  it("should allow starting collaboration by owner", async function () {
    await waitStart(holders);
    await expect(holders.startCollaboration()).to.not.be.reverted;
    expect(await holders.status()).to.equal(1);
  });
});
