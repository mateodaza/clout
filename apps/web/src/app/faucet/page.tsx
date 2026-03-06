import type { Metadata } from 'next'
import { FaucetClient } from './FaucetClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = { title: 'Faucet' }

export default function FaucetPage() {
  return (
    <ErrorBoundary>
      <FaucetClient />
    </ErrorBoundary>
  )
}
