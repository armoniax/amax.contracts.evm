const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

// https://getwaffle.io/
// https://ethereum-waffle.readthedocs.io/en/latest/
// https://github.com/EthWorks/Waffle

describe("Cnyd", function () {
  // global variants

  beforeEach(async () => {
    // init global variants
  });

  it("test Cnyd", async function () {
    const Cnyd = await ethers.getContractFactory("Cnyd");
    const accounts = await hre.ethers.getSigners();
    expect(accounts).length.greaterThan(10);
    const owner = accounts[0];
    const approvers = accounts.slice(1, 4);
    const proposers = accounts.slice(5, 8);
    const initApprovers = [
      approvers[0].address,
      approvers[1].address,
      approvers[2].address,
    ];

    console.log("deploy contract. approvers:", initApprovers);
    const cnyd = await Cnyd.connect(owner).deploy(initApprovers);
    await cnyd.deployed();
    expect(await cnyd.owner()).equal(owner.address);
    expect(await cnyd.holder()).equal(owner.address);
    expect(await cnyd.approvers(2)).equal(initApprovers[2]);

    // add propose by approver
    console.log(
      "set proposer", proposers[0].address,
      "by approver", approvers[0].address
    );
    await cnyd.connect(approvers[0]).setProposer(proposers[0].address, true);
    expect(await cnyd.proposers(proposers[0].address)).equal(true);

    console.log("propose mint. amount:", 10000_0000);
    await cnyd.connect(proposers[0]).proposeMint(10000_0000);
    const [mintAmount] = await cnyd.getMintProposal(proposers[0].address);
    expect(mintAmount).equal(100000000);

    console.log("approve mint. amount:", 10000_0000);
    await cnyd
      .connect(approvers[0])
      .approveMint(proposers[0].address, true, 10000_0000);
    const [,, retApprovers1] = await cnyd.getMintProposal(proposers[0].address);
    expect(retApprovers1[0]).to.equal(approvers[0].address);
  });
});
