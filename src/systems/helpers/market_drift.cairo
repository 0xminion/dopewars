use crate::models::cartel_market::{get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply};
use crate::config::drugs_v2::get_drug_config;
use crate::types::drug_types::DRUG_COUNT;

pub const MAX_TICK: u16 = 63;
pub const MIN_TICK: u16 = 0;

// Apply random drift to all drug prices at a location
// drift_seed is a random value used to derive per-drug drift
pub fn apply_price_drift(drug_prices: u128, drift_seed: felt252) -> u128 {
    let mut prices = drug_prices;
    let seed_u256: u256 = drift_seed.into();
    let mut i: u8 = 0;
    while i < DRUG_COUNT {
        let current_tick = get_drug_price_tick(prices, i);
        // Extract 4 bits per drug from seed for drift direction and magnitude
        let shift: u256 = 1;
        let mut s: u256 = shift;
        let mut j: u8 = 0;
        while j < i * 4 {
            s = s * 2;
            j += 1;
        };
        let bits: u8 = ((seed_u256 / s) & 0xF).try_into().unwrap();
        // bits 0-5: drift down 1-3, bits 6-9: no change, bits 10-15: drift up 1-3
        let new_tick = if bits < 2 {
            if current_tick >= 3 { current_tick - 3 } else { MIN_TICK }
        } else if bits < 4 {
            if current_tick >= 2 { current_tick - 2 } else { MIN_TICK }
        } else if bits < 6 {
            if current_tick >= 1 { current_tick - 1 } else { MIN_TICK }
        } else if bits < 10 {
            current_tick // no change
        } else if bits < 12 {
            if current_tick + 1 <= MAX_TICK { current_tick + 1 } else { MAX_TICK }
        } else if bits < 14 {
            if current_tick + 2 <= MAX_TICK { current_tick + 2 } else { MAX_TICK }
        } else {
            if current_tick + 3 <= MAX_TICK { current_tick + 3 } else { MAX_TICK }
        };
        prices = set_drug_price_tick(prices, i, new_tick);
        i += 1;
    };
    prices
}

// Replenish supply toward initial levels
pub fn replenish_supply(drug_supply: u128) -> u128 {
    let mut supply = drug_supply;
    let mut i: u8 = 0;
    while i < DRUG_COUNT {
        let current = get_drug_supply(supply, i);
        let config = get_drug_config(i + 1); // drug_id is 1-indexed
        let initial = config.initial_supply;
        // Replenish 10% of deficit per tick
        if current < initial {
            let deficit = initial - current;
            let replenish = deficit / 10;
            let new_supply = if replenish > 0 { current + replenish } else { current + 1 };
            let capped = if new_supply > initial { initial } else { new_supply };
            supply = set_drug_supply(supply, i, capped);
        }
        i += 1;
    };
    supply
}

// Market events
pub const EVENT_NONE: u8 = 0;
pub const EVENT_BUST: u8 = 1;       // -50% supply of random drug
pub const EVENT_BOOM: u8 = 2;       // +30% price tick of random drug
pub const EVENT_SHORTAGE: u8 = 3;   // supply halved for all drugs
pub const EVENT_SURPLUS: u8 = 4;    // supply doubled for all drugs

pub fn apply_market_event(
    drug_prices: u128,
    drug_supply: u128,
    event: u8,
    target_drug_idx: u8,
) -> (u128, u128) {
    let mut prices = drug_prices;
    let mut supply = drug_supply;

    if event == EVENT_BUST {
        let current = get_drug_supply(supply, target_drug_idx);
        supply = set_drug_supply(supply, target_drug_idx, current / 2);
    } else if event == EVENT_BOOM {
        let current = get_drug_price_tick(prices, target_drug_idx);
        let boosted = current + current * 30 / 100;
        let capped = if boosted > MAX_TICK { MAX_TICK } else { boosted };
        prices = set_drug_price_tick(prices, target_drug_idx, capped);
    } else if event == EVENT_SHORTAGE {
        let mut i: u8 = 0;
        while i < DRUG_COUNT {
            let current = get_drug_supply(supply, i);
            supply = set_drug_supply(supply, i, current / 2);
            i += 1;
        };
    } else if event == EVENT_SURPLUS {
        let mut i: u8 = 0;
        while i < DRUG_COUNT {
            let current = get_drug_supply(supply, i);
            let doubled = current * 2;
            let max_supply: u16 = 500;
            let capped = if doubled > max_supply { max_supply } else { doubled };
            supply = set_drug_supply(supply, i, capped);
            i += 1;
        };
    }

    (prices, supply)
}
