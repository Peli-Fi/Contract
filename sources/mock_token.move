module peli_fi_sui::mock_token {
    use sui::coin::{Self, TreasuryCap};
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};

    public struct MOCK_TOKEN has drop {}

    public struct Faucet has key {
        id: UID,
        treasury_cap: TreasuryCap<MOCK_TOKEN>,
        last_mint: Table<address, u64>
    }

    const ECooldownNotFinished: u64 = 0;
    const COOLDOWN_MS: u64 = 3600000; // 1 Jam
    const MINT_AMOUNT: u64 = 1000000000; // 1000 USDC (6 desimal)

    fun init(witness: MOCK_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            6, 
            b"USDC", 
            b"Mock USDC", 
            b"Peli-Fi Test Token", 
            option::none(), 
            ctx
        );

        transfer::public_freeze_object(metadata);

        let faucet = Faucet {
            id: object::new(ctx),
            treasury_cap,
            last_mint: table::new(ctx),
        };
        transfer::share_object(faucet);
    }

    public entry fun request_faucet(
        faucet: &mut Faucet,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        if (table::contains(&faucet.last_mint, sender)) {
            let last_claim = *table::borrow(&faucet.last_mint, sender);
            assert!(current_time >= last_claim + COOLDOWN_MS, ECooldownNotFinished);
            
            let last_claim_ref = table::borrow_mut(&mut faucet.last_mint, sender);
            *last_claim_ref = current_time;
        } else {
            table::add(&mut faucet.last_mint, sender, current_time);
        };

        let coins = coin::mint(&mut faucet.treasury_cap, MINT_AMOUNT, ctx);
        transfer::public_transfer(coins, sender);
    }

    // --- FITUR BARU: GETTER UNTUK FRONTEND ---
    public fun get_last_claim(faucet: &Faucet, user: address): u64 {
        if (table::contains(&faucet.last_mint, user)) {
            *table::borrow(&faucet.last_mint, user)
        } else {
            0
        }
    }
}