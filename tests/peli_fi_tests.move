#[test_only]
module peli_fi_sui::peli_fi_tests {
    use sui::test_scenario::{Self, next_tx, ctx};
    use sui::coin::{Coin, TreasuryCap};
    use peli_fi_sui::peli_fi::{Self, PersonalVault, MarketVault, OperatorCap};
    use peli_fi_sui::mock_token::{Self, MOCK_TOKEN};

    #[test]
    fun test_autobot_flow() {
        let admin = @0xAD;
        let user = @0x42;
        let bot = @0xBB;

        let mut scenario = test_scenario::begin(admin);

        // --- 1. SETUP: Deploy Kedua Module ---
        {
            mock_token::init_for_testing(ctx(&mut scenario));
            peli_fi::init_for_testing(ctx(&mut scenario));
        };

        // --- 2. MINT TOKEN & TRANSFER CAP ---
        // Kita butuh next_tx supaya TreasuryCap & OperatorCap "muncul" di tangan admin
        next_tx(&mut scenario, admin); 
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<MOCK_TOKEN>>(&scenario);
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);

            // Mint 1000 koin buat user
            mock_token::mint(&mut treasury_cap, 1000, user, ctx(&mut scenario));
            
            // Kirim kunci Operator ke Bot (Sesuai logic Factory kamu)
            transfer::public_transfer(operator_cap, bot);
            
            test_scenario::return_to_sender(&scenario, treasury_cap);
        };

        // --- 3. CREATE MARKET & VAULT ---
        next_tx(&mut scenario, admin);
        {
            peli_fi::create_market<MOCK_TOKEN>(b"High Yield Market", ctx(&mut scenario));
        };

        next_tx(&mut scenario, user);
        {
            peli_fi::create_vault<MOCK_TOKEN>(ctx(&mut scenario));
        };

        // --- 4. DEPOSIT KE VAULT ---
        next_tx(&mut scenario, user);
        {
            let mut vault = test_scenario::take_shared<PersonalVault<MOCK_TOKEN>>(&scenario);
            let coin = test_scenario::take_from_sender<Coin<MOCK_TOKEN>>(&scenario);
            
            peli_fi::deposit_to_vault(&mut vault, coin);
            
            test_scenario::return_shared(vault);
        };

        // --- 5. EXECUTION BY BOT ---
        next_tx(&mut scenario, bot);
        {
            let cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let mut vault = test_scenario::take_shared<PersonalVault<MOCK_TOKEN>>(&scenario);
            let mut market = test_scenario::take_shared<MarketVault<MOCK_TOKEN>>(&scenario);

            // Bot eksekusi strategi: pindahin 500
            peli_fi::execute_strategy(&cap, &mut vault, &mut market, 500, ctx(&mut scenario));

            test_scenario::return_to_sender(&scenario, cap);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(market);
        };

        test_scenario::end(scenario);
    }
}