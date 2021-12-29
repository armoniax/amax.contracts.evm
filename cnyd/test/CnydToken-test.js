const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

// https://getwaffle.io/
// https://ethereum-waffle.readthedocs.io/en/latest/
// https://github.com/EthWorks/Waffle

const B = BigNumber.from;

describe("CnydToken", function () {
  // global variants
  let accounts;    
  let owner;
  let admin;
  let users;

  beforeEach(async () => {
    // init global variants
    accounts = await hre.ethers.getSigners();    
    expect(accounts).length.greaterThan(10);
    owner = accounts[0];
    admin = accounts[1];
    users = accounts.slice(2, 5);
  });

  it("test CnydToken", async function () {
    const Cnyd = await ethers.getContractFactory("CnydToken");

    const cnyd = await Cnyd.connect(owner).deploy();
    await cnyd.deployed();
    expect(await cnyd.owner()).equal(owner.address);
    expect(await cnyd.admin()).equal(owner.address);
    await cnyd.connect(owner).setAdmin(admin.address);
    expect(await cnyd.admin()).equal(admin.address);

    // mint
    await cnyd.connect(admin).mint(users[0].address, 10000_000000);
    expect(await cnyd.balanceOf(users[0].address)).equal(10000_000000);
    expect(await cnyd.totalSupply()).equal(10000_000000);    


  });
});
