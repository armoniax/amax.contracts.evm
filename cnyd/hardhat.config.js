require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

const { types } = require("hardhat/config");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});


task("deployCnydToken", "Deploy CnydToken contract")
  .addOptionalParam("verify", "Whether to verify contract, true|false", false, types.boolean)
  .setAction(async (taskArgs) => {
    const contractName = "CnydToken";

    console.log("args: ", taskArgs)

    const ContractFactory = await hre.ethers.getContractFactory(contractName);
    const contract = await ContractFactory.deploy();

    await contract.deployed();

    console.log("contract", contractName, "deployed to:", contract.address);

    if (taskArgs.verify) {
      await hre.run("verify:verify", {
        address: contract.address
      });
    }
  });

task("deployCnydAdmin", "Deploy CnydAdmin contract")
  .addOptionalParam("verify", "Whether to verify contract, true|false", false, types.boolean)
  .setAction(async (taskArgs) => {
    const contractName = "CnydAdmin";

    console.log("args: ", taskArgs)

    const ContractFactory = await hre.ethers.getContractFactory(contractName);
    const contract = await ContractFactory.deploy();

    await contract.deployed();

    console.log("contract", contractName, "deployed to:", contract.address);

    if (taskArgs.verify) {
      await hre.run("verify:verify", {
        address: contract.address
      });
    }
  });

task("initCnydAdmin", "Initialize CnydAdmin contract")
  .addParam("admin", "The address of CnydAdmin contract")
  .addParam("token", "The address of CnydToken contract")
  .addParam("approvers", "Address array of approvers, JSON array format", "[]", types.json)
  .setAction(async (taskArgs) => {
    const adminContractName = "CnydAdmin";
    const tokenContractName = "CnydToken";

    console.log("args: ", taskArgs)

    if (!hre.ethers.utils.isAddress(taskArgs.admin)) {
      throw Error ('Invalid token address:', taskArgs.token)
    }
    if (!hre.ethers.utils.isAddress(taskArgs.token)) {
      throw Error ('Invalid token address:', taskArgs.token)
    }

    taskArgs.approvers.forEach(element => {
      if (!hre.ethers.utils.isAddress(element)) {
        throw Error ('Invalid approver address:', element)
      }
  });

    const adminContract = await hre.ethers.getContractAt(adminContractName, taskArgs.admin);
    const tokenContract = await hre.ethers.getContractAt(tokenContractName, taskArgs.token);
    
    const isInit = await adminContract.isInit()
    if (isInit) {
      throw Error ('CnydAdmin has been init')
    }
    
    const curTokenOwner = await tokenContract.owner()
    if (curTokenOwner == taskArgs.admin) {
      throw Error ('The owner of CnydToken is already CnydAdmin')
    }

    const curTokenProposedOwner = await tokenContract.proposedOwner()
    if (curTokenProposedOwner != taskArgs.admin) {
      console.log("Propose owner of CnydToken")
      await tokenContract.proposeOwner(taskArgs.admin)
    }

    console.log("Init CnydAdmin ...")
    await adminContract.init(taskArgs.token, taskArgs.approvers)
    
    console.log("Init CnydAdmin completed")
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const network_accounts = process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [];

// chainId: https://chainlist.org/

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
    },
    goerli: {
      url: process.env.GOERLI_URL || "",
      accounts: network_accounts,
    },
    bsc_test: {
      url: process.env.BSC_TEST_URL || "https://data-seed-prebsc-2-s3.binance.org:8545",
      chainId: 97,
      accounts: network_accounts,
    },
    bsc_main: {
      url: process.env.BSC_MAIN_URL || "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: "auto",
      accounts: network_accounts,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 20000
  },
};
