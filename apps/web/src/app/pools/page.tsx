import type { Metadata } from 'next'
import { PoolsClient } from './PoolsClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'Pools',
  description: 'Explore multi-participant prediction pools on Clout.',
}

export default function PoolsPage() {
  return (
    <ErrorBoundary>
      <PoolsClient />
    </ErrorBoundary>
  )
}
