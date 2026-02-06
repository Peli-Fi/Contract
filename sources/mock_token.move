module peli_fi_sui::mock_token {
    use sui::coin::{Self, TreasuryCap};
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};

    public struct MOCK_TOKEN has drop {}

    // Objek Faucet yang dibagikan secara publik (Shared Object)
    public struct Faucet has key {
        id: UID,
        treasury_cap: TreasuryCap<MOCK_TOKEN>,
        // Mencatat: Alamat User -> Timestamp Terakhir Claim (dalam ms)
        last_mint: Table<address, u64>
    }

    // Errors
    const ECooldownNotFinished: u64 = 0;

    // 1 Jam = 3.600.000 Milliseconds
    const COOLDOWN_MS: u64 = 3600000;
    // Jumlah koin yang didapat sekali claim (1000 USDC dengan 6 desimal)
    const MINT_AMOUNT: u64 = 1000000000; 

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

        // Bungkus TreasuryCap ke dalam Faucet dan jadikan Shared Object
        let faucet = Faucet {
            id: object::new(ctx),
            treasury_cap,
            last_mint: table::new(ctx),
        };
        transfer::share_object(faucet);
    }

    // Fungsi bagi publik untuk meminta koin (Faucet)
    public entry fun request_faucet(
        faucet: &mut Faucet,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        if (table::contains(&faucet.last_mint, sender)) {
            let last_claim = *table::borrow(&faucet.last_mint, sender);
            // Validasi: Apakah sudah lewat 1 jam sejak claim terakhir?
            assert!(current_time >= last_claim + COOLDOWN_MS, ECooldownNotFinished);
            
            // Update waktu claim terbaru
            let last_claim_ref = table::borrow_mut(&mut faucet.last_mint, sender);
            *last_claim_ref = current_time;
        } else {
            // Jika user baru pertama kali claim
            table::add(&mut faucet.last_mint, sender, current_time);
        };

        // Mint koin ke dompet user
        let coins = coin::mint(&mut faucet.treasury_cap, MINT_AMOUNT, ctx);
        transfer::public_transfer(coins, sender);
    }
}