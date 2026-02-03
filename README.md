# Peli-Fi Sui Contract

A DeFi vault and market management smart contract built on Sui blockchain using Move language.

## Overview

Peli-Fi is a decentralized finance protocol that allows users to:
- Create personal vaults to deposit tokens
- Deploy market vaults for liquidity pooling
- Execute automated strategies through authorized operators (autobots)
- Manage deposits and withdrawals securely

## Architecture

### Smart Contracts

The project consists of two main modules:

#### 1. `peli_fi_sui::peli_fi` (Main Protocol)

Core vault and market management system with the following components:

**Structs:**
- `PersonalVault<T>` - Individual user vault for storing tokens
- `MarketVault<T>` - Shared market pool for liquidity
- `OperatorCap` - Authorization token for strategy execution (autobot)

**Functions:**
- `init()` - Initializes the protocol and mints OperatorCap to deployer
- `create_market<T>(name)` - Creates a new market vault for a specific token type
- `create_vault<T>()` - Creates a personal vault for the caller
- `deposit_to_vault<T>(vault, coin)` - Deposits tokens into a personal vault
- `execute_strategy<T>(cap, vault, market, amount)` - Executes strategy (moves funds from vault to market)
- `withdraw_from_vault<T>(vault, amount)` - Withdraws tokens from vault (owner only)

#### 2. `peli_fi_sui::mock_token` (Test Token)

Mock token implementation for testing purposes:

**Features:**
- One-Time Witness (OTW) pattern for secure token creation
- 6 decimals (same as USDC)
- Mint function for testing
- TreasuryCap management

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
2. **Token Distribution**: Mint tokens and transfer OperatorCap to bot
3. **Market Creation**: Admin creates a market vault
4. **Vault Creation**: User creates a personal vault
5. **Deposit**: User deposits tokens into their vault
6. **Strategy Execution**: Bot moves funds from vault to market using OperatorCap

## Contract Flow

### 1. Deployment

```
Admin/Deployer
    ↓
deploy peli_fi_sui package
    ↓
receives OperatorCap
    ↓
transfers OperatorCap to Autobot
```

### 2. User Onboarding

```
User
    ↓
create_vault<T>()
    ↓
receives PersonalVault object
    ↓
deposit_to_vault(coin)
```

### 3. Strategy Execution (Autobot Flow)

```
Autobot (holds OperatorCap)
    ↓
execute_strategy(cap, vault, market, amount)
    ↓
funds move from PersonalVault → MarketVault
```

### 4. Withdrawal

```
User (vault owner)
    ↓
withdraw_from_vault(amount)
    ↓
receives tokens
```

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

### Example 1: Creating a Market

```move
// Admin creates a new market for USDC
public entry fun create_market_usdc(ctx: &mut TxContext) {
    peli_fi::create_market<USDC>(b"USDC High Yield", ctx);
}
```

### Example 2: User Depositing to Vault

```move
// User deposits 1000 MOCK tokens
let coin = coin::split(&mut coins, 1000, ctx);
peli_fi::deposit_to_vault(&mut vault, coin);
```

### Example 3: Autobot Execution

```move
// Autobot moves 500 tokens from vault to market
peli_fi::execute_strategy(
    &operator_cap,
    &mut user_vault,
    &mut market_vault,
    500,
    ctx
);
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 1 | `ENotAuthorized` | Caller is not the vault owner |
| 2 | `EInsufficientBalance` | Vault has insufficient balance |

## Project Structure

```
peli_fi_sui/
├── sources/
│   ├── peli_fi_sui.move       # Main protocol (vaults & markets)
│   └── mock_token.move         # Mock token for testing
├── tests/
│   ├── peli_fi_tests.move      # Integration tests
│   └── peli_fi_sui_tests.move  # Placeholder tests
├── Move.toml                   # Package configuration
├── Published.toml              # Deployment metadata
└── README.md                   # This file
```

## Security Considerations

1. **Owner-Only Withdrawals**: Only vault owners can withdraw funds
2. **Operator Authorization**: Strategy execution requires valid OperatorCap
3. **Balance Checks**: All transfers verify sufficient balance before execution
4. **Shared Objects**: Vaults and markets are shared objects for global access

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

- [ ] Add yield rewards distribution
- [ ] Implement multiple strategies per vault
- [ ] Add time-locked withdrawals
- [ ] Create governance for strategy parameters
- [ ] Add multi-signature for critical operations
- [ ] Implement strategy performance tracking


## License

Specify your license here (e.g., MIT, Apache 2.0)

## Resources

- [Sui Documentation](https://docs.sui.io/)
- [Move Language Guide](https://move-language.github.io/move/)
- [Sui Discord](https://discord.gg/sui)
- [Sui Explorer (Testnet)](https://suiscan.xyz/testnet)

## Support

For questions or issues:
- Open an issue on GitHub
- Contact the development team
- Join our community Discord

---

**Built with ❤️ for Sui ecosystem**
