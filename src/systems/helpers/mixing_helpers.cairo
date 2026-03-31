use crate::config::ingredients::get_ingredient_config;
use crate::types::drug_types::MAX_EFFECTS_PER_DRUG;

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

pub fn get_effect_at_index(effects: u32, index: u8) -> u8 {
    let shift = pow256(index);
    ((effects / shift) & 0xFF).try_into().unwrap()
}

pub fn set_effect_at_index(effects: u32, index: u8, effect_id: u8) -> u32 {
    let shift = pow256(index);
    let mask: u32 = 0xFF * shift;
    let cleared = effects & (0xFFFFFFFF - mask);
    let val: u32 = effect_id.into();
    cleared + val * shift
}

pub fn count_effects(effects: u32) -> u8 {
    let mut count: u8 = 0;
    let mut i: u8 = 0;
    loop {
        if i >= MAX_EFFECTS_PER_DRUG {
            break;
        }
        if get_effect_at_index(effects, i) != 0 {
            count += 1;
        }
        i += 1;
    };
    count
}

fn has_effect(effects: u32, effect_id: u8) -> bool {
    let mut found = false;
    let mut i: u8 = 0;
    loop {
        if i >= MAX_EFFECTS_PER_DRUG {
            break;
        }
        if get_effect_at_index(effects, i) == effect_id {
            found = true;
            break;
        }
        i += 1;
    };
    found
}

pub fn apply_ingredient(effects: u32, ingredient_id: u8) -> u32 {
    let config = get_ingredient_config(ingredient_id);
    let effect_id = config.effect_id;

    // No duplicate effects
    if has_effect(effects, effect_id) {
        return effects;
    }

    // Find empty slot
    let mut i: u8 = 0;
    let mut result = effects;
    loop {
        if i >= MAX_EFFECTS_PER_DRUG {
            // No empty slot found — max 4 effects reached
            break;
        }
        if get_effect_at_index(effects, i) == 0 {
            result = set_effect_at_index(effects, i, effect_id);
            break;
        }
        i += 1;
    };
    result
}
