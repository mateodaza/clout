'use client'

import { useReadContract } from 'wagmi'
import { WalletRecord as WalletRecordType } from '@clout/types'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import { Spinner } from '@/components/Spinner'
import { formatTimestamp, basescanUrl } from '@/lib/utils'

export function WalletRecord({ address }: { address: `0x${string}` }) {
  const { data, isLoading } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'getWalletRecord',
    args: [address],
  })

  if (isLoading) return <Spinner label="Loading wallet record..." />
  if (!data) return <p>No record found.</p>

  const record = data as unknown as WalletRecordType

  return (
    <div style={{ padding: '1rem' }}>
      <p>
        Address:{' '}
        <a
          href={basescanUrl('address', address)}
          target="_blank"
          rel="noopener"
          aria-label={`View your address on Basescan: ${address}`}
        >
          {`${address.slice(0, 6)}…${address.slice(-4)}`}
        </a>
      </p>
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
