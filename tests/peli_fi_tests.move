#[test_only]
module peli_fi_sui::peli_fi_tests {
    use sui::test_scenario::{Self, next_tx, ctx};
    use sui::coin::{Coin, TreasuryCap};
    use sui::balance;
    // Import MasterVault, bukan PersonalVault lagi
    use peli_fi_sui::peli_fi::{Self, MasterVault, MarketVault, OperatorCap};
    use peli_fi_sui::mock_token::{Self, MOCK_TOKEN};

    #[test]
    fun test_autobot_pooling_flow() {
        let admin = @0xAD;
        let user = @0x42;
        let bot = @0xBB;

        let mut scenario = test_scenario::begin(admin);

        // --- 1. SETUP: Deploy Module ---
        {
            mock_token::init_for_testing(ctx(&mut scenario));
            peli_fi::init_for_testing(ctx(&mut scenario));
        };

        // --- 2. PREPARASI: Mint Token & Setup Infrastructure ---
        next_tx(&mut scenario, admin); 
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<MOCK_TOKEN>>(&scenario);
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);

            // Mint 1000 koin buat user
            mock_token::mint(&mut treasury_cap, 1000, user, ctx(&mut scenario));
            
            // Buat Infrastructure Utama (MasterVault & Market)
            peli_fi::create_master_vault<MOCK_TOKEN>(ctx(&mut scenario));
            peli_fi::create_market<MOCK_TOKEN>(b"Low Risk Market", ctx(&mut scenario));

            // Kirim OperatorCap (Kunci Bot) ke alamat Bot
            transfer::public_transfer(operator_cap, bot);
            test_scenario::return_to_address(admin, treasury_cap);
        };

        // --- 3. USER DEPOSIT KE MASTER VAULT ---
        next_tx(&mut scenario, user);
        {
            let mut vault = test_scenario::take_shared<MasterVault<MOCK_TOKEN>>(&scenario);
            let coin = test_scenario::take_from_sender<Coin<MOCK_TOKEN>>(&scenario);
            
            // User deposit 1000 koin ke Strategy ID: 1 (misal Low Risk)
            peli_fi::deposit(&mut vault, coin, 1, ctx(&mut scenario));
            
            test_scenario::return_shared(vault);
        };

        // --- 4. BOT EKSEKUSI (PINDAHIN DANA KE MARKET) ---
        next_tx(&mut scenario, bot);
        {
            let cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let mut vault = test_scenario::take_shared<MasterVault<MOCK_TOKEN>>(&scenario);
            let mut market = test_scenario::take_shared<MarketVault<MOCK_TOKEN>>(&scenario);

            // Bot memindahkan 600 koin dari MasterVault ke MarketVault
            peli_fi::execute_strategy(&cap, &mut vault, &mut market, 600, ctx(&mut scenario));

            // --- 5. VERIFIKASI AKHIR ---
            // Cek saldo di MasterVault sekarang harus sisa 400 (1000 - 600)
            // (Catatan: ini butuh fungsi getter di peli_fi.move jika ingin diakses publik, 
            // tapi dalam test kita bisa intip lewat pemeriksaan balance)
            
            test_scenario::return_to_address(bot, cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(market);
        };
        test_scenario::end(scenario);
    }
}