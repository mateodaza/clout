import type { Metadata } from 'next'
import { createPublicClient, http } from 'viem'
import { baseSepolia } from 'viem/chains'
import { cloutEscrowAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import { ChallengesClient } from './ChallengesClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export async function generateMetadata(): Promise<Metadata> {
  try {
    const client = createPublicClient({
      chain: baseSepolia,
      transport: http(process.env.NEXT_PUBLIC_RPC_URL),
    })
    const count = await client.readContract({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'challengeCount',
    }) as bigint
    return {
      title: 'Challenges',
      description: `Browse ${count.toString()} on-chain PvP escrow challenges on Clout.`,
      alternates: { canonical: '/challenges' },
    }
  } catch {
    return {
      title: 'Challenges',
      description: 'Browse on-chain PvP escrow challenges on Clout.',
      alternates: { canonical: '/challenges' },
    }
  }
}

export default function ChallengesPage() {
  return (
    <ErrorBoundary>
      <ChallengesClient />
    </ErrorBoundary>
  )
}
