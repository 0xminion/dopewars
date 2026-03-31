use crate::config::drugs_v2::get_drug_config;
use crate::types::effect_types::effect_multiplier_bps;

pub fn calculate_buy_price(drug_id: u8, tick: u16) -> u32 {
    let config = get_drug_config(drug_id);
    let base: u32 = config.base_price.into();
    let step: u32 = config.price_step.into();
    let t: u32 = tick.into();
    base + step * t
}

pub fn calculate_sell_price(drug_id: u8, tick: u16, effects: u32) -> u32 {
    let buy = calculate_buy_price(drug_id, tick);
    let mult: u32 = calculate_effect_multiplier(effects).into();
    buy * (100 + mult) / 100
}

pub fn calculate_effect_multiplier(effects: u32) -> u16 {
    let mut total: u16 = 0;
    let mut i: u8 = 0;
    loop {
        if i >= 4 {
            break;
        }
        let shift: u32 = pow256(i);
        let slot_effect: u8 = ((effects / shift) & 0xFF).try_into().unwrap();
        total += effect_multiplier_bps(slot_effect);
        i += 1;
    };
    total
}

fn pow256(n: u8) -> u32 {
    let mut result: u32 = 1;
    let mut i: u8 = 0;
    loop {
        if i >= n {
            break;
        }
        result = result * 256;
        i += 1;
    };
    result
}

pub fn drain_supply(current: u16, buy_qty: u16) -> u16 {
    if buy_qty >= current {
        0
    } else {
        current - buy_qty
    }
}

pub fn replenish_supply(current: u16, sell_qty: u16, max: u16) -> u16 {
    let new_val = current + sell_qty;
    if new_val > max {
        max
    } else {
        new_val
    }
}

pub fn is_visible_to_player(visible_to: felt252, player_idx: u8) -> bool {
    let as_u256: u256 = visible_to.into();
    let bit: u256 = pow2_u256(player_idx);
    (as_u256 & bit) != 0
}

pub fn set_visible_to_player(visible_to: felt252, player_idx: u8) -> felt252 {
    let as_u256: u256 = visible_to.into();
    let bit: u256 = pow2_u256(player_idx);
    let result: u256 = as_u256 | bit;
    result.try_into().unwrap()
}

fn pow2_u256(n: u8) -> u256 {
    let mut result: u256 = 1;
    let mut i: u8 = 0;
    loop {
        if i >= n {
            break;
        }
        result = result * 2;
        i += 1;
    };
    result
}
