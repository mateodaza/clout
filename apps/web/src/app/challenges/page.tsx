'use client'

import { useReadContract, useReadContracts } from 'wagmi'
import { hexToString } from 'viem'
import { ChallengeState } from '@clout/types'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'

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

export default function ChallengesPage() {
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
    <div style={{ padding: '1rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h1>Challenges</h1>
        <Link href="/challenges/create">+ Create Challenge</Link>
      </div>

      {isLoading && <p>Loading challenges...</p>}

      {!isLoading && activeChallenges.length === 0 && (
        <p>No active challenges. <Link href="/challenges/create">Create one</Link></p>
      )}

      {!isLoading && activeChallenges.length > 0 && (
        <>
          <p>Showing active challenges ({activeChallenges.length} of {count})</p>
          <table style={{ borderCollapse: 'collapse', width: '100%' }}>
            <thead>
              <tr>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>ID</th>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Creator</th>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Opponent</th>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Stake</th>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>State</th>
                <th style={{ border: '1px solid #ccc', padding: '0.5rem' }}>Game</th>
              </tr>
            </thead>
            <tbody>
              {activeChallenges.map((c) => (
                <tr key={c.id}>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{c.id}</td>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(c.creator)}</td>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{truncateAddr(c.opponent)}</td>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {(Number(c.stakeAmount) / 1_000_000).toFixed(2)} USDC
                  </td>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>{ChallengeState[c.state]}</td>
                  <td style={{ border: '1px solid #ccc', padding: '0.5rem' }}>
                    {hexToString(c.gameId).replace(/\0+$/, '')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  )
}
