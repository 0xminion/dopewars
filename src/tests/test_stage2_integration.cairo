use rollyourown::systems::helpers::reputation_helpers::{
    award_xp, can_access_drug, get_max_slots, get_max_operations, BRANCH_TRADER, BRANCH_OPERATOR,
};
use rollyourown::systems::helpers::slot_helpers::{
    calculate_dealer_sales, calculate_bust_risk, apply_commission,
};
use rollyourown::systems::helpers::operation_helpers::{process_operation_tick, start_laundering};
use rollyourown::systems::helpers::market_drift::{
    apply_price_drift, replenish_supply, apply_market_event, EVENT_BUST, EVENT_BOOM,
};
use rollyourown::models::reputation::Reputation;
use rollyourown::models::cartel_market::{
    get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply,
};
use starknet::contract_address_const;

#[test]
fn test_stage2_full_loop() {
    // ---------------------------------------------------------------
    // 1. Reputation: award_xp → level up → verify unlocks
    // ---------------------------------------------------------------
    let mut rep = Reputation {
        game_id: 1,
        player_id: contract_address_const::<0x1>(),
        trader_xp: 0,
        enforcer_xp: 0,
        operator_xp: 0,
        trader_lvl: 0,
        enforcer_lvl: 0,
        operator_lvl: 0,
    };

    // Award trader XP to level 1 (100 xp threshold)
    award_xp(ref rep, BRANCH_TRADER, 100);
    assert(rep.trader_lvl == 1, 'trader lvl should be 1');

    // Level 0 can access drug 4, not drug 5
    assert(can_access_drug(0, 4), 'lvl 0 can access drug 4');
    assert(!can_access_drug(0, 5), 'lvl 0 cannot access drug 5');
    // Level 1 can access drug 5
    assert(can_access_drug(1, 5), 'lvl 1 can access drug 5');

    // Award operator XP to level 2 (300 xp threshold) for slot/op unlocks
    award_xp(ref rep, BRANCH_OPERATOR, 300);
    assert(rep.operator_lvl == 2, 'operator lvl should be 2');

    // Level 0 => 2 slots, level 2 => 4 slots
    assert(get_max_slots(0) == 2, 'lvl 0 has 2 slots');
    assert(get_max_slots(2) == 4, 'lvl 2 has 4 slots');

    // Level 0 => 1 operation, level 2 => 2 operations
    let ops_lvl0 = get_max_operations(0);
    let ops_lvl2 = get_max_operations(2);
    assert(ops_lvl2 >= ops_lvl0, 'lvl 2 ops >= lvl 0');

    // ---------------------------------------------------------------
    // 2. Dealer sales: calculate_dealer_sales with different strategies
    // ---------------------------------------------------------------

    // Cautious strategy (0): 10% + skill_bonus
    // drug_id=1, qty=100, salesmanship=50, strategy=0, tick=32
    // sell_pct = 10 + (50/20=2) = 12%, qty_sold = 12
    let (qty_cautious, rev_cautious) = calculate_dealer_sales(1, 100, 50, 0, 32);
    assert(qty_cautious == 12, 'cautious: sold 12');
    assert(rev_cautious > 0, 'cautious: positive revenue');

    // Aggressive strategy (1): 30% + skill_bonus
    // sell_pct = 30 + 2 = 32%, qty_sold = 32
    let (qty_aggressive, rev_aggressive) = calculate_dealer_sales(1, 100, 50, 1, 32);
    assert(qty_aggressive == 32, 'aggressive: sold 32');
    assert(rev_aggressive > rev_cautious, 'aggressive > cautious revenue');

    // Balanced strategy (2): 20% + skill_bonus
    let (qty_balanced, _) = calculate_dealer_sales(1, 100, 50, 2, 32);
    assert(qty_balanced == 22, 'balanced: sold 22');

    // Minimum sell: even 10% of 1 = 0 should become 1
    let (qty_min, _) = calculate_dealer_sales(1, 1, 10, 0, 32);
    assert(qty_min == 1, 'min 1 sold');

    // ---------------------------------------------------------------
    // 3. Bust risk: low heat + high stealth = no bust; high heat + aggressive = bust
    // ---------------------------------------------------------------

    // Low heat (5), high stealth (80), balanced (2), roll=50
    // risk = 5 * (100-80) / 100 = 1, roll 50 >= 1 => not busted
    let busted_low = calculate_bust_risk(5, 80, 2, 50);
    assert(!busted_low, 'low heat high stealth: no bust');

    // High heat (50), low stealth (20), aggressive (1), roll=10
    // base = 50 * (100-20) / 100 = 40, doubled = 80, roll 10 < 80 => busted
    let busted_high = calculate_bust_risk(50, 20, 1, 10);
    assert(busted_high, 'high heat aggressive: busted');

    // ---------------------------------------------------------------
    // 4. Commission: apply_commission → verify split
    // ---------------------------------------------------------------
    let (owner_cut, dealer_cut) = apply_commission(1000, 20);
    assert(dealer_cut == 200, 'dealer cut is 20%');
    assert(owner_cut == 800, 'owner cut is 80%');
    assert(owner_cut + dealer_cut == 1000, 'cuts sum to total');

    // ---------------------------------------------------------------
    // 5. Laundering: start_laundering → process_operation_tick × 2
    // ---------------------------------------------------------------

    // Start laundering 300 dirty cash via Laundromat (op_type=1, capacity=500, turns=2)
    let (queued, turns) = start_laundering(1, 300, 0);
    assert(queued == 300, 'queued 300');
    assert(turns == 2, 'laundromat: 2 turns');

    // Tick 1: still processing (1 turn left after decrement, but turns_left goes from 2->1)
    let (clean1, remaining1, turns1) = process_operation_tick(1, queued, turns);
    assert(clean1 == 0, 'tick1: no clean yet');
    assert(remaining1 == 300, 'tick1: 300 remaining');
    assert(turns1 == 1, 'tick1: 1 turn left');

    // Tick 2: completes — all 300 dirty becomes clean
    let (clean2, remaining2, turns2) = process_operation_tick(1, remaining1, turns1);
    assert(clean2 == 300, 'tick2: 300 clean produced');
    assert(remaining2 == 0, 'tick2: nothing remaining');
    assert(turns2 == 0, 'tick2: no turns left');

    // ---------------------------------------------------------------
    // 6. Market drift: apply_price_drift → verify at least some ticks changed
    // ---------------------------------------------------------------
    let mut prices: u128 = 0;
    let mut i: u8 = 0;
    while i < 8 {
        prices = set_drug_price_tick(prices, i, 32);
        i += 1;
    };

    let drifted = apply_price_drift(prices, 0xDEADBEEFCAFEBABE);
    let mut any_changed = false;
    i = 0;
    while i < 8 {
        if get_drug_price_tick(drifted, i) != 32 {
            any_changed = true;
        }
        i += 1;
    };
    assert(any_changed, 'drift: some ticks changed');

    // ---------------------------------------------------------------
    // 7. Market events: EVENT_BUST halves supply, EVENT_BOOM increases price
    // ---------------------------------------------------------------

    // EVENT_BUST: supply of drug index 3 should be halved
    let mut supply: u128 = 0;
    supply = set_drug_supply(supply, 3, 200);
    let (_, busted_supply) = apply_market_event(0, supply, EVENT_BUST, 3);
    assert(get_drug_supply(busted_supply, 3) == 100, 'bust: supply halved to 100');

    // EVENT_BOOM: price tick of drug index 2 should increase by ~30%
    let mut boom_prices: u128 = 0;
    boom_prices = set_drug_price_tick(boom_prices, 2, 20);
    let (boomed_prices, _) = apply_market_event(boom_prices, 0, EVENT_BOOM, 2);
    // 20 + 20*30/100 = 26
    assert(get_drug_price_tick(boomed_prices, 2) == 26, 'boom: price tick increased');
}
