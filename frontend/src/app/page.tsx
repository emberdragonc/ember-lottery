'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { useState, useEffect } from 'react';

// Base Sepolia contract address (will update after deployment)
const LOTTERY_ADDRESS = '0x0000000000000000000000000000000000000000' as `0x${string}`;

const LOTTERY_ABI = [
  {
    name: 'currentLotteryId',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getLotteryInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_lotteryId', type: 'uint256' }],
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
    name: 'getTicketCount',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_lotteryId', type: 'uint256' }, { name: '_user', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'isLotteryActive',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'buyTickets',
    type: 'function',
    stateMutability: 'payable',
    inputs: [{ name: '_ticketCount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'endLottery',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const;

export default function LotteryPage() {
  const { address, isConnected } = useAccount();
  const [ticketCount, setTicketCount] = useState(1);
  const [timeLeft, setTimeLeft] = useState('');

  // Read current lottery ID
  const { data: lotteryId } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'currentLotteryId',
  });

  // Read lottery info
  const { data: lotteryInfo, refetch: refetchInfo } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'getLotteryInfo',
    args: lotteryId ? [lotteryId] : undefined,
  });

  // Read user's ticket count
  const { data: userTickets, refetch: refetchTickets } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'getTicketCount',
    args: lotteryId && address ? [lotteryId, address] : undefined,
  });

  // Read if lottery is active
  const { data: isActive } = useReadContract({
    address: LOTTERY_ADDRESS,
    abi: LOTTERY_ABI,
    functionName: 'isLotteryActive',
  });

  // Buy tickets
  const { writeContract: buyTickets, data: buyHash, isPending: isBuying } = useWriteContract();
  const { isLoading: isBuyConfirming, isSuccess: isBuySuccess } = useWaitForTransactionReceipt({ hash: buyHash });

  // End lottery
  const { writeContract: endLottery, data: endHash, isPending: isEnding } = useWriteContract();
  const { isLoading: isEndConfirming, isSuccess: isEndSuccess } = useWaitForTransactionReceipt({ hash: endHash });

  // Calculate time left
  useEffect(() => {
    if (!lotteryInfo) return;
    const endTime = Number(lotteryInfo[1]);
    
    const timer = setInterval(() => {
      const now = Math.floor(Date.now() / 1000);
      const remaining = endTime - now;
      
      if (remaining <= 0) {
        setTimeLeft('Ended');
        clearInterval(timer);
      } else {
        const hours = Math.floor(remaining / 3600);
        const minutes = Math.floor((remaining % 3600) / 60);
        const seconds = remaining % 60;
        setTimeLeft(`${hours}h ${minutes}m ${seconds}s`);
      }
    }, 1000);

    return () => clearInterval(timer);
  }, [lotteryInfo]);

  // Refetch on success
  useEffect(() => {
    if (isBuySuccess || isEndSuccess) {
      refetchInfo();
      refetchTickets();
    }
  }, [isBuySuccess, isEndSuccess, refetchInfo, refetchTickets]);

  const ticketPrice = lotteryInfo ? lotteryInfo[0] : BigInt(0);
  const totalPot = lotteryInfo ? lotteryInfo[2] : BigInt(0);
  const participantCount = lotteryInfo ? Number(lotteryInfo[3]) : 0;
  const winner = lotteryInfo ? lotteryInfo[4] : '0x0000000000000000000000000000000000000000';
  const ended = lotteryInfo ? lotteryInfo[5] : false;
  const canEnd = !isActive && !ended && lotteryId && lotteryId > BigInt(0);

  const handleBuy = () => {
    if (!ticketPrice) return;
    buyTickets({
      address: LOTTERY_ADDRESS,
      abi: LOTTERY_ABI,
      functionName: 'buyTickets',
      args: [BigInt(ticketCount)],
      value: ticketPrice * BigInt(ticketCount),
    });
  };

  const handleEnd = () => {
    endLottery({
      address: LOTTERY_ADDRESS,
      abi: LOTTERY_ABI,
      functionName: 'endLottery',
    });
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-zinc-950 via-zinc-900 to-black">
      {/* Navigation */}
      <nav className="border-b border-zinc-800/50 backdrop-blur-sm sticky top-0 z-50 bg-zinc-950/80">
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <a href="https://ember.engineer" className="flex items-center gap-3 group">
            <span className="text-3xl group-hover:animate-pulse">🎲</span>
            <div>
              <h1 className="text-xl font-bold text-white">Ember Lottery</h1>
              <p className="text-xs text-zinc-500">Built by Ember 🐉</p>
            </div>
          </a>
          <div className="flex items-center gap-6">
            <a 
              href="https://ember.engineer"
              className="text-zinc-400 hover:text-white transition-colors text-sm"
            >
              Den
            </a>
            <a 
              href="https://staking.ember.engineer"
              className="text-zinc-400 hover:text-white transition-colors text-sm"
            >
              Staking
            </a>
            <a 
              href="https://x.com/emberclawd" 
              target="_blank"
              rel="noopener noreferrer"
              className="text-zinc-400 hover:text-white transition-colors text-sm"
            >
              𝕏
            </a>
            <ConnectButton.Custom>
              {({ account, chain, openConnectModal, openAccountModal, mounted }) => {
                const connected = mounted && account && chain;
                return (
                  <button
                    onClick={connected ? openAccountModal : openConnectModal}
                    className="px-4 py-2 bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-500 hover:to-red-500 text-white text-sm font-medium rounded-lg transition-all"
                  >
                    {connected ? `${account.displayName}` : 'Connect'}
                  </button>
                );
              }}
            </ConnectButton.Custom>
          </div>
        </div>
      </nav>

      {/* Coming Soon Banner */}
      <div className="bg-gradient-to-r from-orange-600/20 to-red-600/20 border-y border-orange-500/30">
        <div className="max-w-6xl mx-auto px-4 py-3 text-center">
          <span className="text-orange-400 font-medium">🚧 Coming Soon</span>
          <span className="text-zinc-400 mx-2">—</span>
          <span className="text-zinc-300">Lottery is currently on testnet only. Mainnet launch coming soon!</span>
        </div>
      </div>

      {/* Header */}
      <section className="py-12 px-4 text-center">
        <h1 className="text-4xl font-bold text-white mb-2">
          🎲 Ember Lottery
        </h1>
        <p className="text-zinc-400">
          Buy tickets, win the pot! 5% fee supports $EMBER stakers
        </p>
      </section>

      {/* Lottery Stats */}
      <section className="max-w-4xl mx-auto px-4 pb-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-xl p-4 text-center">
            <p className="text-zinc-400 text-sm">Total Pot</p>
            <p className="text-2xl font-bold text-white">{formatEther(totalPot)} ETH</p>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-xl p-4 text-center">
            <p className="text-zinc-400 text-sm">Tickets Sold</p>
            <p className="text-2xl font-bold text-white">{participantCount}</p>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-xl p-4 text-center">
            <p className="text-zinc-400 text-sm">Ticket Price</p>
            <p className="text-2xl font-bold text-white">{formatEther(ticketPrice)} ETH</p>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-xl p-4 text-center">
            <p className="text-zinc-400 text-sm">Time Left</p>
            <p className="text-2xl font-bold text-orange-400">{timeLeft || 'N/A'}</p>
          </div>
        </div>
      </section>

      {/* Main Content */}
      <section className="max-w-2xl mx-auto px-4 pb-16">
        {!isConnected ? (
          <div className="text-center py-16 bg-zinc-900/30 border border-zinc-800 rounded-2xl flex flex-col items-center justify-center">
            <p className="text-zinc-400 mb-6">Connect your wallet to play</p>
            <div className="flex justify-center">
              <ConnectButton />
            </div>
          </div>
        ) : ended ? (
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-2xl p-8 text-center">
            <h2 className="text-2xl font-bold text-white mb-4">🏆 Lottery Ended!</h2>
            {winner !== '0x0000000000000000000000000000000000000000' ? (
              <>
                <p className="text-zinc-400 mb-2">Winner:</p>
                <p className="text-orange-400 font-mono text-lg break-all">{winner}</p>
                <p className="text-zinc-500 mt-4">Prize: {formatEther(totalPot * BigInt(95) / BigInt(100))} ETH</p>
              </>
            ) : (
              <p className="text-zinc-400">No participants</p>
            )}
          </div>
        ) : isActive ? (
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-2xl p-8">
            <h2 className="text-xl font-bold text-white mb-6 text-center">Buy Tickets</h2>
            
            {/* Your Tickets */}
            <div className="bg-zinc-800/50 rounded-lg p-4 mb-6 text-center">
              <p className="text-zinc-400 text-sm">Your Tickets</p>
              <p className="text-3xl font-bold text-orange-400">{userTickets?.toString() || '0'}</p>
            </div>

            {/* Ticket Selector */}
            <div className="mb-6">
              <label className="text-zinc-400 text-sm block mb-2">Number of Tickets</label>
              <div className="flex items-center gap-4">
                <button 
                  onClick={() => setTicketCount(Math.max(1, ticketCount - 1))}
                  className="w-12 h-12 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-white text-xl font-bold"
                >
                  -
                </button>
                <input 
                  type="number" 
                  value={ticketCount}
                  onChange={(e) => setTicketCount(Math.max(1, parseInt(e.target.value) || 1))}
                  className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3 text-white text-center text-xl font-bold"
                />
                <button 
                  onClick={() => setTicketCount(ticketCount + 1)}
                  className="w-12 h-12 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-white text-xl font-bold"
                >
                  +
                </button>
              </div>
            </div>

            {/* Cost */}
            <div className="bg-zinc-800/50 rounded-lg p-4 mb-6">
              <div className="flex justify-between text-zinc-400 text-sm">
                <span>Cost:</span>
                <span className="text-white font-bold">
                  {formatEther(ticketPrice * BigInt(ticketCount))} ETH
                </span>
              </div>
            </div>

            {/* Buy Button */}
            <button
              onClick={handleBuy}
              disabled={isBuying || isBuyConfirming}
              className="w-full py-4 bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-500 hover:to-red-500 disabled:from-zinc-600 disabled:to-zinc-700 text-white font-bold rounded-xl transition-all"
            >
              {isBuying ? 'Confirming...' : isBuyConfirming ? 'Buying...' : `Buy ${ticketCount} Ticket${ticketCount > 1 ? 's' : ''}`}
            </button>
          </div>
        ) : canEnd ? (
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-2xl p-8 text-center">
            <h2 className="text-xl font-bold text-white mb-4">⏰ Lottery Time's Up!</h2>
            <p className="text-zinc-400 mb-6">Click below to draw the winner</p>
            <button
              onClick={handleEnd}
              disabled={isEnding || isEndConfirming}
              className="px-8 py-4 bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-500 hover:to-red-500 disabled:from-zinc-600 disabled:to-zinc-700 text-white font-bold rounded-xl transition-all"
            >
              {isEnding ? 'Confirming...' : isEndConfirming ? 'Drawing...' : '🎰 Draw Winner'}
            </button>
          </div>
        ) : (
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-2xl p-8 text-center">
            <h2 className="text-xl font-bold text-white mb-4">No Active Lottery</h2>
            <p className="text-zinc-400">Check back soon for the next round!</p>
          </div>
        )}
      </section>

      {/* How It Works */}
      <section className="max-w-4xl mx-auto px-4 pb-16">
        <h2 className="text-2xl font-bold text-white mb-6 text-center">How It Works</h2>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-xl p-6 text-center">
            <div className="text-4xl mb-4">🎫</div>
            <h3 className="text-lg font-bold text-white mb-2">1. Buy Tickets</h3>
            <p className="text-zinc-400 text-sm">Each ticket gives you one entry. Buy more for better odds!</p>
          </div>
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-xl p-6 text-center">
            <div className="text-4xl mb-4">⏳</div>
            <h3 className="text-lg font-bold text-white mb-2">2. Wait for Draw</h3>
            <p className="text-zinc-400 text-sm">When time's up, anyone can trigger the winner selection.</p>
          </div>
          <div className="bg-zinc-900/30 border border-zinc-800 rounded-xl p-6 text-center">
            <div className="text-4xl mb-4">🏆</div>
            <h3 className="text-lg font-bold text-white mb-2">3. Win 95%</h3>
            <p className="text-zinc-400 text-sm">Winner takes 95% of the pot. 5% goes to $EMBER stakers.</p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-8 px-4 text-center text-zinc-500 text-sm">
        Built by Ember 🐉 | Part of the autonomous builder ecosystem
      </footer>
    </main>
  );
}
