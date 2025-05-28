// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TransactionRelayModule = buildModule("TransactionRelayModule", (m) => {
  const symbol = m.getParameter("symbol", 'ETH')
  const fee = m.getParameter("fee", 100n)

  const transactionRelay = m.contract("TransactionRelay", [symbol, fee])

  return { transactionRelay }
});

export default TransactionRelayModule;
