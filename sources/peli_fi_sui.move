module peli_fi_sui::peli_fi {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};

    // --- Errors ---
    const ENotAuthorized: u64 = 1;
    const EInsufficientBalance: u64 = 2;

    // Key untuk membedakan saldo user berdasarkan Strategy ID
    public struct UserStrategyKey has copy, drop, store {
        owner: address,
        strategy_id: u64
    }

    // Ini adalah MasterVault (Pooling) - Hanya dideploy 1x
    public struct MasterVault<phantom T> has key {
        id: UID,
        // Buku kas internal: (Alamat User + Strategy ID) -> Saldo
        user_balances: Table<UserStrategyKey, u64>,
        // Total dana kolektif yang ada di dalam Vault ini
        pool: Balance<T>,
        // Catatan total per strategi untuk Bot
        total_by_strategy: Table<u64, u64>
    }

    public struct MarketVault<phantom T> has key {
        id: UID,
        asset_name: vector<u8>,
        total_liquidity: Balance<T>,
    }

    // Izin khusus untuk Bot
    public struct OperatorCap has key, store {
        id: UID,
    }

    // --- Functions ---

    fun init(ctx: &mut TxContext) {
        let cap = OperatorCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    // Membuat MasterVault tunggal
    public entry fun create_master_vault<T>(ctx: &mut TxContext) {
        let vault = MasterVault<T> {
            id: object::new(ctx),
            user_balances: table::new(ctx),
            pool: balance::zero(),
            total_by_strategy: table::new(ctx),
        };
        transfer::share_object(vault);
    }

    // User Deposit: Masuk ke pool besar & catat di tabel
    public entry fun deposit<T>(
        vault: &mut MasterVault<T>, 
        coin: Coin<T>, 
        strategy_id: u64, 
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&coin);
        let sender = tx_context::sender(ctx);
        let key = UserStrategyKey { owner: sender, strategy_id };

        let coin_balance = coin::into_balance(coin);
        balance::join(&mut vault.pool, coin_balance);

        if (table::contains(&vault.user_balances, key)) {
            let current_bal = table::borrow_mut(&mut vault.user_balances, key);
            *current_bal = *current_bal + amount;
        } else {
            table::add(&mut vault.user_balances, key, amount);
        };

        if (table::contains(&vault.total_by_strategy, strategy_id)) {
            let total = table::borrow_mut(&mut vault.total_by_strategy, strategy_id);
            *total = *total + amount;
        } else {
            table::add(&mut vault.total_by_strategy, strategy_id, amount);
        };
    }

    // --- FITUR BARU: WITHDRAW ---
    // User menarik uang kembali ke dompet mereka
    public entry fun withdraw<T>(
        vault: &mut MasterVault<T>,
        amount: u64,
        strategy_id: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let key = UserStrategyKey { owner: sender, strategy_id };

        // 1. Cek catatan saldo user
        assert!(table::contains(&vault.user_balances, key), EInsufficientBalance);
        let user_bal = table::borrow_mut(&mut vault.user_balances, key);
        assert!(*user_bal >= amount, EInsufficientBalance);

        // 2. Cek apakah di pool fisik MasterVault ada uangnya (tidak sedang di Market)
        assert!(balance::value(&vault.pool) >= amount, EInsufficientBalance);

        // 3. Update catatan
        *user_bal = *user_bal - amount;
        let total_strat = table::borrow_mut(&mut vault.total_by_strategy, strategy_id);
        *total_strat = *total_strat - amount;

        // 4. Transfer fisik
        let split_balance = balance::split(&mut vault.pool, amount);
        let coin = coin::from_balance(split_balance, ctx);
        transfer::public_transfer(coin, sender);
    }

    // Bot Execute Strategy
    public entry fun execute_strategy<T>(
        _cap: &OperatorCap, 
        vault: &mut MasterVault<T>, 
        market: &mut MarketVault<T>, 
        amount: u64, 
        _ctx: &mut TxContext
    ) {
        assert!(balance::value(&vault.pool) >= amount, EInsufficientBalance);
        let split_balance = balance::split(&mut vault.pool, amount);
        balance::join(&mut market.total_liquidity, split_balance);
    }

    public entry fun create_market<T>(name: vector<u8>, ctx: &mut TxContext) {
        let market = MarketVault<T> {
            id: object::new(ctx),
            asset_name: name,
            total_liquidity: balance::zero(),
        };
        transfer::share_object(market);
    }

    // Pindah dari Idle (ID 0) ke Strategi baru
    public entry fun select_strategy<T>(
        vault: &mut MasterVault<T>,
        amount: u64,
        new_strategy_id: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let idle_key = UserStrategyKey { owner: sender, strategy_id: 0 };
        let target_key = UserStrategyKey { owner: sender, strategy_id: new_strategy_id };

        assert!(table::contains(&vault.user_balances, idle_key), EInsufficientBalance);
        let idle_bal = table::borrow_mut(&mut vault.user_balances, idle_key);
        assert!(*idle_bal >= amount, EInsufficientBalance);

        *idle_bal = *idle_bal - amount;

        if (table::contains(&vault.user_balances, target_key)) {
            let target_bal = table::borrow_mut(&mut vault.user_balances, target_key);
            *target_bal = *target_bal + amount;
        } else {
            table::add(&mut vault.user_balances, target_key, amount);
        };

        if (table::contains(&vault.total_by_strategy, new_strategy_id)) {
            let total = table::borrow_mut(&mut vault.total_by_strategy, new_strategy_id);
            *total = *total + amount;
        } else {
            table::add(&mut vault.total_by_strategy, new_strategy_id, amount);
        };
    }

    // --- FITUR BARU: GETTERS (Untuk Frontend UI) ---

    // Mengambil saldo spesifik user berdasarkan alamat dan strategy_id
    public fun get_user_balance<T>(vault: &MasterVault<T>, user: address, strategy_id: u64): u64 {
        let key = UserStrategyKey { owner: user, strategy_id };
        if (table::contains(&vault.user_balances, key)) {
            *table::borrow(&vault.user_balances, key)
        } else {
            0
        }
    }

    // Mengambil total dana yang ada di MasterVault
    public fun get_vault_pool_balance<T>(vault: &MasterVault<T>): u64 {
        balance::value(&vault.pool)
    }

    // Mengambil total dana yang ada di Market tertentu
    public fun get_market_balance<T>(market: &MarketVault<T>): u64 {
        balance::value(&market.total_liquidity)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let cap = OperatorCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }
}