import type { Metadata } from 'next'
import { createPublicClient, http } from 'viem'
import { baseSepolia } from 'viem/chains'
import { cloutPoolAbi, POOL_ADDRESS } from '@/lib/contracts'
import { PoolsClient } from './PoolsClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export async function generateMetadata(): Promise<Metadata> {
  try {
    const client = createPublicClient({
      chain: baseSepolia,
      transport: http(process.env.NEXT_PUBLIC_RPC_URL),
    })
    const count = await client.readContract({
      address: POOL_ADDRESS,
      abi: cloutPoolAbi,
      functionName: 'poolCount',
    }) as bigint
    return {
      title: 'Pools',
      description: `Explore ${count.toString()} multi-participant prediction pools on Clout.`,
      alternates: { canonical: '/pools' },
    }
  } catch {
    return {
      title: 'Pools',
      description: 'Explore multi-participant prediction pools on Clout.',
      alternates: { canonical: '/pools' },
    }
  }
}

export default function PoolsPage() {
  return (
    <ErrorBoundary>
      <PoolsClient />
    </ErrorBoundary>
  )
}
