module peli_fi_sui::mock_token {
    use sui::coin::{Self, TreasuryCap};

    public struct MOCK_TOKEN has drop {}

    fun init(witness: MOCK_TOKEN, ctx: &mut TxContext) {
        // Pindahkan logika ke fungsi internal agar bisa dipakai ulang
        create_currency_internal(witness, ctx);
    }

    fun create_currency_internal(witness: MOCK_TOKEN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            6, 
            b"USDC", 
            b"Mock USDC", 
            b"Peli-Fi Test Token", 
            option::none(), 
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Gunakan test_utils untuk membuat witness khusus testing
        create_currency_internal(
            sui::test_utils::create_one_time_witness<MOCK_TOKEN>(), 
            ctx
        );
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<MOCK_TOKEN>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }
}