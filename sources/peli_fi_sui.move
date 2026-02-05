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
        // Berikan OperatorCap ke pengirim transaksi (Bot/Admin)
        let cap = OperatorCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    // Membuat MasterVault tunggal (Hanya panggil 1x saat deploy)
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

        // 1. Masukkan koin ke pool utama
        let coin_balance = coin::into_balance(coin);
        balance::join(&mut vault.pool, coin_balance);

        // 2. Update catatan saldo user di tabel
        if (table::contains(&vault.user_balances, key)) {
            let current_bal = table::borrow_mut(&mut vault.user_balances, key);
            *current_bal = *current_bal + amount;
        } else {
            table::add(&mut vault.user_balances, key, amount);
        };

        // 3. Update total per strategi untuk Bot
        if (table::contains(&vault.total_by_strategy, strategy_id)) {
            let total = table::borrow_mut(&mut vault.total_by_strategy, strategy_id);
            *total = *total + amount;
        } else {
            table::add(&mut vault.total_by_strategy, strategy_id, amount);
        };
    }

    // Bot Execute Strategy: Memindahkan dana kolektif ke Market
    public entry fun execute_strategy<T>(
        _cap: &OperatorCap, 
        vault: &mut MasterVault<T>, 
        market: &mut MarketVault<T>, 
        amount: u64, 
        _ctx: &mut TxContext
    ) {
        assert!(balance::value(&vault.pool) >= amount, EInsufficientBalance);
        
        // Ambil dari pool besar MasterVault
        let split_balance = balance::split(&mut vault.pool, amount);
        
        // Pindahkan ke MarketVault (DeFi Protocol)
        balance::join(&mut market.total_liquidity, split_balance);
    }

    // Create Market (Sama seperti sebelumnya)
    public entry fun create_market<T>(name: vector<u8>, ctx: &mut TxContext) {
        let market = MarketVault<T> {
            id: object::new(ctx),
            asset_name: name,
            total_liquidity: balance::zero(),
        };
        transfer::share_object(market);
    }

  public fun init_for_testing(ctx: &mut TxContext) {
        // Jangan panggil init(ctx), tapi tulis ulang isinya di sini:
        let cap = OperatorCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }
}