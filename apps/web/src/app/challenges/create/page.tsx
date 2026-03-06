import type { Metadata } from 'next'
import { CreateChallengeClient } from './CreateChallengeClient'

export const metadata: Metadata = {
  title: 'Create Challenge',
  description: 'Create a new PvP escrow challenge and stake USDC against an opponent.',
}

export default function CreateChallengePage() {
  return <CreateChallengeClient />
}
