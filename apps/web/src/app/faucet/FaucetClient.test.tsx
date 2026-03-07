import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  useReadContract,
} from 'wagmi'
import { useToast } from '@/contexts/ToastContext'
import { useWrongChain } from '@/lib/useWrongChain'
import { FaucetClient } from './FaucetClient'

vi.mock('wagmi', () => ({
  useAccount: vi.fn(),
  useWriteContract: vi.fn(),
  useWaitForTransactionReceipt: vi.fn(),
  useReadContract: vi.fn(),
}))

vi.mock('@/lib/useWrongChain', () => ({
  useWrongChain: vi.fn(),
}))

vi.mock('@/contexts/ToastContext', () => ({
  useToast: vi.fn(),
}))

vi.mock('@/components/ConnectWallet', () => ({
  ConnectWallet: () => null,
}))

const mockUseAccount = vi.mocked(useAccount)
const mockUseWriteContract = vi.mocked(useWriteContract)
const mockUseWaitForTransactionReceipt = vi.mocked(useWaitForTransactionReceipt)
const mockUseReadContract = vi.mocked(useReadContract)
const mockUseWrongChain = vi.mocked(useWrongChain)
const mockUseToast = vi.mocked(useToast)

function setupDefaultMocks() {
  mockUseToast.mockReturnValue({
    toasts: [],
    addToast: vi.fn().mockReturnValue('toast-id'),
    updateToast: vi.fn(),
    dismissToast: vi.fn(),
  })
  mockUseWriteContract.mockReturnValue({
    writeContract: vi.fn(),
    data: undefined,
    error: null,
    reset: vi.fn(),
  } as unknown as ReturnType<typeof useWriteContract>)
  mockUseWaitForTransactionReceipt.mockReturnValue({
    isSuccess: false,
    isError: false,
    error: null,
  } as unknown as ReturnType<typeof useWaitForTransactionReceipt>)
  mockUseReadContract.mockReturnValue({
    data: undefined,
    refetch: vi.fn(),
  } as unknown as ReturnType<typeof useReadContract>)
}

describe('FaucetClient — wrong-chain button disabling', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setupDefaultMocks()
  })

  it('disables the Mint button when connected but on the wrong chain', () => {
    mockUseAccount.mockReturnValue({
      address: '0xabc' as `0x${string}`,
      isConnected: true,
    } as ReturnType<typeof useAccount>)
    mockUseWrongChain.mockReturnValue(true)

    render(<FaucetClient />)

    expect(screen.getByRole('button', { name: /^Mint$/i })).toBeDisabled()
  })

  it('enables the Mint button when connected on the correct chain', () => {
    mockUseAccount.mockReturnValue({
      address: '0xabc' as `0x${string}`,
      isConnected: true,
    } as ReturnType<typeof useAccount>)
    mockUseWrongChain.mockReturnValue(false)

    render(<FaucetClient />)

    expect(screen.getByRole('button', { name: /^Mint$/i })).toBeEnabled()
  })

  it('disables the amount input when on the wrong chain', () => {
    mockUseAccount.mockReturnValue({
      address: '0xabc' as `0x${string}`,
      isConnected: true,
    } as ReturnType<typeof useAccount>)
    mockUseWrongChain.mockReturnValue(true)

    render(<FaucetClient />)

    expect(screen.getByRole('textbox')).toBeDisabled()
  })
})
