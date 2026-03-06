'use client'

import { useAccount, useReadContract } from 'wagmi'
import { zeroAddress } from 'viem'
import { mockStablecoinAbi, TOKEN_ADDRESS } from '@/lib/contracts'

export function useTokenBalance() {
  const { address, isConnected } = useAccount()
  return useReadContract({
    address: TOKEN_ADDRESS,
    abi: mockStablecoinAbi,
    functionName: 'balanceOf',
    args: [address ?? zeroAddress],
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5_000,
    },
  })
}
