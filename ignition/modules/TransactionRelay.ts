// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TransactionRelayModule = buildModule("TransactionRelayModule", (m) => {
  const transactionRelay = m.contract("TransactionRelay", []);

  return { transactionRelay };
});

export default TransactionRelayModule;
