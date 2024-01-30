const { zeroAddress } = require("@nomicfoundation/ethereumjs-util");
const { expect } = require("chai");
const { ethers, waffle, upgrades } = require("hardhat");
const { parseUnits, parseEther } = ethers;

describe("Holders", function () {
  let holders;
  let owner;
  let holder1;
  let holder2;

  beforeEach(async function () {
    [owner, holder1, holder2] = await ethers.getSigners();
    const Holders = await ethers.deployContract("HoldersCollaborate");
    holders = await Holders.waitForDeployment();
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
});
