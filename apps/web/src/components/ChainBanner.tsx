'use client'
import { useSwitchChain } from 'wagmi'
import { baseSepolia } from 'viem/chains'
import { useWrongChain } from '@/lib/useWrongChain'

export function ChainBanner() {
  const isWrongChain = useWrongChain()
  const { switchChain } = useSwitchChain()

  if (!isWrongChain) return null

  return (
    <div
      role="alert"
      aria-live="assertive"
      className="bg-yellow-400 dark:bg-yellow-500 px-4 py-2 flex items-center justify-between gap-4"
    >
      <span className="font-medium text-yellow-900">
        Wrong network — please switch to Base Sepolia
      </span>
      <button
        onClick={() => switchChain({ chainId: baseSepolia.id })}
        className="px-3 py-1 rounded bg-yellow-900 text-yellow-100 text-sm font-medium"
        aria-label="Switch to Base Sepolia"
      >
        Switch Network
      </button>
    </div>
  )
}
