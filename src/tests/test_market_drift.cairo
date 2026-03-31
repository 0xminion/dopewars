use rollyourown::systems::helpers::market_drift::{
    apply_price_drift, replenish_supply, apply_market_event,
    EVENT_BUST, EVENT_BOOM, EVENT_SHORTAGE, EVENT_SURPLUS,
};
use rollyourown::models::cartel_market::{get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply};

#[test]
fn test_price_drift_changes_ticks() {
    // Start all drugs at tick 32
    let mut prices: u128 = 0;
    let mut i: u8 = 0;
    while i < 8 {
        prices = set_drug_price_tick(prices, i, 32);
        i += 1;
    };

    let drifted = apply_price_drift(prices, 0x123456789ABCDEF);
    // At least one tick should have changed
    let mut any_changed = false;
    i = 0;
    while i < 8 {
        if get_drug_price_tick(drifted, i) != 32 {
            any_changed = true;
        }
        i += 1;
    };
    assert(any_changed, 'drift should change some ticks');
}

#[test]
fn test_replenish_supply() {
    let mut supply: u128 = 0;
    // Weed (drug 1, idx 0) initial=200, set to 100
    supply = set_drug_supply(supply, 0, 100);
    let replenished = replenish_supply(supply);
    let new_val = get_drug_supply(replenished, 0);
    // deficit=100, replenish=10, new=110
    assert(new_val == 110, 'replenished to 110');
}

#[test]
fn test_event_bust() {
    let mut supply: u128 = 0;
    supply = set_drug_supply(supply, 2, 100);
    let (_, new_supply) = apply_market_event(0, supply, EVENT_BUST, 2);
    assert(get_drug_supply(new_supply, 2) == 50, 'bust halves supply');
}

#[test]
fn test_event_boom() {
    let mut prices: u128 = 0;
    prices = set_drug_price_tick(prices, 1, 20);
    let (new_prices, _) = apply_market_event(prices, 0, EVENT_BOOM, 1);
    // 20 + 20*30/100 = 26
    assert(get_drug_price_tick(new_prices, 1) == 26, 'boom +30%');
}
