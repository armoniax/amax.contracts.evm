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
  let users;

  beforeEach(async () => {
    // init global variants
    accounts = await hre.ethers.getSigners();    
    expect(accounts).length.greaterThan(10);
    owner = accounts[0];
    users = accounts.slice(1, 3);
  });

  it("test CnydToken", async function () {
    const Cnyd = await ethers.getContractFactory("CnydToken");

    const cnyd = await Cnyd.connect(owner).deploy();
    await cnyd.deployed();
    expect(await cnyd.owner()).equal(owner.address);

    // mint
    await cnyd.connect(owner).mint(users[0].address, 10000_000000);
    expect(await cnyd.balanceOf(users[0].address)).equal(10000_000000);
    expect(await cnyd.totalSupply()).equal(10000_000000);    

    // transfer
    await cnyd.connect(users[0]).transfer(users[1].address, 100_000000);
    expect(await cnyd.balanceOf(users[0].address)).equal(9900_000000);
    expect(await cnyd.balanceOf(users[1].address)).equal(100_000000);
    expect(await cnyd.totalSupply()).equal(10000_000000);  


    // burn
    await cnyd.connect(users[0]).transfer(cnyd.address, 100_000000);
    expect(await cnyd.balanceOf(cnyd.address)).equal(100_000000);
    await cnyd.connect(owner).burn(100_000000);
    expect(await cnyd.balanceOf(cnyd.address)).equal(0);
    expect(await cnyd.totalSupply()).equal(10000_000000 - 100_000000);  
  });
});
