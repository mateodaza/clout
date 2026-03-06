'use client'

import { useState, useMemo, useEffect } from 'react'
import { useReadContract, useReadContracts } from 'wagmi'
import { useAccount } from 'wagmi'
import { PoolState } from '@clout/types'
import { cloutPoolAbi, POOL_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { PoolStateBadge } from '@/components/StateBadge'
import { formatTimestamp } from '@/lib/utils'

const POOL_FILTER_SETS: Record<string, Set<number>> = {
  open:     new Set([PoolState.OPEN]),
  closed:   new Set([PoolState.CLOSED, PoolState.SUBMITTED, PoolState.DISPUTED]),
  resolved: new Set([PoolState.FINALIZED, PoolState.VOIDED]),
}

type PoolRow = {
  id: number
  host: `0x${string}`
  state: number
  yesTotal: bigint
  noTotal: bigint
  eventStart: bigint
  eventEnd: bigint
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function PoolsClient() {
  const [filter, setFilter] = useState<'all' | 'open' | 'closed' | 'resolved'>('all')
  const [sortAsc, setSortAsc] = useState(false)
  const { address, isConnected } = useAccount()
  const [myView, setMyView] = useState(false)

  useEffect(() => {
    const v = sessionStorage.getItem('clout:pools:myView')
    if (v === 'true') setMyView(true)
  }, [])

  useEffect(() => {
    sessionStorage.setItem('clout:pools:myView', String(myView))
  }, [myView])

  const { data: countData, isLoading: countLoading } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'poolCount',
  })

  const count = Number(countData ?? 0n)

  const { data: poolResults, isLoading: poolsLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      address: POOL_ADDRESS,
      abi: cloutPoolAbi,
      functionName: 'pools' as const,
      args: [BigInt(i + 1)] as const, // IDs are 1-indexed
    })),
    query: { enabled: count > 0 },
  })

  const { data: stakesResults, isLoading: stakesLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      address: POOL_ADDRESS,
      abi: cloutPoolAbi,
      functionName: 'getStakes' as const,
      args: [BigInt(i + 1), address!] as const,
    })),
    query: { enabled: myView && !!address && count > 0 },
  })

  const stakedPoolIds = useMemo<Set<number>>(() => {
    if (!myView || !address || !stakesResults) return new Set()
    const ids = new Set<number>()
    stakesResults.forEach((r, i) => {
      if (!r.result) return
      const [yesStake, noStake] = r.result as [bigint, bigint]
      if (yesStake > 0n || noStake > 0n) ids.add(i + 1)
    })
    return ids
  }, [stakesResults, myView, address])

  const isLoading = countLoading || poolsLoading || (myView && stakesLoading)

  // pools() returns a tuple — field order per CloutPool.sol:
  // 0=host, 1=resolver, 2=token, 3=eventStart, 4=eventEnd, 5=resolveBy,
  // 6=perWalletCap, 7=totalPoolCap, 8=hostCommissionBps, 9=state,
  // 10=yesTotal, 11=noTotal, 12=resolvedAt, 13=yesWins, 14=losingStakerCount, 15=flagCount
  const allPools: PoolRow[] = (poolResults ?? [])
    .map((r, i) => {
      if (!r.result) return null
      const p = r.result as readonly unknown[]
      return {
        id: i + 1,
        host: p[0] as `0x${string}`,
        state: p[9] as number,
        yesTotal: p[10] as bigint,
        noTotal: p[11] as bigint,
        eventStart: p[3] as bigint,
        eventEnd: p[4] as bigint,
      }
    })
    .filter((p): p is PoolRow => p !== null)

  const displayPools = useMemo(() => {
    return allPools
      .filter(p => filter === 'all' || POOL_FILTER_SETS[filter].has(p.state))
      .filter(p => !myView || !address || stakedPoolIds.has(p.id))
      .sort((a, b) => sortAsc ? a.id - b.id : b.id - a.id)
  }, [allPools, filter, sortAsc, myView, address, stakedPoolIds])

  const filterButtons: { label: string; value: 'all' | 'open' | 'closed' | 'resolved' }[] = [
    { label: 'All', value: 'all' },
    { label: 'Open', value: 'open' },
    { label: 'Closed', value: 'closed' },
    { label: 'Resolved', value: 'resolved' },
  ]

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <h1>Pools</h1>
        <Link href="/pools/create">+ Create Pool</Link>
      </div>

      {/* Filter + sort controls */}
      <div className="flex flex-wrap items-center gap-2 mb-3">
        {filterButtons.map(btn => (
          <button
            key={btn.value}
            onClick={() => setFilter(btn.value)}
            style={filter === btn.value ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
          >
            {btn.label}
          </button>
        ))}
        <button onClick={() => setSortAsc(s => !s)} style={{ marginLeft: 'auto' }}>
          ↕ {sortAsc ? 'Oldest first' : 'Newest first'}
        </button>
        {isConnected && (
          <div style={{ display: 'flex', gap: '0.5rem', marginLeft: '1rem' }}>
            <button
              onClick={() => setMyView(false)}
              style={!myView ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
            >
              All Pools
            </button>
            <button
              onClick={() => setMyView(true)}
              style={myView ? { fontWeight: 700, borderBottom: '2px solid currentColor' } : undefined}
            >
              My Pools
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
              <Skeleton width="65%" height="1rem" />
              <Skeleton width="45%" height="1rem" />
              <Skeleton width="45%" height="1rem" />
              <Skeleton width="55%" height="1rem" />
              <Skeleton width="55%" height="1rem" />
            </div>
          ))}
        </div>
      )}

      {!isLoading && displayPools.length === 0 && (
        <p>
          {myView
            ? 'You have no pools yet.'
            : filter === 'all'
              ? <><span>No pools yet. </span><Link href="/pools/create">Create one</Link></>
              : 'No pools match this filter.'
          }
        </p>
      )}

      {!isLoading && displayPools.length > 0 && (
        <>
          <p>Showing {displayPools.length} of {allPools.length} pools</p>

          {/* Mobile card list */}
          <div className="flex flex-col gap-3 md:hidden mt-3">
            {displayPools.map((p) => (
              <Link
                key={p.id}
                href={`/pools/${p.id}`}
                className="border rounded p-3 flex flex-col gap-1 block hover:bg-gray-50 cursor-pointer"
              >
                <div className="flex justify-between">
                  <span className="font-semibold">#{p.id}</span>
                  <PoolStateBadge state={p.state} />
                </div>
                <div className="text-sm">Host: {truncateAddr(p.host)}</div>
                <div className="text-sm">YES: {(Number(p.yesTotal) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">NO: {(Number(p.noTotal) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">Start: {formatTimestamp(p.eventStart)}</div>
                <div className="text-sm">End: {formatTimestamp(p.eventEnd)}</div>
              </Link>
            ))}
          </div>

          {/* Desktop grid */}
          <div className="hidden md:block overflow-x-auto mt-3">
            <div style={{ width: '100%' }}>
              {/* Header row */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', fontWeight: 'bold' }}>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>ID</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Host</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>State</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>YES Total</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>NO Total</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Event Start</span>
                <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Event End</span>
              </div>
              {/* Data rows — each row is a <Link> */}
              {displayPools.map((p) => (
                <Link
                  key={p.id}
                  href={`/pools/${p.id}`}
                  className="hover:bg-gray-50 cursor-pointer"
                  style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}
                >
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{p.id}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(p.host)}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    <PoolStateBadge state={p.state} />
                  </span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {(Number(p.yesTotal) / 1_000_000).toFixed(2)} USDC
                  </span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {(Number(p.noTotal) / 1_000_000).toFixed(2)} USDC
                  </span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{formatTimestamp(p.eventStart)}</span>
                  <span style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{formatTimestamp(p.eventEnd)}</span>
                </Link>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
