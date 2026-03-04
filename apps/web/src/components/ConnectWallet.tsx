'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'

const CONNECTOR_LABELS: Record<string, string> = {
  coinbaseWallet: 'Coinbase Wallet (Smart Wallet)',
  walletConnect: 'WalletConnect',
  injected: 'MetaMask (injected)',
}

export function ConnectWallet() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected && address) {
    return (
      <div>
        <span>{address.slice(0, 6)}…{address.slice(-4)}</span>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div>
      {connectors.map((connector) => (
        <button key={connector.id} onClick={() => connect({ connector })}>
          {CONNECTOR_LABELS[connector.id] ?? connector.name}
        </button>
      ))}
    </div>
  )
}
