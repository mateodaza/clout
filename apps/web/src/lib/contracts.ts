import { type Abi } from 'viem'
import CloutEscrowAbi from './abis/CloutEscrow.json'
import CloutPoolAbi from './abis/CloutPool.json'
import MockStablecoinAbi from './abis/MockStablecoin.json'

export const cloutEscrowAbi = CloutEscrowAbi as unknown as Abi
export const cloutPoolAbi = CloutPoolAbi as unknown as Abi
export const mockStablecoinAbi = MockStablecoinAbi as unknown as Abi

// Deployed contract addresses — Base Sepolia (chain ID 84532)
export const ESCROW_ADDRESS: `0x${string}` = '0x7D7F328a9eFDc4d6a332892a0902b549f2cB7E8D'
export const POOL_ADDRESS: `0x${string}`   = '0x25d7c79044Ef8d0C7978822086d2d4D4b7C2bb65'
export const TOKEN_ADDRESS: `0x${string}`  = '0xCF31F10B6be540c08060253334B1ad99b2C8E488'
