import type { Metadata } from 'next'
import { FaucetClient } from './FaucetClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'Faucet',
  description: 'Get testnet USDC to try Clout challenges and pools on Base Sepolia.',
  alternates: { canonical: '/faucet' },
}

export default function FaucetPage() {
  return (
    <ErrorBoundary>
      <FaucetClient />
    </ErrorBoundary>
  )
}
