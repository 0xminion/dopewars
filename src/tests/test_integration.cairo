// Integration test: full game loop simulation through helper functions.
// Exercises action batching, market pricing, mixing, selling with effects,
// heat escalation, encounter triggering, location heat packing, and commit-reveal.

use crate::systems::helpers::action_executor::{validate_action_batch, calculate_total_ap_cost};
use crate::systems::helpers::market_helpers::{calculate_buy_price, calculate_sell_price};
use crate::systems::helpers::encounter_helpers::{
    should_trigger_encounter, resolve_encounter, calculate_crew_power, calculate_threat,
    EncounterOutcome,
};
use crate::systems::helpers::mixing_helpers::{apply_ingredient, count_effects};
use crate::utils::action_hash::{hash_actions, verify_action_hash};
use crate::types::action_types::{Action, ActionType};
use crate::config::heat_config::notoriety_to_tier;
use crate::models::heat::{get_location_heat, set_location_heat};

fn make_action(t: ActionType, loc: u8, drug: u8, qty: u16) -> Action {
    Action {
        action_type: t,
        target_location: loc,
        drug_id: drug,
        quantity: qty,
        ingredient_id: 0,
        slot_index: 0,
    }
}

#[test]
fn test_full_game_loop_simulation() {
    // -----------------------------------------------------------------------
    // 1. Action batch validation: Travel (adj=1AP) + Buy (1AP) + Scout (1AP) = 3AP
    // -----------------------------------------------------------------------
    // Location 1 is adjacent to 2, so Travel costs 1 AP.
    let batch = array![
        make_action(ActionType::Travel, 2, 0, 0), // 1 AP (adjacent)
        make_action(ActionType::Buy, 2, 1, 5),    // 1 AP
        make_action(ActionType::Scout, 2, 0, 0),  // 1 AP
    ];
    let total_ap = calculate_total_ap_cost(batch.span(), 1, false);
    assert(total_ap == 3, 'should cost 3 AP');

    // Batch fits in 3 AP, but not in 2 AP
    assert(validate_action_batch(batch.span(), 1, 3), 'batch fits in 3 AP');
    assert(!validate_action_batch(batch.span(), 1, 2), 'batch not fit in 2 AP');

    // -----------------------------------------------------------------------
    // 2. Buy price: drug_id=1 (Weed) at tick 32 => base=15 + 32*2 = 79
    // -----------------------------------------------------------------------
    let buy_price = calculate_buy_price(1, 32);
    assert(buy_price == 79, 'Weed at tick 32 = 79');

    let base_price = calculate_buy_price(1, 0);
    assert(base_price == 15, 'Weed base price = 15');

    // -----------------------------------------------------------------------
    // 3. Mixing: apply ingredient, verify effect count
    // -----------------------------------------------------------------------
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 1); // effect_id=1 (Cut)
    assert(count_effects(effects) == 1, '1 effect after 1st mix');

    effects = apply_ingredient(effects, 2); // effect_id=2
    assert(count_effects(effects) == 2, '2 effects after 2nd mix');

    let effects_dup = apply_ingredient(effects, 1); // duplicate
    assert(count_effects(effects_dup) == 2, 'duplicate ignored');

    // -----------------------------------------------------------------------
    // 4. Sell price with effects (effect_id=3 = Potent, +30 bps)
    //    drug_id=1, tick=0 => base=15; with effect 3 => 15*130/100 = 19
    // -----------------------------------------------------------------------
    let sell_no_fx = calculate_sell_price(1, 0, 0);
    assert(sell_no_fx == 15, 'sell no effects = 15');

    let sell_with_fx = calculate_sell_price(1, 0, 3);
    assert(sell_with_fx == 19, 'sell Potent effect = 19');

    // -----------------------------------------------------------------------
    // 5. Heat escalation thresholds via notoriety_to_tier
    // -----------------------------------------------------------------------
    assert(notoriety_to_tier(0) == 0, 'notoriety 0 => tier 0');
    assert(notoriety_to_tier(19) == 0, 'notoriety 19 => tier 0');
    assert(notoriety_to_tier(20) == 1, 'notoriety 20 => tier 1');
    assert(notoriety_to_tier(50) == 2, 'notoriety 50 => tier 2');
    assert(notoriety_to_tier(100) == 3, 'notoriety 100 => tier 3');

    // -----------------------------------------------------------------------
    // 6. Encounter triggering at different tiers
    // -----------------------------------------------------------------------
    assert(!should_trigger_encounter(0, 0, 0), 'tier0 roll0 no trigger');
    assert(!should_trigger_encounter(0, 0, 50), 'tier0 roll50 no trigger');
    assert(!should_trigger_encounter(1, 0, 99), 'tier1 high roll no trigger');
    assert(should_trigger_encounter(3, 6, 30), 'tier3 low roll triggers');

    let power = calculate_crew_power(3, 20); // 10 + 3*5 + 20 = 45
    assert(power == 45, 'crew power = 45');

    let win = resolve_encounter(50, 30);
    assert(win == EncounterOutcome::Win, 'p50 vs t30 should win');

    let lose = resolve_encounter(10, 50);
    assert(lose == EncounterOutcome::Lose, 'p10 vs t50 should lose');

    // -----------------------------------------------------------------------
    // 7. Location heat packing / unpacking
    // -----------------------------------------------------------------------
    let packed: u64 = 0;

    let p1 = set_location_heat(packed, 0, 42);
    assert(get_location_heat(p1, 0) == 42, 'loc0 heat = 42');

    let p2 = set_location_heat(p1, 3, 77);
    assert(get_location_heat(p2, 0) == 42, 'loc0 unchanged after set3');
    assert(get_location_heat(p2, 3) == 77, 'loc3 heat = 77');
    assert(get_location_heat(p2, 1) == 0, 'loc1 heat = 0');

    let p3 = set_location_heat(p2, 0, 5);
    assert(get_location_heat(p3, 0) == 5, 'loc0 overwritten to 5');
    assert(get_location_heat(p3, 3) == 77, 'loc3 intact after overwrite');

    // -----------------------------------------------------------------------
    // 8. Commit-reveal hash verification
    // -----------------------------------------------------------------------
    let commit_actions = array![
        make_action(ActionType::Travel, 2, 0, 0),
        make_action(ActionType::Buy, 2, 1, 10),
        make_action(ActionType::Scout, 2, 0, 0),
    ];
    let salt: felt252 = 0xDEADBEEF;

    let commitment = hash_actions(commit_actions.span(), salt);
    assert(commitment != 0, 'commitment != 0');

    assert(
        verify_action_hash(commit_actions.span(), salt, commitment),
        'correct salt verifies'
    );

    assert(
        !verify_action_hash(commit_actions.span(), 0x1111, commitment),
        'wrong salt fails'
    );

    let other_actions = array![make_action(ActionType::Sell, 1, 1, 5)];
    let other_hash = hash_actions(other_actions.span(), salt);
    assert(other_hash != commitment, 'diff actions diff hash');
}
