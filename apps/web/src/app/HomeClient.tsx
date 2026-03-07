'use client'

import { useAccount } from 'wagmi'
import Link from 'next/link'
import { WalletRecord } from '@/components/WalletRecord'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { RecentActivity } from '@/components/RecentActivity'

export function HomeClient() {
  const { address, isConnected } = useAccount()

  return (
    <ErrorBoundary>
    <div>
      <h1>Clout</h1>
      <p>On-chain performance challenges: stake, compete, and prove your edge.</p>

      <div className="flex flex-col sm:flex-row gap-4 my-8">
        <Link href="/challenges" className="flex-1 p-4 border rounded" aria-label="Browse challenges">
          <strong>Challenges</strong>
          <p>Browse, create, and manage PvP escrow challenges.</p>
        </Link>
        <Link href="/pools" className="flex-1 p-4 border rounded" aria-label="Browse pools">
          <strong>Pools</strong>
          <p>Explore multi-participant challenge pools.</p>
        </Link>
      </div>

      {isConnected && address ? (
        <WalletRecord address={address} />
      ) : (
        <p>Connect your wallet to view your stats.</p>
      )}

      <div className="mt-8">
        <RecentActivity />
      </div>
    </div>
    </ErrorBoundary>
  )
}
