const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

// https://getwaffle.io/
// https://ethereum-waffle.readthedocs.io/en/latest/
// https://github.com/EthWorks/Waffle

const B = BigNumber.from;

describe("CnydAdmin", function () {
  // global variants
  let accounts;    
  let owner;
  let approvers;
  let proposers;
  let initApprovers;

  beforeEach(async () => {
    // init global variants
    accounts = await hre.ethers.getSigners();
    expect(accounts).length.greaterThan(10);

    owner = accounts[0];
    approvers = accounts.slice(1, 4);
    proposers = accounts.slice(5, 8);
    initApprovers = [
      approvers[0].address,
      approvers[1].address,
      approvers[2].address,
    ];
  });

  it("test CnydAdmin", async function () {
    const CnydToken = await ethers.getContractFactory("CnydToken");

    const cnydToken = await CnydToken.connect(owner).deploy();
    await cnydToken.deployed();
    // console.log("cnydToken:", cnydToken);

    const CnydAdmin = await ethers.getContractFactory("CnydAdmin");

    const cnydAdmin = await CnydAdmin.connect(owner).deploy(cnydToken.address, initApprovers);
    await cnydAdmin.deployed();

    await cnydToken.proposeOwner(cnydAdmin.address);
    expect(await cnydToken.proposedOwner()).equal(cnydAdmin.address);

    await cnydAdmin.takeTokenOwnership();
    expect(await cnydToken.owner()).equal(cnydAdmin.address);

    await cnydAdmin.setTokenAdmin(cnydAdmin.address);
    expect(await cnydToken.admin()).equal(cnydAdmin.address);

    // await cnydToken.setOwner(cnydAdmin.address);   
    // expect(await cnydToken.owner()).equal(owner.address);
    // expect(await cnydToken.holder()).equal(owner.address);
    // expect(await cnydToken.approvers(2)).equal(initApprovers[2]);

    // console.log("deploy contract. approvers:", initApprovers);

    // // add propose by approver
    // console.log(
    //   "set proposer", proposers[0].address,
    //   "by approver", approvers[0].address
    // );
    // await cnyd.connect(approvers[0]).setProposer(proposers[0].address, true);
    // expect(await cnyd.proposers(proposers[0].address)).equal(true);

    // console.log("propose mint. amount:", 10000_0000);
    // await cnyd.connect(proposers[0]).proposeMint(10000_0000);
    // const [mintAmount] = await cnyd.getMintProposal(proposers[0].address);
    // expect(mintAmount).equal(100000000);

    // console.log("approve mint. amount:", 10000_0000);
    // await cnyd.connect(approvers[0]).approveMint(proposers[0].address, true, 10000_0000);
    // await cnyd.connect(approvers[1]).approveMint(proposers[0].address, true, 10000_0000);
    // const [,, retApprovers1] = await cnyd.getMintProposal(proposers[0].address);
    // expect(retApprovers1).to.deep.equal([approvers[0].address, approvers[1].address]);

    // await cnyd.connect(approvers[2]).approveMint(proposers[0].address, true, 10000_0000);
    // expect(await cnyd.getMintProposal(proposers[0].address)).to.deep.equal([B(0), B(0), []]);
    // expect(await cnyd.totalSupply()).to.equal(10000_0000);
    // expect(await cnyd.balanceOf(owner.address)).to.equal(10000_0000);

  });
});
