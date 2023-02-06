require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*", // Match any network id
      timeoutBlocks: 200,
      skipDryRun: true,
    },
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/abis/',
  migrations_directory: './migrations',
  compilers: {
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      version: '0.8.11',
    }
  }
}
