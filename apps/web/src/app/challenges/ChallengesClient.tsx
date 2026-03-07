'use client'

import { useState, useMemo, useEffect } from 'react'
import { useReadContract, useReadContracts } from 'wagmi'
import { useAccount } from 'wagmi'
import { hexToString } from 'viem'

function safeHexToLabel(hex: `0x${string}`): string {
  try { return hexToString(hex).replace(/\0+$/, '') || hex.slice(0, 10) + '…' } catch { return hex.slice(0, 10) + '…' }
}
import { ChallengeState } from '@clout/types'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { ChallengeStateBadge } from '@/components/StateBadge'

const CHALLENGE_FILTER_SETS: Record<string, Set<number>> = {
  open:     new Set([ChallengeState.CREATED]),
  active:   new Set([ChallengeState.ACCEPTED, ChallengeState.SUBMITTED]),
  resolved: new Set([ChallengeState.FINALIZED, ChallengeState.VOIDED]),
}

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
  const [filter, setFilter] = useState<'all' | 'open' | 'active' | 'resolved'>('all')
  const [sortAsc, setSortAsc] = useState(false)
  const { address, isConnected } = useAccount()
  const [myView, setMyView] = useState(false)

  useEffect(() => {
    const v = sessionStorage.getItem('clout:challenges:myView')
    if (v === 'true') setMyView(true)
  }, [])

  useEffect(() => {
    sessionStorage.setItem('clout:challenges:myView', String(myView))
  }, [myView])

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
  const allChallenges: ChallengeRow[] = (challengeResults ?? [])
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
    .filter((c): c is ChallengeRow => c !== null)

  const displayChallenges = useMemo(() => {
    return allChallenges
      .filter(c => filter === 'all' || CHALLENGE_FILTER_SETS[filter].has(c.state))
      .filter(c => {
        if (!myView || !address) return true
        const addrLower = address.toLowerCase()
        return c.creator.toLowerCase() === addrLower || c.opponent.toLowerCase() === addrLower
      })
      .sort((a, b) => sortAsc ? a.id - b.id : b.id - a.id)
  }, [allChallenges, filter, sortAsc, myView, address])

  const filterButtons: { label: string; value: 'all' | 'open' | 'active' | 'resolved' }[] = [
    { label: 'All', value: 'all' },
    { label: 'Open', value: 'open' },
    { label: 'Active', value: 'active' },
    { label: 'Resolved', value: 'resolved' },
  ]

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <h1>Challenges</h1>
        <Link href="/challenges/create" aria-label="Create a new challenge">+ Create Challenge</Link>
      </div>

      {/* Filter + sort controls */}
      <div className="flex flex-wrap items-center gap-2 mb-3">
        {filterButtons.map(btn => (
          <button
            key={btn.value}
            onClick={() => setFilter(btn.value)}
            aria-label={`Filter challenges: ${btn.label}`}
            aria-pressed={filter === btn.value}
            style={filter === btn.value ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
          >
            {btn.label}
          </button>
        ))}
        <button
          onClick={() => setSortAsc(s => !s)}
          aria-label={sortAsc ? 'Sort: oldest first — click to sort newest first' : 'Sort: newest first — click to sort oldest first'}
          style={{ marginLeft: 'auto' }}
        >
          ↕ {sortAsc ? 'Oldest first' : 'Newest first'}
        </button>
        {isConnected && (
          <div style={{ display: 'flex', gap: '0.5rem', marginLeft: '1rem' }}>
            <button
              onClick={() => setMyView(false)}
              aria-label="Show all challenges"
              aria-pressed={!myView}
              style={!myView ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
            >
              All Challenges
            </button>
            <button
              onClick={() => setMyView(true)}
              aria-label="Show my challenges"
              aria-pressed={myView}
              style={myView ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
            >
              My Challenges
            </button>
          </div>
        )}
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

      {!isLoading && displayChallenges.length === 0 && (
        <p>
          {myView
            ? 'You have no challenges yet.'
            : filter === 'all'
              ? <><span>No challenges yet. </span><Link href="/challenges/create" aria-label="Create your first challenge">Create one</Link></>
              : 'No challenges match this filter.'
          }
        </p>
      )}

      {!isLoading && displayChallenges.length > 0 && (
        <>
          <p>Showing {displayChallenges.length} of {allChallenges.length} challenges</p>

          {/* Mobile card list */}
          <div className="flex flex-col gap-3 md:hidden mt-3">
            {displayChallenges.map((c) => (
              <Link
                key={c.id}
                href={`/challenges/${c.id}`}
                aria-label={`View challenge #${c.id}`}
                className="border rounded p-3 flex flex-col gap-1 block hover:bg-gray-50 cursor-pointer"
              >
                <div className="flex justify-between">
                  <span className="font-semibold">#{c.id}</span>
                  <ChallengeStateBadge state={c.state} />
                </div>
                <div className="text-sm">Creator: {truncateAddr(c.creator)}</div>
                <div className="text-sm">Opponent: {truncateAddr(c.opponent)}</div>
                <div className="text-sm">Stake: {(Number(c.stakeAmount) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">Game: {safeHexToLabel(c.gameId)}</div>
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
              {displayChallenges.map((c) => (
                <Link
                  key={c.id}
                  href={`/challenges/${c.id}`}
                  aria-label={`View challenge #${c.id}`}
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
                    {safeHexToLabel(c.gameId)}
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
