module peli_fi_sui::peli_fi {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    // --- 1. ERRORS (Constant harus ada supaya tidak 'unbound constant') ---
    const ENotAuthorized: u64 = 1;
    const EInsufficientBalance: u64 = 2;

    // --- 2. OBJECTS (Struct harus didefinisikan sebelum dipakai di fungsi) ---

    public struct PersonalVault<phantom T> has key {
        id: UID,
        owner: address,
        balance: Balance<T>,
    }

    public struct MarketVault<phantom T> has key {
        id: UID,
        asset_name: vector<u8>,
        total_liquidity: Balance<T>,
    }

    public struct OperatorCap has key, store {
        id: UID,
    }

    // --- 3. FUNCTIONS ---

    fun init(ctx: &mut TxContext) {
        let cap = OperatorCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    public fun create_market<T>(name: vector<u8>, ctx: &mut TxContext) {
        let market = MarketVault<T> {
            id: object::new(ctx),
            asset_name: name,
            total_liquidity: balance::zero(),
        };
        transfer::share_object(market);
    }

    public fun create_vault<T>(ctx: &mut TxContext) {
        let vault = PersonalVault<T> {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            balance: balance::zero(),
        };
        transfer::share_object(vault);
    }

    public fun deposit_to_vault<T>(vault: &mut PersonalVault<T>, coin: Coin<T>) {
        let coin_balance = coin::into_balance(coin);
        balance::join(&mut vault.balance, coin_balance);
    }

    public fun execute_strategy<T>(
        _cap: &OperatorCap, 
        vault: &mut PersonalVault<T>, 
        market: &mut MarketVault<T>, 
        amount: u64, 
        _ctx: &mut TxContext
    ) {
        assert!(balance::value(&vault.balance) >= amount, EInsufficientBalance);
        let split_balance = balance::split(&mut vault.balance, amount);
        balance::join(&mut market.total_liquidity, split_balance);
    }

    public fun withdraw_from_vault<T>(vault: &mut PersonalVault<T>, amount: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == vault.owner, ENotAuthorized);
        let split_balance = balance::split(&mut vault.balance, amount);
        let coin = coin::from_balance(split_balance, ctx);
        transfer::public_transfer(coin, vault.owner);
    }
}