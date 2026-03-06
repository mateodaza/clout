'use client'

import { useReadContract, useReadContracts } from 'wagmi'
import { PoolState } from '@clout/types'
import { cloutPoolAbi, POOL_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Spinner } from '@/components/Spinner'
import { PoolStateBadge } from '@/components/StateBadge'

const ACTIVE_POOL_STATES = new Set([
  PoolState.OPEN,       // 0
  PoolState.CLOSED,     // 1
  PoolState.SUBMITTED,  // 2
  PoolState.DISPUTED,   // 3
  // FINALIZED (4) and VOIDED (5) are excluded
])

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

function formatTs(ts: bigint): string {
  return ts === 0n ? '—' : new Date(Number(ts) * 1000).toLocaleString()
}

export default function PoolsPage() {
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

  const isLoading = countLoading || poolsLoading

  // pools() returns a tuple — field order per CloutPool.sol:
  // 0=host, 1=resolver, 2=token, 3=eventStart, 4=eventEnd, 5=resolveBy,
  // 6=perWalletCap, 7=totalPoolCap, 8=hostCommissionBps, 9=state,
  // 10=yesTotal, 11=noTotal, 12=resolvedAt, 13=yesWins, 14=losingStakerCount, 15=flagCount
  const activePools: PoolRow[] = (poolResults ?? [])
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
    .filter((p): p is PoolRow => p !== null && ACTIVE_POOL_STATES.has(p.state))

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <h1>Pools</h1>
        <Link href="/pools/create">+ Create Pool</Link>
      </div>

      {isLoading && <Spinner label="Loading pools..." />}

      {!isLoading && activePools.length === 0 && (
        <p>No active pools. <Link href="/pools/create">Create one</Link></p>
      )}

      {!isLoading && activePools.length > 0 && (
        <>
          <p>Showing active pools ({activePools.length} of {count})</p>

          {/* Mobile card list */}
          <div className="flex flex-col gap-3 md:hidden mt-3">
            {activePools.map((p) => (
              <div key={p.id} className="border rounded p-3 flex flex-col gap-1">
                <div className="flex justify-between">
                  <span className="font-semibold">#{p.id}</span>
                  <PoolStateBadge state={p.state} />
                </div>
                <div className="text-sm">Host: {truncateAddr(p.host)}</div>
                <div className="text-sm">YES: {(Number(p.yesTotal) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">NO: {(Number(p.noTotal) / 1_000_000).toFixed(2)} USDC</div>
                <div className="text-sm">Start: {formatTs(p.eventStart)}</div>
                <div className="text-sm">End: {formatTs(p.eventEnd)}</div>
                <Link href={`/pools/${p.id}`} className="text-sm text-blue-600">View →</Link>
              </div>
            ))}
          </div>

          {/* Desktop table */}
          <div className="hidden md:block overflow-x-auto mt-3">
            <table style={{ borderCollapse: 'collapse', width: '100%' }}>
              <thead>
                <tr>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>ID</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Host</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>State</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>YES Total</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>NO Total</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Event Start</th>
                  <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Event End</th>
                </tr>
              </thead>
              <tbody>
                {activePools.map((p) => (
                  <tr key={p.id}>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{p.id}</td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(p.host)}</td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}><PoolStateBadge state={p.state} /></td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                      {(Number(p.yesTotal) / 1_000_000).toFixed(2)} USDC
                    </td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                      {(Number(p.noTotal) / 1_000_000).toFixed(2)} USDC
                    </td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{formatTs(p.eventStart)}</td>
                    <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{formatTs(p.eventEnd)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}
