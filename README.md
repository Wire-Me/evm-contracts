# About

This repository contains the source code for WireMe's EVM smart contracts, unit tests for these contracts, and scripts
to compile and deploy the contracts to the Sepolia testnet and ETH mainnet. It also uses ENV vars to configure the 
private keys used to deploy contracts.

# Deployment
Use Hardhat Ignition to deploy smart contracts

To localhost
```bash
npx hardhat ignition deploy ./ignition/modules/Lock.ts --network localhost
```
To Sepolia
```bash
npx hardhat ignition deploy ./ignition/modules/Lock.ts --network sepolia
```
