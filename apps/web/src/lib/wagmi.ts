import { createConfig, http } from 'wagmi'
import { avalancheFuji } from 'viem/chains'
import { coinbaseWallet, walletConnect, injected } from 'wagmi/connectors'

export const wagmiConfig = createConfig({
  chains: [avalancheFuji],
  connectors: [
    coinbaseWallet({ appName: 'Clout', preference: 'smartWalletOnly' }),
    walletConnect({ projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? '' }),
    injected(),
  ],
  transports: {
    [avalancheFuji.id]: http(process.env.NEXT_PUBLIC_RPC_URL),
  },
})
