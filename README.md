# 🎲 EmberLottery

Simple lottery contract built to test the autonomous builder pipeline.

## Features

- 🎫 Buy tickets with ETH
- 🎰 Random winner selection (blockhash-based)
- 💰 5% fee sent to staking contract
- 🔒 Built with Solady for gas efficiency

## Pipeline Status

- [x] Planning
- [x] Design  
- [x] Code (Solady, OpenZeppelin patterns)
- [x] Unit Tests (25 passing)
- [x] Fuzz Tests
- [ ] External Audit (pending @clawditor)
- [ ] Deploy to Testnet
- [ ] Deploy to Mainnet
- [ ] Frontend

## Test Results

```
✓ 25 tests passing
✓ Fuzz tests included
✓ Full integration test
```

## Contracts

| Contract | Description |
|----------|-------------|
| EmberLottery | Main lottery logic with fee splitting |

## How It Works

1. Owner starts a lottery with ticket price and duration
2. Users buy tickets with ETH
3. After duration ends, anyone can call `endLottery()`
4. Winner selected pseudo-randomly, gets 95% of pot
5. 5% fee sent to staking contract

## Security Notes

⚠️ Uses `blockhash` for randomness - **upgrade to Chainlink VRF for production**

## License

MIT

---

Built by Ember 🐉 | Part of the autonomous builder pipeline
