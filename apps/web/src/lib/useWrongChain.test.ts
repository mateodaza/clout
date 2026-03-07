import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook } from '@testing-library/react'
import { useAccount, useChainId } from 'wagmi'
import { useWrongChain } from './useWrongChain'

vi.mock('wagmi', () => ({
  useAccount: vi.fn(),
  useChainId: vi.fn(),
}))

const mockUseAccount = vi.mocked(useAccount)
const mockUseChainId = vi.mocked(useChainId)

describe('useWrongChain', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns false when wallet is disconnected, regardless of chain', () => {
    mockUseAccount.mockReturnValue({ isConnected: false } as ReturnType<typeof useAccount>)
    mockUseChainId.mockReturnValue(1)
    const { result } = renderHook(() => useWrongChain())
    expect(result.current).toBe(false)
  })

  it('returns false when connected on Base Sepolia (84532)', () => {
    mockUseAccount.mockReturnValue({ isConnected: true } as ReturnType<typeof useAccount>)
    mockUseChainId.mockReturnValue(84532)
    const { result } = renderHook(() => useWrongChain())
    expect(result.current).toBe(false)
  })

  it('returns true when connected on Ethereum mainnet (1)', () => {
    mockUseAccount.mockReturnValue({ isConnected: true } as ReturnType<typeof useAccount>)
    mockUseChainId.mockReturnValue(1)
    const { result } = renderHook(() => useWrongChain())
    expect(result.current).toBe(true)
  })

  it('returns true when connected on Avalanche Fuji (43113)', () => {
    mockUseAccount.mockReturnValue({ isConnected: true } as ReturnType<typeof useAccount>)
    mockUseChainId.mockReturnValue(43113)
    const { result } = renderHook(() => useWrongChain())
    expect(result.current).toBe(true)
  })
})
