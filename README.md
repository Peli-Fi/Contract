# Peli-Fi Sui Contract

A DeFi vault protocol on Sui blockchain with pooling vaults, strategy selection, and automated execution.

## What It Does

- **Pooling Vault**: Users deposit tokens into a shared `MasterVault` with internal accounting per strategy
- **Strategy Selection**: Users can allocate funds to different investment strategies
- **Automated Execution**: Authorized autobots deploy funds from `MasterVault` to `MarketVault` to earn yield
- **Secure Withdrawals**: Users withdraw from their allocated strategy (when funds are available in pool)

## Key Components

| Component | Description |
|-----------|-------------|
| `MasterVault<T>` | Shared vault where all user funds are pooled |
| `MarketVault<T>` | Destination vault where deployed funds earn yield |
| `OperatorCap` | Authorization token that allows autobots to execute strategies |
| `UserStrategyKey` | Composite key (owner + strategy_id) tracking user balances |

## Quick Start

### Prerequisites

```bash
# Install Sui CLI
# Visit: https://docs.sui.io/guides/developer/getting-started/install
```

### Build

```bash
sui move build
```

### Test

```bash
# Run all tests
sui move test

# Run specific test
sui move test --filter test_autobot_flow
```

## Main Functions

| Function | Description |
|----------|-------------|
| `create_master_vault<T>()` | Create shared vault (once per token type) |
| `create_market<T>(name)` | Create a market vault for deployed funds |
| `deposit<T>(vault, coin, strategy_id)` | Deposit tokens into vault |
| `withdraw<T>(vault, amount, strategy_id)` | Withdraw tokens (must be in pool) |
| `select_strategy<T>(vault, amount, new_strategy_id)` | Move funds from idle to a strategy |
| `execute_strategy<T>(cap, vault, market, amount)` | Bot moves funds to market (requires OperatorCap) |

## How It Works

```
User Deposit (1000 tokens, strategy_id=1)
    ↓
MasterVault (Pool: 1000, User@strategy_1: 1000)
    ↓
Bot executes_strategy (600 tokens)
    ↓
MasterVault (Pool: 400) → MarketVault (Liquidity: 600)
```

**Important**: Users can only withdraw if funds are physically in `MasterVault` pool. If bot deployed funds to `MarketVault`, user must wait for bot to return them.

## Frontend Getters

```move
// Get user's balance in a strategy
get_user_balance(vault, @user_address, strategy_id) → u64

// Get total funds in MasterVault pool (not deployed)
get_vault_pool_balance(vault) → u64

// Get total funds deployed in a market
get_market_balance(market) → u64
```

## Deployment

**Deployed on Sui Testnet:**
- Package ID: `0xbeae85386af05931e3ab66f9cc22c795010b8b7eb0520a23476ad0c9d89b611b`
- Chain ID: `4c78adac` (testnet)

### Deploy Yourself

```bash
# Testnet
sui client publish --gas-budget 100000000

# Mainnet
sui client switch --env mainnet
sui client publish --gas-budget 100000000
```

## Project Structure

```
peli_fi_sui/
├── sources/
│   ├── peli_fi_sui.move       # Main protocol
│   └── mock_token.move         # Test token with faucet
├── tests/
│   └── peli_fi_tests.move      # Integration tests
├── Move.toml                   # Package config
└── Published.toml              # Deployment metadata
```

## Error Codes

| Code | Error |
|------|-------|
| 1 | `ENotAuthorized` |
| 2 | `EInsufficientBalance` |

## Resources

- [Sui Documentation](https://docs.sui.io/)
- [Move Language Guide](https://move-language.github.io/move/)
- [Sui Explorer (Testnet)](https://suiscan.xyz/testnet)
