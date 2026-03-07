'use client'
import { useChainId, useAccount } from 'wagmi'

const TARGET_CHAIN_ID = 84532

export function useWrongChain(): boolean {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  return isConnected && chainId !== TARGET_CHAIN_ID
}
