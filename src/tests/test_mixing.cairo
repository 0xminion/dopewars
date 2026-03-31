use crate::systems::helpers::mixing_helpers::{
    apply_ingredient, count_effects, get_effect_at_index,
};

#[test]
fn test_apply_first_ingredient() {
    // ingredient_id=1 => effect_id=1 (Cut)
    let effects = apply_ingredient(0, 1);
    assert(get_effect_at_index(effects, 0) == 1, 'first effect should be 1');
    assert(count_effects(effects) == 1, 'count should be 1');
}

#[test]
fn test_apply_multiple_ingredients() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 1); // effect 1
    effects = apply_ingredient(effects, 2); // effect 2
    effects = apply_ingredient(effects, 3); // effect 3
    assert(count_effects(effects) == 3, 'count should be 3');
    assert(get_effect_at_index(effects, 0) == 1, 'slot 0 should be effect 1');
    assert(get_effect_at_index(effects, 1) == 2, 'slot 1 should be effect 2');
    assert(get_effect_at_index(effects, 2) == 3, 'slot 2 should be effect 3');
}

#[test]
fn test_cannot_exceed_max_effects() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 1); // effect 1
    effects = apply_ingredient(effects, 2); // effect 2
    effects = apply_ingredient(effects, 3); // effect 3
    effects = apply_ingredient(effects, 4); // effect 4
    assert(count_effects(effects) == 4, 'should have 4 effects');
    // Try to add a 5th — ingredient_id=5 has effect_id=5
    let effects_after = apply_ingredient(effects, 5);
    // Should remain at 4 effects (no empty slot)
    assert(count_effects(effects_after) == 4, 'should still have 4 effects');
}

#[test]
fn test_no_duplicate_effects() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 1); // effect 1
    // Try to apply ingredient_id=1 again (same effect_id=1)
    let effects_after = apply_ingredient(effects, 1);
    assert(count_effects(effects_after) == 1, 'no duplicates allowed');
}
