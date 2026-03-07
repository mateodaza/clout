'use client'

import { useMemo } from 'react'
import { useReadContract, useReadContracts } from 'wagmi'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { ChallengeStateBadge, PoolStateBadge } from '@/components/StateBadge'
import { cloutEscrowAbi, ESCROW_ADDRESS, cloutPoolAbi, POOL_ADDRESS } from '@/lib/contracts'
import { formatRelativeTime, formatBalance } from '@/lib/utils'

type ChallengeFeedItem = {
  type: 'challenge'
  id: number
  who: `0x${string}`
  amount: bigint
  state: number
  createdAt: bigint    // c[10] — Challenge.createdAt (used for sort + display)
  href: string
}

type PoolFeedItem = {
  type: 'pool'
  id: number
  who: `0x${string}`
  amount: bigint
  state: number
  eventStart: bigint   // p[3] — Pool.eventStart (creation-time proxy; used for sort + display)
  href: string
}

type FeedItem = ChallengeFeedItem | PoolFeedItem

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function RecentActivity() {
  const { data: challengeCountData, isLoading: countCLoading } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'challengeCount',
  })
  const { data: poolCountData, isLoading: countPLoading } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'poolCount',
  })
  const challengeCount = Number(challengeCountData ?? 0n)
  const poolCount = Number(poolCountData ?? 0n)

  // IDs are 1-indexed. If count=10: [10,9,8,7,6]. If count=3: [3,2,1]. If count=0: []
  const lastChallengeIds = Array.from(
    { length: Math.min(5, challengeCount) },
    (_, i) => challengeCount - i
  )
  const lastPoolIds = Array.from(
    { length: Math.min(5, poolCount) },
    (_, i) => poolCount - i
  )

  const { data: challengeResults, isLoading: challengesLoading } = useReadContracts({
    contracts: lastChallengeIds.map(id => ({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'challenges' as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: challengeCount > 0 },
  })

  const { data: poolResults, isLoading: poolsLoading } = useReadContracts({
    contracts: lastPoolIds.map(id => ({
      address: POOL_ADDRESS,
      abi: cloutPoolAbi,
      functionName: 'pools' as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: poolCount > 0 },
  })

  // challenges() tuple indices: 0=creator, 1=opponent, 2=designatedResolver, 3=token,
  // 4=stakeAmount, 5=state, 6=gameId, 7=matchId, 8=submittedResult,
  // 9=submittedBy, 10=createdAt, ...
  //
  // pools() tuple indices: 0=host, 1=resolver, 2=token, 3=eventStart, 4=eventEnd,
  // 5=resolveBy, 6=perWalletCap, 7=totalPoolCap, 8=hostCommissionBps,
  // 9=state, 10=yesTotal, 11=noTotal, 12=resolvedAt, 13=yesWins, ...
  // NOTE: Pool has no createdAt — eventStart (p[3]) used as creation-time proxy
  const feedItems: FeedItem[] = useMemo(() => {
    const parsedChallenges: ChallengeFeedItem[] = (challengeResults ?? [])
      .map((r, i) => {
        if (!r.result) return null
        const c = r.result as readonly unknown[]
        return {
          type: 'challenge' as const,
          id: lastChallengeIds[i],
          who: c[0] as `0x${string}`,
          amount: c[4] as bigint,
          state: c[5] as number,
          createdAt: c[10] as bigint,
          href: `/challenges/${lastChallengeIds[i]}`,
        }
      })
      .filter((c): c is ChallengeFeedItem => c !== null)

    const parsedPools: PoolFeedItem[] = (poolResults ?? [])
      .map((r, i) => {
        if (!r.result) return null
        const p = r.result as readonly unknown[]
        return {
          type: 'pool' as const,
          id: lastPoolIds[i],
          who: p[0] as `0x${string}`,
          amount: (p[10] as bigint) + (p[11] as bigint),  // yesTotal + noTotal
          state: p[9] as number,
          eventStart: p[3] as bigint,
          href: `/pools/${lastPoolIds[i]}`,
        }
      })
      .filter((p): p is PoolFeedItem => p !== null)

    // Unified timestamp sort: Challenge uses createdAt (c[10]), Pool uses eventStart (p[3]).
    // Sorted descending so most-recent/upcoming items appear first.
    return [...parsedChallenges, ...parsedPools].sort((a, b) => {
      const tA = a.type === 'challenge' ? a.createdAt : a.eventStart
      const tB = b.type === 'challenge' ? b.createdAt : b.eventStart
      return tA < tB ? 1 : tA > tB ? -1 : 0
    })
  }, [challengeResults, poolResults, lastChallengeIds, lastPoolIds])

  const isLoading = countCLoading || countPLoading || challengesLoading || poolsLoading

  if (isLoading) {
    return (
      <div>
        <h2>Recent Activity</h2>
        <div className="flex flex-col gap-3 mt-3">
          {[0, 1, 2, 3, 4].map(i => (
            <div key={i} className="border rounded p-3 flex flex-col gap-2">
              <div className="flex justify-between">
                <Skeleton width="5rem" height="1rem" />
                <Skeleton width="4rem" height="1rem" />
              </div>
              <Skeleton width="60%" height="1rem" />
              <Skeleton width="45%" height="1rem" />
              <Skeleton width="30%" height="0.75rem" />
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (challengeCount === 0 && poolCount === 0) {
    return (
      <div>
        <h2>Recent Activity</h2>
        <p>No activity yet.</p>
      </div>
    )
  }

  if (feedItems.length === 0) {
    return (
      <div>
        <h2>Recent Activity</h2>
        <p>No activity yet.</p>
      </div>
    )
  }

  return (
    <div>
      <h2>Recent Activity</h2>
      <div className="flex flex-col gap-3 mt-3">
        {feedItems.map(item => (
          <Link
            key={`${item.type}-${item.id}`}
            href={item.href}
            aria-label={`View ${item.type} #${item.id}`}
            className="border rounded p-3 flex flex-col gap-1 hover:bg-gray-50 cursor-pointer"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="text-xs font-semibold uppercase">
                  {item.type === 'challenge' ? 'Challenge' : 'Pool'}
                </span>
                <span className="font-semibold">#{item.id}</span>
              </div>
              {item.type === 'challenge'
                ? <ChallengeStateBadge state={item.state} />
                : <PoolStateBadge state={item.state} />
              }
            </div>
            <div className="text-sm">
              {item.type === 'challenge' ? 'Creator' : 'Host'}: {truncateAddr(item.who)}
            </div>
            <div className="text-sm">
              {item.type === 'challenge' ? 'Stake' : 'Pool'}: {formatBalance(item.amount)}
            </div>
            <div className="text-xs text-gray-500">
              {item.type === 'challenge'
                ? formatRelativeTime(item.createdAt)
                : formatRelativeTime(item.eventStart)
              }
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
