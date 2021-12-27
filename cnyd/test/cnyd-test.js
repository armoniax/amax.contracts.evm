const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

// https://getwaffle.io/
// https://ethereum-waffle.readthedocs.io/en/latest/
// https://github.com/EthWorks/Waffle

const B = BigNumber.from;

describe("Cnyd", function () {
  // global variants
  let accounts;    
  let owner;
  let approvers;
  let proposers;
  let initApprovers;

  beforeEach(async () => {
    // init global variants
    accounts = await hre.ethers.getSigners();
    owner = accounts[0];
    approvers = accounts.slice(1, 4);
    proposers = accounts.slice(5, 8);
    initApprovers = [
      approvers[0].address,
      approvers[1].address,
      approvers[2].address,
    ];
  });

  it("test Cnyd", async function () {
    const Cnyd = await ethers.getContractFactory("Cnyd");
    expect(accounts).length.greaterThan(10);

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
    await cnyd.connect(approvers[0]).approveMint(proposers[0].address, true, 10000_0000);
    await cnyd.connect(approvers[1]).approveMint(proposers[0].address, true, 10000_0000);
    const [,, retApprovers1] = await cnyd.getMintProposal(proposers[0].address);
    expect(retApprovers1).to.deep.equal([approvers[0].address, approvers[1].address]);

    await cnyd.connect(approvers[2]).approveMint(proposers[0].address, true, 10000_0000);
    expect(await cnyd.getMintProposal(proposers[0].address)).to.deep.equal([B(0), B(0), []]);
    expect(await cnyd.totalSupply()).to.equal(10000_0000);
    expect(await cnyd.balanceOf(owner.address)).to.equal(10000_0000);

  });
});
