import { http, createConfig } from 'wagmi'
import { base, baseSepolia, mainnet, sepolia } from 'wagmi/chains'
import { coinbaseWallet, injected, walletConnect } from 'wagmi/connectors'

// Project ID from WalletConnect (replace with your own)
const projectId = process.env.NEXT_PUBLIC_WC_PROJECT_ID || 'YOUR_PROJECT_ID'

export const config = createConfig({
  chains: [base, baseSepolia, mainnet, sepolia],
  connectors: [
    injected(),
    coinbaseWallet({ 
      appName: 'Ember Lottery',
      // Enable EIP-7702 capabilities
      preference: 'smartWalletOnly'
    }),
    walletConnect({ projectId }),
  ],
  transports: {
    [base.id]: http(),
    [baseSepolia.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}
