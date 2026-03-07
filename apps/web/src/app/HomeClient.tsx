'use client'

import { useAccount } from 'wagmi'
import { useReadContract } from 'wagmi'
import Link from 'next/link'
import { WalletRecord } from '@/components/WalletRecord'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { RecentActivity } from '@/components/RecentActivity'
import { cloutEscrowAbi, cloutPoolAbi, ESCROW_ADDRESS, POOL_ADDRESS } from '@/lib/contracts'

function HeroSection() {
  return (
    <section className="py-24 sm:py-32 text-center">
      <h1 className="text-5xl sm:text-7xl font-extrabold tracking-tight leading-tight">
        The conviction market for the creator economy
      </h1>
      <p className="mt-6 text-xl sm:text-2xl text-zinc-400 max-w-2xl mx-auto">
        Stake on outcomes. Build your track record. Prove your edge.
      </p>
      <div className="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
        <Link
          href="/challenges"
          className="inline-flex items-center justify-center px-8 py-4 text-base font-semibold rounded-lg bg-white text-black hover:bg-zinc-100 dark:bg-white dark:text-black transition-colors"
        >
          Browse Challenges
        </Link>
        <Link
          href="/pools"
          className="inline-flex items-center justify-center px-8 py-4 text-base font-semibold rounded-lg border border-zinc-600 text-white hover:bg-zinc-800 transition-colors"
        >
          Explore Pools
        </Link>
      </div>
    </section>
  )
}

function StatsSection() {
  const { data: challengeCount, isLoading: loadingChallenges } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'challengeCount',
  })
  const { data: poolCount, isLoading: loadingPools } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'poolCount',
  })

  const stats = [
    { label: 'Challenges', value: loadingChallenges ? '…' : Number(challengeCount ?? 0n).toString() },
    { label: 'Pools', value: loadingPools ? '…' : Number(poolCount ?? 0n).toString() },
  ]

  return (
    <section className="py-12 border-t border-zinc-800">
      <dl className="flex flex-col sm:flex-row gap-8 justify-center text-center">
        {stats.map(({ label, value }) => (
          <div key={label}>
            <dt className="text-zinc-400 text-sm uppercase tracking-widest">{label}</dt>
            <dd className="mt-1 text-4xl font-bold tabular-nums">{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}

export function HomeClient() {
  const { address, isConnected } = useAccount()

  return (
    <ErrorBoundary>
      <div className="max-w-5xl mx-auto px-4 sm:px-8">
        <HeroSection />
        <StatsSection />
        <section className="py-12 border-t border-zinc-800">
          {isConnected && address ? (
            <WalletRecord address={address} />
          ) : (
            <p className="text-center text-zinc-400">Connect your wallet to view your on-chain stats.</p>
          )}
        </section>
        <section className="py-12 border-t border-zinc-800">
          <RecentActivity />
        </section>
      </div>
    </ErrorBoundary>
  )
}
