import type { Metadata } from 'next'
import { ChallengesClient } from './ChallengesClient'

export const metadata: Metadata = {
  title: 'Challenges',
  description: 'Browse and manage on-chain PvP escrow challenges on Clout.',
}

export default function ChallengesPage() {
  return <ChallengesClient />
}
