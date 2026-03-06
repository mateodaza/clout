import type { Metadata } from 'next'
import { CreatePoolClient } from './CreatePoolClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'Create Pool',
  description: 'Create a new prediction pool and stake USDC on an outcome.',
}

export default function CreatePoolPage() {
  return (
    <ErrorBoundary>
      <CreatePoolClient />
    </ErrorBoundary>
  )
}
