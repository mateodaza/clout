import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { useSwitchChain } from 'wagmi'
import { useWrongChain } from '@/lib/useWrongChain'
import { ChainBanner } from './ChainBanner'

vi.mock('@/lib/useWrongChain', () => ({
  useWrongChain: vi.fn(),
}))

vi.mock('wagmi', () => ({
  useSwitchChain: vi.fn(),
}))

vi.mock('viem/chains', () => ({
  baseSepolia: { id: 84532 },
}))

const mockUseWrongChain = vi.mocked(useWrongChain)
const mockUseSwitchChain = vi.mocked(useSwitchChain)

describe('ChainBanner', () => {
  const switchChain = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
    mockUseSwitchChain.mockReturnValue({ switchChain } as ReturnType<typeof useSwitchChain>)
  })

  it('renders nothing when on the correct chain', () => {
    mockUseWrongChain.mockReturnValue(false)
    const { container } = render(<ChainBanner />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when wallet is disconnected', () => {
    mockUseWrongChain.mockReturnValue(false)
    const { container } = render(<ChainBanner />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders an alert banner when on a wrong chain', () => {
    mockUseWrongChain.mockReturnValue(true)
    render(<ChainBanner />)
    expect(screen.getByRole('alert')).toBeInTheDocument()
    expect(screen.getByText(/Wrong network/)).toBeInTheDocument()
  })

  it('shows a Switch Network button when on a wrong chain', () => {
    mockUseWrongChain.mockReturnValue(true)
    render(<ChainBanner />)
    expect(screen.getByRole('button', { name: /Switch to Base Sepolia/i })).toBeInTheDocument()
  })

  it('calls switchChain with Base Sepolia (84532) when Switch Network is clicked', () => {
    mockUseWrongChain.mockReturnValue(true)
    render(<ChainBanner />)
    fireEvent.click(screen.getByRole('button', { name: /Switch to Base Sepolia/i }))
    expect(switchChain).toHaveBeenCalledWith({ chainId: 84532 })
  })
})
