import { useCapabilities, useWriteContracts, useCallsStatus } from 'wagmi/experimental'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useState, useCallback, useMemo } from 'react'
import { parseAbi, type Address, type Hex, encodeFunctionData } from 'viem'

// ERC20 ABI for approve
const ERC20_ABI = parseAbi([
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
])

// Lottery ABI for buyTickets
const LOTTERY_ABI = parseAbi([
  'function buyTickets(uint256 ticketCount)',
  'function getTicketCost(uint256 ticketCount) view returns (uint256)',
])

interface UseBuyTicketsParams {
  tokenAddress: Address
  lotteryAddress: Address
  ticketCount: bigint
  exactCost: bigint
}

interface UseBuyTicketsReturn {
  // State
  supportsBatching: boolean
  isLoading: boolean
  isPending: boolean
  isSuccess: boolean
  error: Error | null
  txHash: Hex | undefined
  
  // Actions
  buyTickets: () => Promise<void>
  reset: () => void
}

/**
 * Hook for buying lottery tickets with EIP-7702 batching support
 * 
 * If wallet supports atomic batching (EIP-7702):
 *   - Batches approve(EXACT amount) + buyTickets in single tx
 *   - User signs once, pays gas once
 * 
 * If wallet doesn't support batching:
 *   - Falls back to two-step: approve(EXACT amount) → buyTickets
 *   - User signs twice, pays gas twice
 * 
 * Uses EXACT approval amounts, not infinite approvals
 */
export function useBuyTickets({
  tokenAddress,
  lotteryAddress,
  ticketCount,
  exactCost,
}: UseBuyTicketsParams): UseBuyTicketsReturn {
  const { address, chainId } = useAccount()
  
  // Check wallet capabilities for atomic batching
  const { data: capabilities } = useCapabilities()
  
  // Determine if current chain supports atomic batching
  const supportsBatching = useMemo(() => {
    if (!chainId || !capabilities) return false
    const chainCapabilities = capabilities[chainId]
    // Check for atomicBatch capability (EIP-7702 / smart wallet feature)
    return chainCapabilities?.atomicBatch?.supported === true
  }, [chainId, capabilities])
  
  // === Batched Transaction Flow (EIP-7702) ===
  const {
    writeContracts,
    data: batchId,
    isPending: isBatchPending,
    error: batchError,
    reset: resetBatch,
  } = useWriteContracts()
  
  const { data: batchStatus } = useCallsStatus({
    id: batchId as string,
    query: {
      enabled: !!batchId,
      refetchInterval: (data) => 
        data.state.data?.status === 'CONFIRMED' ? false : 1000,
    },
  })
  
  // === Fallback Two-Step Flow ===
  const [fallbackStep, setFallbackStep] = useState<'idle' | 'approving' | 'buying' | 'done'>('idle')
  
  const {
    writeContract: writeApprove,
    data: approveHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract()
  
  const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } = 
    useWaitForTransactionReceipt({ hash: approveHash })
  
  const {
    writeContract: writeBuy,
    data: buyHash,
    isPending: isBuyPending,
    error: buyError,
    reset: resetBuy,
  } = useWriteContract()
  
  const { isLoading: isBuyConfirming, isSuccess: isBuySuccess } = 
    useWaitForTransactionReceipt({ hash: buyHash })
  
  // Effect to chain approve → buy in fallback flow
  const chainFallbackBuy = useCallback(() => {
    if (fallbackStep === 'approving' && isApproveSuccess) {
      setFallbackStep('buying')
      writeBuy({
        address: lotteryAddress,
        abi: LOTTERY_ABI,
        functionName: 'buyTickets',
        args: [ticketCount],
      })
    }
    if (fallbackStep === 'buying' && isBuySuccess) {
      setFallbackStep('done')
    }
  }, [fallbackStep, isApproveSuccess, isBuySuccess, writeBuy, lotteryAddress, ticketCount])
  
  // Trigger fallback chaining
  if (fallbackStep === 'approving' && isApproveSuccess) {
    chainFallbackBuy()
  }
  
  // === Main Action ===
  const buyTickets = useCallback(async () => {
    if (!address) throw new Error('Wallet not connected')
    
    if (supportsBatching) {
      // EIP-7702 Batched Flow: approve + buy in single atomic tx
      writeContracts({
        contracts: [
          {
            address: tokenAddress,
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [lotteryAddress, exactCost], // EXACT amount, not infinite
          },
          {
            address: lotteryAddress,
            abi: LOTTERY_ABI,
            functionName: 'buyTickets',
            args: [ticketCount],
          },
        ],
      })
    } else {
      // Fallback Two-Step Flow: approve first, then buy
      setFallbackStep('approving')
      writeApprove({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [lotteryAddress, exactCost], // EXACT amount, not infinite
      })
    }
  }, [
    address,
    supportsBatching,
    writeContracts,
    writeApprove,
    tokenAddress,
    lotteryAddress,
    exactCost,
    ticketCount,
  ])
  
  // === Reset ===
  const reset = useCallback(() => {
    resetBatch()
    resetApprove()
    resetBuy()
    setFallbackStep('idle')
  }, [resetBatch, resetApprove, resetBuy])
  
  // === Aggregate State ===
  const isLoading = supportsBatching
    ? false
    : isApproveConfirming || isBuyConfirming
  
  const isPending = supportsBatching
    ? isBatchPending || batchStatus?.status === 'PENDING'
    : isApprovePending || isBuyPending
  
  const isSuccess = supportsBatching
    ? batchStatus?.status === 'CONFIRMED'
    : isBuySuccess
  
  const error = supportsBatching
    ? batchError
    : approveError || buyError
  
  const txHash = supportsBatching
    ? batchStatus?.receipts?.[0]?.transactionHash
    : buyHash
  
  return {
    supportsBatching,
    isLoading,
    isPending,
    isSuccess,
    error: error as Error | null,
    txHash,
    buyTickets,
    reset,
  }
}

/**
 * Hook to check if wallet supports EIP-7702 batching on current chain
 */
export function useSupportsAtomicBatch(): boolean {
  const { chainId } = useAccount()
  const { data: capabilities } = useCapabilities()
  
  return useMemo(() => {
    if (!chainId || !capabilities) return false
    const chainCapabilities = capabilities[chainId]
    return chainCapabilities?.atomicBatch?.supported === true
  }, [chainId, capabilities])
}
