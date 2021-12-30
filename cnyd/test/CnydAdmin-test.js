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
  let users;

  let CnydToken;
  let cnydToken;
  let CnydAdmin;
  let cnydAdmin;

  beforeEach(async () => {
    // init global variants
    accounts = await ethers.getSigners();
    expect(accounts).length.greaterThan(11);
    // console.log("accounts:", accounts.length);
    owner = accounts[0];
    approvers = accounts.slice(1, 4);
    proposers = accounts.slice(5, 8);
    users = accounts.slice(9, 10);

    initApprovers = [
      approvers[0].address,
      approvers[1].address,
      approvers[2].address,
    ];

    CnydToken = await ethers.getContractFactory("CnydToken");
    CnydAdmin = await ethers.getContractFactory("CnydAdmin");

    cnydToken = await CnydToken.connect(owner).deploy();
    await cnydToken.deployed();
    // console.log("cnydToken:", cnydToken);

    cnydAdmin = await CnydAdmin.connect(owner).deploy(cnydToken.address, initApprovers);
    await cnydAdmin.deployed();

    await cnydToken.proposeOwner(cnydAdmin.address);
    expect(await cnydToken.proposedOwner()).equal(cnydAdmin.address);

    await cnydAdmin.takeTokenOwnership();
    expect(await cnydToken.owner()).equal(cnydAdmin.address);

    await cnydAdmin.setTokenAdmin(cnydAdmin.address);
    expect(await cnydToken.admin()).equal(cnydAdmin.address);
  });

  it("test Mint and Burn Proposal", async function () {

    await cnydAdmin.connect(owner).setProposer(proposers[0].address, true);
    expect(await cnydAdmin.proposers(proposers[0].address)).equal(true);

    const proposeMintReceipt = await (await cnydAdmin.connect(proposers[0]).proposeMint(users[0].address, 10000_000000)).wait(1);
    expect(proposeMintReceipt.events.length).to.equal(1);
    expect(proposeMintReceipt.events[0].event).to.equal('MintProposed');

    let blockTime = B((await ethers.provider.getBlock(proposeMintReceipt.blockNumber)).timestamp);

    expect(proposeMintReceipt.events[0].args).to.deep.equal([proposers[0].address, users[0].address, B(10000_000000)]);
    expect(await cnydAdmin.getMintProposal(proposers[0].address)).to.deep.equal([users[0].address, B(10000_000000), blockTime, []]);
    await cnydAdmin.connect(approvers[0]).approveMint(proposers[0].address, true, users[0].address, 10000_000000);
    await cnydAdmin.connect(approvers[1]).approveMint(proposers[0].address, true, users[0].address, 10000_000000);
    expect((await cnydAdmin.getMintProposal(proposers[0].address))[3]).to.deep.equal([approvers[0].address, approvers[1].address]);

    const mintApproveReceipt = await (await cnydAdmin.connect(approvers[2]).approveMint(
        proposers[0].address, true, users[0].address, 10000_000000)).wait();

    expect(mintApproveReceipt.events[0].event).to.equal('MintApproved');
    expect(await cnydToken.balanceOf(users[0].address)).equal(10000_000000);
    expect(await cnydToken.totalSupply()).equal(10000_000000);

    // transfer burned amount to cnyd contract
    await cnydToken.connect(users[0]).transfer(cnydToken.address, 1000_000000)
    expect(await cnydToken.balanceOf(users[0].address)).equal(9000_000000);
    expect(await cnydToken.balanceOf(cnydToken.address)).equal(1000_000000);

    // proposeBurn
    const proposeBurnReceipt = await (await cnydAdmin.connect(proposers[0]).proposeBurn(100_000000)).wait(1);
    expect(proposeBurnReceipt.events.length).to.equal(1);
    expect(proposeBurnReceipt.events[0].event).to.equal('BurnProposed');
    expect(proposeBurnReceipt.events[0].args).to.deep.equal([proposers[0].address, B(100_000000)]);

    blockTime = B((await ethers.provider.getBlock(proposeBurnReceipt.blockNumber)).timestamp);

    expect(await cnydAdmin.getBurnProposal(proposers[0].address)).to.deep.equal([B(100_000000), blockTime, []]);
    await cnydAdmin.connect(approvers[0]).approveBurn(proposers[0].address, true, 100_000000);
    await cnydAdmin.connect(approvers[1]).approveBurn(proposers[0].address, true, 100_000000);
    expect((await cnydAdmin.getBurnProposal(proposers[0].address))[2]).to.deep.equal([approvers[0].address, approvers[1].address]);

    const burnApproveReceipt = await (await cnydAdmin.connect(approvers[2]).approveBurn(
        proposers[0].address, true, 100_000000)).wait();

    expect(burnApproveReceipt.events[0].event).to.equal('BurnApproved');
    expect(await cnydToken.balanceOf(cnydToken.address)).equal(900_000000);
    expect(await cnydToken.totalSupply()).equal(9900_000000);

  });

});
