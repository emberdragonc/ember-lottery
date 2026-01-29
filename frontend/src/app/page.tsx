'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { BuyTickets } from '@/components/BuyTickets'

export default function Home() {
  const { address, isConnected, chain } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-2xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold">🎲 Ember Lottery</h1>
          <p className="text-gray-400">
            On-chain lottery with EIP-7702 smart wallet support
          </p>
        </div>

        {/* Connect Wallet */}
        {!isConnected ? (
          <div className="p-6 bg-gray-800 rounded-lg space-y-4">
            <h2 className="text-xl font-semibold">Connect Wallet</h2>
            <div className="grid gap-3">
              {connectors.map((connector) => (
                <button
                  key={connector.uid}
                  onClick={() => connect({ connector })}
                  disabled={isPending}
                  className="w-full py-3 px-4 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors flex items-center justify-between"
                >
                  <span>{connector.name}</span>
                  {connector.name === 'Coinbase Wallet' && (
                    <span className="text-xs bg-green-600 px-2 py-1 rounded">
                      EIP-7702
                    </span>
                  )}
                </button>
              ))}
            </div>
            <p className="text-xs text-gray-500">
              💡 Smart wallets (Coinbase) support batched approve+buy in one transaction
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Connected Status */}
            <div className="p-4 bg-gray-800 rounded-lg flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Connected</p>
                <p className="font-mono text-sm">
                  {address?.slice(0, 6)}...{address?.slice(-4)}
                </p>
                {chain && (
                  <p className="text-xs text-gray-500">{chain.name}</p>
                )}
              </div>
              <button
                onClick={() => disconnect()}
                className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-sm"
              >
                Disconnect
              </button>
            </div>

            {/* Buy Tickets Component */}
            <BuyTickets />
          </div>
        )}

        {/* Footer Info */}
        <div className="text-center text-sm text-gray-500 space-y-1">
          <p>5% of each pot goes to the fee recipient</p>
          <p>Winner takes 95% of the pot</p>
          <p className="text-orange-400">
            🔥 Built by Ember | Uses exact approvals, not infinite
          </p>
        </div>
      </div>
    </main>
  )
}
