'use client'

import { useReadContract, useReadContracts } from 'wagmi'
import { hexToString } from 'viem'
import { ChallengeState } from '@clout/types'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { ChallengeStateBadge } from '@/components/StateBadge'

const ACTIVE_STATES = new Set([
  ChallengeState.CREATED,
  ChallengeState.ACCEPTED,
  ChallengeState.SUBMITTED,
  ChallengeState.DISPUTED,
  ChallengeState.RESOLVED,
])

type ChallengeRow = {
  id: number
  creator: `0x${string}`
  opponent: `0x${string}`
  stakeAmount: bigint
  state: number
  gameId: `0x${string}`
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function ChallengesClient() {
  const { data: countData, isLoading: countLoading } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'challengeCount',
  })

  const count = Number(countData ?? 0n)

  const { data: challengeResults, isLoading: challengesLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'challenges' as const,
      args: [BigInt(i + 1)] as const, // IDs are 1-indexed; slot 0 is permanently empty
    })),
    query: { enabled: count > 0 },
  })

  const isLoading = countLoading || challengesLoading

  // challenges() returns a tuple: [creator, opponent, designatedResolver, token, stakeAmount, state, gameId, ...]
  // Indices: 0=creator, 1=opponent, 2=designatedResolver, 3=token, 4=stakeAmount, 5=state, 6=gameId
  const activeChallenges: ChallengeRow[] = (challengeResults ?? [])
    .map((r, i) => {
      if (!r.result) return null
      const c = r.result as readonly unknown[]
      return {
        id: i + 1,
        creator: c[0] as `0x${string}`,
        opponent: c[1] as `0x${string}`,
        stakeAmount: c[4] as bigint,
        state: c[5] as number,
        gameId: c[6] as `0x${string}`,
      }
    })
    .filter((c): c is ChallengeRow => c !== null && ACTIVE_STATES.has(c.state))

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <h1>Challenges</h1>
        <Link href="/challenges/create">+ Create Challenge</Link>
      </div>

      {isLoading && (
        <div className="flex flex-col gap-3 mt-3">
          {[0, 1, 2].map((i) => (
            <div key={i} className="border rounded p-3 flex flex-col gap-2">
              <div className="flex justify-between">
                <Skeleton width="2rem" height="1rem" />
                <Skeleton width="5rem" height="1rem" />
              </div>
              <Skeleton width="70%" height="1rem" />
              <Skeleton width="70%" height="1rem" />
              <Skeleton width="40%" height="1rem" />
              <Skeleton width="55%" height="1rem" />
            </div>
          ))}
        </div>
      )}

      {!isLoading && activeChallenges.length === 0 && (
        <p>No active challenges. <Link href="/challenges/create">Create one</Link></p>
      )}

      {!isLoading && activeChallenges.length > 0 && (
        <>
          <p>Showing active challenges ({activeChallenges.length} of {count})</p>

          {/* Mobile card list */}
          <div className="flex flex-col gap-3 md:hidden mt-3">
            {activeChallenges.map((c) => (
              <Link
                key={c.id}
                href={`/challenges/${c.id}`}
                className="border rounded p-3 flex flex-col gap-1 block hover:bg-gray-50 cursor-pointer"
              >
                <div className="flex justify-between">
                  <span className="font-semibold">#{c.id}</span>
                  <ChallengeStateBadge state={c.state} />
                </div>
                <div className="text-sm">Creator: {truncateAddr(c.creator)}</div>
                <div className="text-sm">Opponent: {truncateAddr(c.opponent)}</div>
                <div className="text-sm">Stake: {(Number(c.stakeAmount) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">Game: {hexToString(c.gameId).replace(/\0+$/, '')}</div>
              </Link>
            ))}
          </div>

          {/* Desktop grid */}
          <div className="hidden md:block overflow-x-auto mt-3">
            <div style={{ width: '100%' }}>
              {/* Header row */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', fontWeight: 'bold' }}>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>ID</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Creator</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Opponent</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Stake</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>State</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Game</span>
              </div>
              {/* Data rows — each row is a <Link> */}
              {activeChallenges.map((c) => (
                <Link
                  key={c.id}
                  href={`/challenges/${c.id}`}
                  className="hover:bg-gray-50 cursor-pointer"
                  style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)' }}
                >
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{c.id}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(c.creator)}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(c.opponent)}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {(Number(c.stakeAmount) / 1_000_000).toFixed(2)} USDC
                  </span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    <ChallengeStateBadge state={c.state} />
                  </span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {hexToString(c.gameId).replace(/\0+$/, '')}
                  </span>
                </Link>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
