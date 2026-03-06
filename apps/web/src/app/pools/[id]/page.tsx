import type { Metadata } from 'next'
import { PoolDetailClient } from './PoolDetailClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  return {
    title: `Pool #${id}`,
    description: `View details and stake on Pool #${id} on Clout.`,
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
