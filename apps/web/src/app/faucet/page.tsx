import type { Metadata } from 'next'
import { FaucetClient } from './FaucetClient'

export const metadata: Metadata = { title: 'Faucet' }

export default function FaucetPage() {
  return <FaucetClient />
}
