'use client'

import { useReadContract } from 'wagmi'
import { WalletRecord as WalletRecordType } from '@clout/types'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'

function formatTimestamp(ts: bigint): string {
  if (ts === 0n) return 'N/A'
  return new Date(Number(ts) * 1000).toLocaleDateString()
}

export function WalletRecord({ address }: { address: `0x${string}` }) {
  const { data, isLoading } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'getWalletRecord',
    args: [address],
  })

  if (isLoading) return <p>Loading wallet record...</p>
  if (!data) return <p>No record found.</p>

  const record = data as unknown as WalletRecordType

  return (
    <div style={{ padding: '1rem' }}>
      <dl>
        <dt>Challenges Entered</dt>
        <dd>{Number(record.challengesEntered)}</dd>

        <dt>Challenges Completed</dt>
        <dd>{Number(record.challengesCompleted)}</dd>

        <dt>Challenges Won</dt>
        <dd>{Number(record.challengesWon)}</dd>

        <dt>Challenges Disputed</dt>
        <dd>{Number(record.challengesDisputed)}</dd>

        <dt>Total Staked</dt>
        <dd>{(Number(record.totalStaked) / 1_000_000).toFixed(2)} USDC</dd>

        <dt>First Challenge</dt>
        <dd>{formatTimestamp(record.firstChallengeAt)}</dd>

        <dt>Last Challenge</dt>
        <dd>{formatTimestamp(record.lastChallengeAt)}</dd>
      </dl>
    </div>
  )
}
