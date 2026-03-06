import type { Metadata } from 'next'
import { ChallengesClient } from './ChallengesClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'Challenges',
  description: 'Browse and manage on-chain PvP escrow challenges on Clout.',
}

export default function ChallengesPage() {
  return (
    <ErrorBoundary>
      <ChallengesClient />
    </ErrorBoundary>
  )
}
