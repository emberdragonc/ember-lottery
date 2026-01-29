'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useBalance } from 'wagmi'
import { formatUnits, parseUnits, type Address } from 'viem'
import { useBuyTickets, useSupportsAtomicBatch } from '@/hooks/useEIP7702'

// Contract addresses (update for your deployment)
const LOTTERY_ADDRESS = process.env.NEXT_PUBLIC_LOTTERY_ADDRESS as Address
const TOKEN_ADDRESS = process.env.NEXT_PUBLIC_TOKEN_ADDRESS as Address

// ABIs
const LOTTERY_ABI = [
  {
    name: 'getTicketCost',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'ticketCount', type: 'uint256' }],
    outputs: [{ name: 'cost', type: 'uint256' }],
  },
  {
    name: 'getLotteryInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'lotteryId', type: 'uint256' }],
    outputs: [
      { name: 'ticketPrice', type: 'uint256' },
      { name: 'endTime', type: 'uint256' },
      { name: 'totalPot', type: 'uint256' },
      { name: 'participantCount', type: 'uint256' },
      { name: 'winner', type: 'address' },
      { name: 'ended', type: 'bool' },
    ],
  },
  {
    name: 'currentLotteryId',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'isLotteryActive',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const

const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'symbol',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
  },
  {
    name: 'decimals',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
  },
] as const

export function BuyTickets() {
  const { address, isConnected } = useAccount()
  const [ticketCount, setTicketCount] = useState(1)
  
  const supportsBatching = useSupportsAtomicBatch()
  
  // Read token info
  const { data: tokenSymbol } = useReadContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'symbol',
  })
  
  const { data: tokenDecimals } = useReadContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'decimals',
  })
  
  const { data: tokenBalance } = useReadContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })
  
  // Read lottery info
  const { data: lotteryId } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'currentLotteryId',
  })
  
  const { data: isActive } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'isLotteryActive',
  })
  
  const { data: ticketCost } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'getTicketCost',
    args: [BigInt(ticketCount)],
  })
  
  const { data: lotteryInfo } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'getLotteryInfo',
    args: lotteryId ? [lotteryId] : undefined,
    query: { enabled: !!lotteryId },
  })
  
  // Buy tickets hook with EIP-7702 support
  const {
    supportsBatching: confirmedBatching,
    isLoading,
    isPending,
    isSuccess,
    error,
    txHash,
    buyTickets,
    reset,
  } = useBuyTickets({
    tokenAddress: TOKEN_ADDRESS,
    lotteryAddress: LOTTERY_ADDRESS,
    ticketCount: BigInt(ticketCount),
    exactCost: ticketCost || BigInt(0),
  })
  
  const decimals = tokenDecimals || 18
  const formattedCost = ticketCost ? formatUnits(ticketCost, decimals) : '0'
  const formattedBalance = tokenBalance ? formatUnits(tokenBalance, decimals) : '0'
  const hasBalance = tokenBalance && ticketCost ? tokenBalance >= ticketCost : false
  
  const handleBuy = async () => {
    try {
      await buyTickets()
    } catch (err) {
      console.error('Failed to buy tickets:', err)
    }
  }
  
  if (!isConnected) {
    return (
      <div className="p-6 bg-gray-800 rounded-lg">
        <p className="text-gray-400">Connect your wallet to buy tickets</p>
      </div>
    )
  }
  
  return (
    <div className="p-6 bg-gray-800 rounded-lg space-y-6">
      {/* EIP-7702 Status Banner */}
      <div className={`p-3 rounded-lg ${supportsBatching ? 'bg-green-900/50 border border-green-500' : 'bg-yellow-900/50 border border-yellow-500'}`}>
        {supportsBatching ? (
          <div className="flex items-center gap-2">
            <span className="text-green-400">⚡</span>
            <span className="text-green-300 text-sm">
              Smart Wallet Detected - Approve + Buy in one transaction!
            </span>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <span className="text-yellow-400">ℹ️</span>
            <span className="text-yellow-300 text-sm">
              Standard Wallet - Will require 2 transactions (approve, then buy)
            </span>
          </div>
        )}
      </div>
      
      {/* Lottery Status */}
      {!isActive && (
        <div className="p-3 bg-red-900/50 border border-red-500 rounded-lg">
          <p className="text-red-300">No active lottery. Check back later!</p>
        </div>
      )}
      
      {/* Lottery Info */}
      {lotteryInfo && (
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-gray-400">Ticket Price:</span>
            <p className="text-white font-mono">
              {formatUnits(lotteryInfo[0], decimals)} {tokenSymbol}
            </p>
          </div>
          <div>
            <span className="text-gray-400">Total Pot:</span>
            <p className="text-white font-mono">
              {formatUnits(lotteryInfo[2], decimals)} {tokenSymbol}
            </p>
          </div>
          <div>
            <span className="text-gray-400">Participants:</span>
            <p className="text-white font-mono">{lotteryInfo[3].toString()}</p>
          </div>
          <div>
            <span className="text-gray-400">Your Balance:</span>
            <p className="text-white font-mono">
              {formattedBalance} {tokenSymbol}
            </p>
          </div>
        </div>
      )}
      
      {/* Ticket Selection */}
      <div className="space-y-3">
        <label className="block text-gray-300">Number of Tickets</label>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setTicketCount(Math.max(1, ticketCount - 1))}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg"
            disabled={ticketCount <= 1}
          >
            -
          </button>
          <input
            type="number"
            value={ticketCount}
            onChange={(e) => setTicketCount(Math.max(1, parseInt(e.target.value) || 1))}
            className="w-20 px-4 py-2 bg-gray-700 rounded-lg text-center text-white"
            min="1"
          />
          <button
            onClick={() => setTicketCount(ticketCount + 1)}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg"
          >
            +
          </button>
        </div>
        
        {/* Cost Display */}
        <div className="p-3 bg-gray-700/50 rounded-lg">
          <div className="flex justify-between items-center">
            <span className="text-gray-400">Total Cost:</span>
            <span className="text-xl font-mono text-white">
              {formattedCost} {tokenSymbol}
            </span>
          </div>
          <p className="text-xs text-gray-500 mt-1">
            Exact approval amount: {formattedCost} {tokenSymbol} (no infinite approvals)
          </p>
        </div>
      </div>
      
      {/* Buy Button */}
      <button
        onClick={handleBuy}
        disabled={!isActive || !hasBalance || isPending || isLoading}
        className={`w-full py-3 px-6 rounded-lg font-semibold transition-colors ${
          !isActive || !hasBalance || isPending || isLoading
            ? 'bg-gray-600 cursor-not-allowed text-gray-400'
            : 'bg-orange-500 hover:bg-orange-600 text-white'
        }`}
      >
        {isPending || isLoading ? (
          <span className="flex items-center justify-center gap-2">
            <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
            </svg>
            {supportsBatching ? 'Processing Batch...' : 'Processing...'}
          </span>
        ) : !hasBalance ? (
          `Insufficient ${tokenSymbol} Balance`
        ) : supportsBatching ? (
          `🎫 Buy ${ticketCount} Ticket${ticketCount > 1 ? 's' : ''} (1 TX)`
        ) : (
          `🎫 Buy ${ticketCount} Ticket${ticketCount > 1 ? 's' : ''} (2 TXs)`
        )}
      </button>
      
      {/* Success State */}
      {isSuccess && (
        <div className="p-4 bg-green-900/50 border border-green-500 rounded-lg">
          <p className="text-green-300 font-semibold">🎉 Tickets Purchased!</p>
          {txHash && (
            <a
              href={`https://basescan.org/tx/${txHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-green-400 hover:text-green-300 text-sm underline"
            >
              View Transaction →
            </a>
          )}
          <button
            onClick={reset}
            className="mt-2 text-sm text-gray-400 hover:text-white"
          >
            Buy More
          </button>
        </div>
      )}
      
      {/* Error State */}
      {error && (
        <div className="p-4 bg-red-900/50 border border-red-500 rounded-lg">
          <p className="text-red-300 font-semibold">Transaction Failed</p>
          <p className="text-red-400 text-sm">{error.message}</p>
          <button
            onClick={reset}
            className="mt-2 text-sm text-gray-400 hover:text-white"
          >
            Try Again
          </button>
        </div>
      )}
    </div>
  )
}
