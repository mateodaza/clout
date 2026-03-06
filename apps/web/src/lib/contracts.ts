import { type Abi } from 'viem'
import CloutEscrowAbi from './abis/CloutEscrow.json'
import CloutPoolAbi from './abis/CloutPool.json'
import MockStablecoinAbi from './abis/MockStablecoin.json'

export const cloutEscrowAbi = CloutEscrowAbi as unknown as Abi
export const cloutPoolAbi = CloutPoolAbi as unknown as Abi
export const mockStablecoinAbi = MockStablecoinAbi as unknown as Abi

export const ESCROW_ADDRESS = process.env.NEXT_PUBLIC_ESCROW_ADDRESS as `0x${string}`
export const POOL_ADDRESS   = process.env.NEXT_PUBLIC_POOL_ADDRESS as `0x${string}`
export const TOKEN_ADDRESS  = process.env.NEXT_PUBLIC_TOKEN_ADDRESS as `0x${string}`
