'use client'

import { useAccount } from 'wagmi'
import Link from 'next/link'
import { WalletRecord } from '@/components/WalletRecord'

export default function Home() {
  const { address, isConnected } = useAccount()

  return (
    <div style={{ padding: '2rem' }}>
      <h1>Clout</h1>
      <p>On-chain performance challenges: stake, compete, and prove your edge.</p>

      <div style={{ display: 'flex', gap: '1rem', margin: '2rem 0' }}>
        <Link href="/challenges" style={{ display: 'block', padding: '1rem', border: '1px solid #ccc' }}>
          <strong>Challenges</strong>
          <p>Browse, create, and manage PvP escrow challenges.</p>
        </Link>
        <Link href="/pools" style={{ display: 'block', padding: '1rem', border: '1px solid #ccc' }}>
          <strong>Pools</strong>
          <p>Explore multi-participant challenge pools.</p>
        </Link>
      </div>

      {isConnected && address ? (
        <WalletRecord address={address} />
      ) : (
        <p>Connect your wallet to view your stats.</p>
      )}
    </div>
  )
}
