'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { useTokenBalance } from '@/lib/useTokenBalance'
import { formatBalance } from '@/lib/utils'

const CONNECTOR_LABELS: Record<string, string> = {
  coinbaseWallet: 'Coinbase Wallet (Smart Wallet)',
  walletConnect: 'WalletConnect',
  injected: 'MetaMask (injected)',
}

export function ConnectWallet() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const { data: balance } = useTokenBalance()

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm">{address.slice(0, 6)}…{address.slice(-4)} | {balance !== undefined ? formatBalance(balance as bigint) : '—'}</span>
        <button
          onClick={() => disconnect()}
          className="text-sm px-3 py-1.5 border rounded"
        >
          Disconnect
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col sm:flex-row gap-2">
      {connectors.map((connector) => (
        <button
          key={connector.id}
          onClick={() => connect({ connector })}
          className="w-full sm:w-auto px-3 py-2 text-sm border rounded"
        >
          {CONNECTOR_LABELS[connector.id] ?? connector.name}
        </button>
      ))}
    </div>
  )
}
