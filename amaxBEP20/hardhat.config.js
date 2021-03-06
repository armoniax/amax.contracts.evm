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


task("deployAmaxBEP20", "Deploy AmaxBEP20 contract")
  .addOptionalParam("verify", "Whether to verify contract, true|false", false, types.boolean)
  .setAction(async (taskArgs) => {
    const contractName = "AmaxBEP20";
    console.log("args: ", taskArgs)
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    await hre.run('compile');

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

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const network_accounts = process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [];

// chainId: https://chainlist.org/

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.12",
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
      url: process.env.BSC_MAIN_URL || "https://bsc-dataseed4.ninicoin.io",
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
