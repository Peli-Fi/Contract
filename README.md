# Peli-Fi Sui Contract

A DeFi vault and market management smart contract built on Sui blockchain using Move language.

## Overview

Peli-Fi is a decentralized finance protocol that implements a **pooling vault system** with automated strategy execution. The protocol allows users to:
- Deposit tokens into a shared MasterVault with strategy allocation
- Select and switch between different investment strategies
- Have authorized operators (autobots) execute strategy deployments to markets
- Manage deposits and withdrawals securely with internal accounting

## Architecture

### Smart Contracts

The project consists of two main modules:

#### 1. `peli_fi_sui::peli_fi` (Main Protocol)

Core vault and market management system with the following components:

**Structs:**

| Struct | Description |
|--------|-------------|
| `MasterVault<T>` | Shared pooling vault that tracks user balances by strategy. All user funds are pooled here, with internal accounting separating deposits by strategy_id |
| `MarketVault<T>` | Destination liquidity pool where deployed funds earn yield. Funds move from MasterVault to MarketVault during strategy execution |
| `OperatorCap` | Authorization token held by autobots. Required to execute strategies (move funds from MasterVault to MarketVault) |
| `UserStrategyKey` | Composite key combining `owner` address + `strategy_id` for tracking user balances per strategy |

**Functions:**

| Function | Description |
|----------|-------------|
| `init()` | Initializes protocol, mints OperatorCap to deployer |
| `create_master_vault<T>()` | Creates the shared MasterVault (called once per token type) |
| `create_market<T>(name)` | Creates a MarketVault for deployed funds |
| `deposit<T>(vault, coin, strategy_id)` | Deposits tokens into MasterVault, credits user's balance for specific strategy |
| `withdraw<T>(vault, amount, strategy_id)` | Withdraws tokens from MasterVault (funds must be in pool, not deployed) |
| `select_strategy<T>(vault, amount, new_strategy_id)` | Moves user's balance from idle (strategy 0) to a new strategy |
| `execute_strategy<T>(cap, vault, market, amount)` | Autobot moves funds from MasterVault pool to MarketVault (requires OperatorCap) |
| `get_user_balance<T>(vault, user, strategy_id)` | Query user's balance for specific strategy (read-only) |
| `get_vault_pool_balance<T>(vault)` | Query total funds in MasterVault pool (read-only) |
| `get_market_balance<T>(market)` | Query total funds in MarketVault (read-only) |

#### 2. `peli_fi_sui::mock_token` (Test Token)

Mock token implementation for testing purposes:

**Features:**
- One-Time Witness (OTW) pattern for secure token creation
- 6 decimals (same as USDC)
- Mint function for testing via TreasuryCap
- Frozen metadata (immutable)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Sui CLI** - Install from [Sui documentation](https://docs.sui.io/guides/developer/getting-started/install)
- **Move Analyzer** - For Move code analysis
- **Node.js** (optional, for frontend integration)

## Installation

### Step 1: Clone the Repository

```bash
git clone <your-repository-url>
cd peli_fi_sui
```

### Step 2: Verify Move.toml Configuration

Check `Move.toml`:

```toml
[package]
name = "peli_fi_sui"
edition = "2024"

[dependencies]
```

### Step 3: Build the Contract

```bash
sui move build
```

This will compile all Move modules and verify the code.

## Testing

### Run All Tests

```bash
sui move test
```

### Run Specific Test

```bash
sui move test --filter test_autobot_flow
```

### Test Coverage

The test suite (`tests/peli_fi_tests.move`) covers the complete flow:

1. **Setup Phase**: Deploy both modules (peli_fi and mock_token)
2. **Infrastructure Setup**: Admin creates MasterVault and MarketVault, transfers OperatorCap to bot
3. **Token Distribution**: Mint tokens to user
4. **User Deposit**: User deposits 1000 tokens to MasterVault with strategy_id=1
5. **Strategy Execution**: Bot moves 600 tokens from MasterVault pool to MarketVault
6. **Verification**: Confirm remaining balance in MasterVault pool

## How the Logic Works (Detailed Explanation)

### Core Concept: Pooling with Internal Accounting

Peli-Fi uses a **pooling architecture** rather than individual vaults. This is more gas-efficient and enables better capital utilization:

```
┌─────────────────────────────────────────────────────────────┐
│                    MasterVault<T>                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Internal Accounting Table               │   │
│  │  UserStrategyKey (owner + strategy_id) → Balance    │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │  (@user1, strategy_0) → 500 tokens  (Idle)          │   │
│  │  (@user1, strategy_1) → 1000 tokens (Low Risk)      │   │
│  │  (@user2, strategy_1) → 2000 tokens (Low Risk)      │   │
│  │  (@user3, strategy_2) → 1500 tokens (High Yield)    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Pool Balance: 5000 tokens (physically in vault)           │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Patterns

#### 1. UserStrategyKey (Composite Key)
```move
public struct UserStrategyKey has copy, drop, store {
    owner: address,      // User's wallet address
    strategy_id: u64     // Strategy identifier (0 = idle)
}
```

This composite key allows a single user to have balances across multiple strategies simultaneously.

#### 2. Strategy ID System
- **Strategy 0**: Idle - Default state when funds are deposited but not allocated
- **Strategy 1+**: Active strategies (Low Risk, High Yield, etc.)
- Users can move funds between strategies using `select_strategy()`

#### 3. Two-Balance System
The contract tracks balances in two ways:
- **Internal Accounting**: User's recorded balance per strategy (what they own)
- **Pool Balance**: Actual tokens physically in the MasterVault (available for withdrawal/deployment)

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT PHASE                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Admin/Deployer (@0xAD)
    │
    ├── deploy peli_fi_sui package
    │   └── receives OperatorCap ──┐
    │                              │
    ├── create_master_vault<MOCK_TOKEN>() → Shared MasterVault created
    │
    ├── create_market<MOCK_TOKEN>("Low Risk Market") → Shared MarketVault created
    │
    └── transfer OperatorCap → Bot (@0xBB)
                                    (Bot now has authority to execute strategies)


┌─────────────────────────────────────────────────────────────────────────────┐
│                        USER DEPOSIT FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

User (@0x42) with 1000 MOCK tokens
    │
    ├── Call: deposit(vault, 1000_coin, strategy_id=1)
    │
    ├── MasterVault Internal Accounting:
    │   └── Add UserStrategyKey(@0x42, 1) → 1000
    │
    ├── MasterVault Total by Strategy:
    │   └── strategy_id=1 → +1000
    │
    └── Physical Pool:
        └── balance::join(pool, 1000) → Pool now has 1000 tokens


┌─────────────────────────────────────────────────────────────────────────────┐
│                  STRATEGY SELECTION FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

User wants to move 500 tokens from Idle (strategy 0) to Strategy 1
    │
    ├── Call: select_strategy(vault, amount=500, new_strategy_id=1)
    │
    ├── Prerequisite: User must have balance in strategy 0 (Idle)
    │   (User deposits initially go to idle, then select active strategy)
    │
    ├── Internal Accounting Changes:
    │   ├── UserStrategyKey(@user, 0) → -500
    │   └── UserStrategyKey(@user, 1) → +500
    │
    └── No physical token movement (just accounting entries)


┌─────────────────────────────────────────────────────────────────────────────┐
│                  BOT EXECUTION FLOW (Strategy Deployment)                   │
└─────────────────────────────────────────────────────────────────────────────┘

Bot (@0xBB) with OperatorCap
    │
    ├── Call: execute_strategy(cap, vault, market, amount=600)
    │
    ├── Authorization Check:
    │   └── OperatorCap is required (only bot has it)
    │
    ├── Balance Check:
    │   └── pool.balance >= 600 (sufficient funds available)
    │
    ├── Physical Token Movement:
    │   ├── MasterVault Pool: balance::split(pool, 600)
    │   └── MarketVault: balance::join(market.liquidity, 600)
    │
    └── Result:
        ├── MasterVault pool: 1000 → 400 tokens
        └── MarketVault liquidity: 0 → 600 tokens


┌─────────────────────────────────────────────────────────────────────────────┐
│                      WITHDRAWAL FLOW                                         │
└─────────────────────────────────────────────────────────────────────────────┘

User (@0x42) wants to withdraw 300 tokens from Strategy 1
    │
    ├── Call: withdraw(vault, amount=300, strategy_id=1)
    │
    ├── Authorization Check:
    │   └── tx_context::sender() == UserStrategyKey.owner ✓
    │
    ├── Internal Balance Check:
    │   └── UserStrategyKey(@user, 1) >= 300 ✓
    │
    ├── Pool Availability Check:
    │   └── pool.balance >= 300
    │   (IMPORTANT: If funds are deployed in MarketVault, withdrawal fails!)
    │
    ├── Internal Accounting Update:
    │   ├── UserStrategyKey(@user, 1) → -300
    │   └── total_by_strategy[1] → -300
    │
    └── Physical Transfer:
        └── coin::from_balance(balance::split(pool, 300)) → transfer to user
```

### Critical Security Constraints

1. **Withdrawal Restriction**: Users can only withdraw if funds are physically in the MasterVault pool. If the bot has deployed funds to MarketVault, the user must wait for the bot to return them.

2. **Strategy Selection**: Users must first have funds in "idle" (strategy 0) to select a new strategy. This creates a two-step process:
   - Deposit → gets credited to strategy 0
   - Select strategy → moves from strategy 0 to target strategy

3. **Operator Authorization**: Only the holder of OperatorCap can execute strategies (move funds to markets). This is the bot's exclusive permission.

### Frontend Integration

The contract provides three getter functions for UI display:

```move
// Get specific user's balance in a strategy
get_user_balance(vault, @user_address, strategy_id) → u64

// Get total funds sitting in MasterVault pool (not deployed)
get_vault_pool_balance(vault) → u64

// Get total funds deployed in a specific market
get_market_balance(market) → u64
```

### Error Handling

| Code | Constant | When Triggered |
|------|----------|----------------|
| 1 | `ENotAuthorized` | Reserved for future authorization checks |
| 2 | `EInsufficientBalance` | User doesn't have enough recorded balance OR pool doesn't have enough physical tokens |

## Deployment

### Published Addresses

The contract is already deployed on Sui Testnet:

- **Package ID**: `0xbeae85386af05931e3ab66f9cc22c795010b8b7eb0520a23476ad0c9d89b611b`
- **Chain ID**: `4c78adac` (testnet)
- **Upgrade Capability**: `0x76bdd90087b7706ed4f7cbe51e449b70025e266a1f19b81bcc75babe41a19818`

### Deploy to Testnet

```bash
# 1. Configure your testnet address in sui client
sui client new-address --ed25519

# 2. Request testnet SUI from faucet
# Visit: https://faucet.sui.io/

# 3. Publish the package
sui client publish --gas-budget 100000000
```

### Deploy to Mainnet

```bash
# Switch to mainnet
sui client switch --env mainnet

# Publish
sui client publish --gas-budget 100000000
```

## Usage Examples

### Example 1: Admin Setup

```move
// Admin creates the MasterVault and MarketVault
public entry fun setup_protocol(ctx: &mut TxContext) {
    peli_fi::create_master_vault<USDC>(ctx);
    peli_fi::create_market<USDC>(b"Low Risk Strategy", ctx);
    peli_fi::create_market<USDC>(b"High Yield Strategy", ctx);
}
```

### Example 2: User Depositing to MasterVault

```move
// User deposits 1000 MOCK tokens to strategy 1 (Low Risk)
let coin = coin::split(&mut coins, 1000, ctx);
peli_fi::deposit(&mut vault, coin, 1, ctx);

// This:
// 1. Adds 1000 tokens to the physical pool
// 2. Credits UserStrategyKey(@user, 1) with 1000
// 3. Increases total_by_strategy[1] by 1000
```

### Example 3: User Selecting Strategy

```move
// User moves 500 tokens from idle (0) to strategy 2 (High Yield)
peli_fi::select_strategy(&mut vault, 500, 2, ctx);

// This:
// 1. Decreases UserStrategyKey(@user, 0) by 500
// 2. Increases UserStrategyKey(@user, 2) by 500
// 3. Updates total_by_strategy[2] accordingly
// No physical tokens move (just accounting)
```

### Example 4: Autobot Execution

```move
// Autobot moves 500 tokens from MasterVault pool to MarketVault
peli_fi::execute_strategy(
    &operator_cap,
    &mut master_vault,
    &mut market_vault,
    500,
    ctx
);

// This:
// 1. Verifies OperatorCap (only bot can do this)
// 2. Checks pool has >= 500 tokens
// 3. Physically moves tokens: MasterVault.pool → MarketVault.total_liquidity
// NOTE: Internal accounting doesn't change - users still own their recorded amounts
```

### Example 5: User Withdrawal

```move
// User withdraws 300 tokens from strategy 1
peli_fi::withdraw(&mut vault, 300, 1, ctx);

// This:
// 1. Verifies caller is the owner
// 2. Checks UserStrategyKey(@user, 1) >= 300
// 3. Checks pool.balance >= 300 (physical availability)
// 4. Decreases internal accounting
// 5. Transfers 300 tokens to user's wallet
```

## Error Codes

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 1 | `ENotAuthorized` | Caller is not the vault owner |
| 2 | `EInsufficientBalance` | Vault has insufficient balance |

## Project Structure

```
peli_fi_sui/
├── sources/
│   ├── peli_fi_sui.move       # Main protocol (MasterVault, MarketVault, operations)
│   └── mock_token.move         # Mock token (MOCK_TOKEN) for testing
├── tests/
│   ├── peli_fi_tests.move      # Integration tests for full flow
│   └── peli_fi_sui_tests.move  # Placeholder tests (commented out)
├── build/                      # Compiled Move bytecode (auto-generated)
│   └── peli_fi_sui/
│       └── sources/
│           ├── peli_fi.move    # Compiled main protocol
│           ├── mock_token.move # Compiled mock token
│           └── dependencies/   # Sui framework dependencies
├── playground/                 # Test/development scripts
├── Move.toml                   # Package configuration (edition 2024)
├── Move.lock                   # Dependency lock file
├── Published.toml              # Deployment metadata
└── README.md                   # This file
```

## Security Considerations

1. **Owner-Only Withdrawals**: Users can only withdraw from their own balances. The contract verifies `tx_context::sender()` matches the `UserStrategyKey.owner`.

2. **Operator Authorization**: Strategy execution (moving funds to markets) requires a valid OperatorCap. Only authorized autobots can execute strategies.

3. **Dual Balance Validation**: Withdrawals check both:
   - Internal accounting: User's recorded balance
   - Physical pool: Actual tokens available (not deployed)

4. **Shared Objects**: Both MasterVault and MarketVault are shared objects, enabling concurrent access by all users.

5. **Strategy Isolation**: Each user's balance is tracked separately per strategy using composite keys, preventing cross-contamination.

6. **No Reentrancy**: The contract follows Sui's object-oriented model which naturally prevents reentrancy attacks.

## Development Workflow

### Making Changes

1. Edit source files in `sources/`
2. Run tests: `sui move test`
3. Build to verify: `sui move build`
4. Commit changes

### Upgrading Contract

Since the package uses an upgrade capability, the deployer can upgrade:

```bash
sui client upgrade --package-id <package-id> --gas-budget 100000000
```

## Future Enhancements

Potential improvements to consider:

- [ ] **Strategy Return Flow**: Add `execute_strategy_return()` to move funds from MarketVault back to MasterVault
- [ ] **Yield Distribution**: Implement reward distribution from MarketVault yields to users based on their strategy shares
- [ ] **Emergency Withdraw**: Add admin-controlled emergency withdrawal capability
- [ ] **Strategy Metadata**: Store strategy names, risk levels, and APY data on-chain
- [ ] **Performance Tracking**: Track historical returns per strategy
- [ ] **Multi-Token Support**: Enable cross-strategy token swaps
- [ ] **Time-Locks**: Add locking periods for strategy deposits to encourage long-term participation
- [ ] **Fee Mechanism**: Add protocol fees on strategy execution or yield generation


## License

This project is provided as-is for educational and development purposes. Please specify your chosen license (e.g., MIT, Apache 2.0, GPL) before production deployment.

## Resources

- [Sui Documentation](https://docs.sui.io/)
- [Move Language Guide](https://move-language.github.io/move/)
- [Sui Discord](https://discord.gg/sui)
- [Sui Explorer (Testnet)](https://suiscan.xyz/testnet)

---

**Built with ❤️ for Sui ecosystem**
