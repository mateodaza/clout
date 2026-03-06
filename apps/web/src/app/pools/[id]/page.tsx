import type { Metadata } from 'next'
import { createPublicClient, http } from 'viem'
import { baseSepolia } from 'viem/chains'
import { cloutPoolAbi, POOL_ADDRESS } from '@/lib/contracts'
import { PoolDetailClient } from './PoolDetailClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  try {
    const client = createPublicClient({
      chain: baseSepolia,
      transport: http(process.env.NEXT_PUBLIC_RPC_URL),
    })
    const pool = await client.readContract({
      address: POOL_ADDRESS,
      abi: cloutPoolAbi,
      functionName: 'getPool',
      args: [BigInt(id)],
    }) as { host: string; yesTotal: bigint; noTotal: bigint }
    const truncHost = `${pool.host.slice(0, 6)}…${pool.host.slice(-4)}`
    const totalUsdc = (Number(pool.yesTotal + pool.noTotal) / 1_000_000).toFixed(2)
    return {
      title: `Pool #${id}`,
      description: `Pool #${id} on Clout hosted by ${truncHost}. ${totalUsdc} USDC staked (YES: ${(Number(pool.yesTotal) / 1_000_000).toFixed(2)} / NO: ${(Number(pool.noTotal) / 1_000_000).toFixed(2)}).`,
      alternates: { canonical: `/pools/${id}` },
    }
  } catch {
    return {
      title: `Pool #${id}`,
      description: `View details and stake on Pool #${id} on Clout.`,
      alternates: { canonical: `/pools/${id}` },
    }
  }
}

export default function PoolDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  return (
    <ErrorBoundary>
      <PoolDetailClient params={params} />
    </ErrorBoundary>
  )
}
