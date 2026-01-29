# 🎲 EmberLottery

Simple lottery contract with EIP-7702 smart wallet support for batched approve+buy transactions.

## Features

- 🎫 Buy tickets with ETH (EmberLottery) or ERC20 tokens (EmberLotteryERC20)
- 🎰 Random winner selection (blockhash-based)
- 💰 5% fee sent to staking contract
- 🔒 Built with Solady for gas efficiency
- ⚡ **EIP-7702 Compatible** - No tx.origin checks, works with account abstraction
- 🔐 **Exact Approvals** - No infinite approvals, approve only what you spend

## EIP-7702 Support

This project is designed for the EIP-7702 smart wallet era:

### Contract
- ✅ No `tx.origin` checks anywhere
- ✅ Uses `msg.sender` throughout (works with delegated accounts)
- ✅ `getTicketCost()` helper for calculating exact approval amounts

### Frontend
- ✅ Detects wallet capabilities via `useCapabilities()`
- ✅ **If batching supported**: Atomic approve + buyTickets in single transaction
- ✅ **If not supported**: Graceful fallback to two-step flow
- ✅ Uses **exact approval amounts** (not infinite approvals)

## Test Results

```
✓ 38 tests passing (25 ETH + 13 ERC20)
✓ Fuzz tests included
✓ Full integration tests
```

## Contracts

| Contract | Description |
|----------|-------------|
| EmberLottery | ETH lottery with commit-reveal |
| EmberLotteryERC20 | ERC20 lottery with exact approvals |

## How It Works

### ETH Lottery
1. Owner starts a lottery with ticket price and duration
2. Users buy tickets with ETH
3. After duration ends, anyone can call `endLottery()`
4. Winner selected pseudo-randomly, gets 95% of pot
5. 5% fee sent to staking contract

### ERC20 Lottery (7702 Optimized)
1. Owner starts a lottery with ticket price and duration
2. Users approve EXACT amount via `getTicketCost(ticketCount)`
3. With EIP-7702 smart wallets: approve + buy batched in one tx
4. Winner selected, gets 95% of pot in tokens

## Frontend Usage

```typescript
import { useBuyTickets, useSupportsAtomicBatch } from '@/hooks/useEIP7702'

// Check if wallet supports batching
const supportsBatching = useSupportsAtomicBatch()

// Buy tickets with automatic batching detection
const { buyTickets, isLoading, isSuccess } = useBuyTickets({
  tokenAddress: TOKEN_ADDRESS,
  lotteryAddress: LOTTERY_ADDRESS,
  ticketCount: BigInt(5),
  exactCost: ticketCost, // From getTicketCost(5)
})

// UI shows different messaging based on batching support
{supportsBatching 
  ? "⚡ Smart Wallet - 1 transaction" 
  : "Standard Wallet - 2 transactions"}
```

## Running Frontend

```bash
cd frontend
npm install
cp .env.example .env.local
# Edit .env.local with your contract addresses
npm run dev
```

## Security Notes

⚠️ Uses `blockhash` for randomness - **upgrade to Chainlink VRF for production**

---

Built by Ember 🐉 | EIP-7702 Ready
