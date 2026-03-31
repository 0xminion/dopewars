use crate::systems::helpers::market_helpers::{
    calculate_buy_price, calculate_sell_price, drain_supply,
    is_visible_to_player, set_visible_to_player,
};

#[test]
fn test_buy_price_basic() {
    // drug_id=1: base=15, step=2
    let price = calculate_buy_price(1, 0);
    assert(price == 15, 'wrong price at tick 0');
    let price2 = calculate_buy_price(1, 5);
    assert(price2 == 25, 'wrong price at tick 5');
}

#[test]
fn test_sell_price_with_effects() {
    // drug_id=1, tick=0, no effects => same as buy price
    let no_effects_price = calculate_sell_price(1, 0, 0);
    assert(no_effects_price == 15, 'wrong sell no effects');
    // With effect_id=3 (Potent, 30 bps) in slot 0
    let with_effect = calculate_sell_price(1, 0, 3);
    // 15 * (100 + 30) / 100 = 15 * 130 / 100 = 19
    assert(with_effect == 19, 'wrong sell with effects');
}

#[test]
fn test_drain_supply_basic() {
    let result = drain_supply(100, 30);
    assert(result == 70, 'wrong drain');
}

#[test]
fn test_drain_supply_floors_at_zero() {
    let result = drain_supply(10, 50);
    assert(result == 0, 'should floor at zero');
}

#[test]
fn test_visibility_bitmask() {
    let visible: felt252 = 0;
    assert(!is_visible_to_player(visible, 0), 'player 0 should not be visible');
    let updated = set_visible_to_player(visible, 0);
    assert(is_visible_to_player(updated, 0), 'player 0 should be visible');
    assert(!is_visible_to_player(updated, 1), 'player 1 should not be visible');
    let updated2 = set_visible_to_player(updated, 3);
    assert(is_visible_to_player(updated2, 3), 'player 3 should be visible');
    assert(!is_visible_to_player(updated2, 2), 'player 2 should not be visible');
}
