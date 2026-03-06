import type { Metadata } from 'next'
import { CreateChallengeClient } from './CreateChallengeClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'Create Challenge',
  description: 'Create a new PvP escrow challenge and stake USDC against an opponent.',
  alternates: { canonical: '/challenges/create' },
}

export default function CreateChallengePage() {
  return (
    <ErrorBoundary>
      <CreateChallengeClient />
    </ErrorBoundary>
  )
}
