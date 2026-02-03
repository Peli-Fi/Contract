module peli_fi_sui::mock_token {
    use sui::coin::{Self, TreasuryCap};

    /// Nama struct harus sama dengan nama module (Uppercase) 
    /// Ini disebut One-Time Witness (OTW)
    public struct MOCK_TOKEN has drop {}
    

    /// Fungsi init otomatis jalan sekali pas kontrak di-deploy
    fun init(witness: MOCK_TOKEN, ctx: &mut TxContext) {
        // create_currency bakal bikin token baru
        // Parameter: OTW, decimals, symbol, name, description, icon_url, ctx
        let (treasury, metadata) = coin::create_currency(
            witness, 
            6,                  // Decimals (sama kayak USDC)
            b"MOCK",            // Symbol
            b"Mock Token",      // Name
            b"Peli-Fi Test Token", // Description
            option::none(),     // Icon URL
            ctx
        );

        // Metadata biasanya dibikin publik biar orang bisa liat logo/nama
        transfer::public_freeze_object(metadata);

        // TreasuryCap adalah "Kunci Cetak". 
        // Siapa yang pegang ini, dia yang bisa mint token.
        // Untuk hackathon, kita kirim ke pengirim transaksi (kamu).
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Fungsi Mint (Sama kayak fungsi mint di MockToken.sol kamu)
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<MOCK_TOKEN>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    #[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(MOCK_TOKEN {}, ctx)
}
}

