use crate::systems::helpers::action_executor::{
    validate_action, calculate_total_ap_cost, validate_action_batch,
};
use crate::types::action_types::{Action, ActionType};

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
fn test_validate_action_buy_enough_ap() {
    let action = make_action(ActionType::Buy, 1, 1, 5);
    // Buy costs 1 AP
    assert(validate_action(action, 1, 1), 'should be valid with 1 AP');
    assert(!validate_action(action, 1, 0), 'should fail with 0 AP');
}

#[test]
fn test_validate_action_none_always_invalid() {
    let action = make_action(ActionType::None, 0, 0, 0);
    assert(!validate_action(action, 1, 10), 'None action should be invalid');
}

#[test]
fn test_validate_travel_adjacent() {
    // Location 1 is adjacent to 2 and 3 (adjacent_mask = 0b000110)
    let action = make_action(ActionType::Travel, 2, 0, 0);
    // Adjacent travel costs 1 AP
    assert(validate_action(action, 1, 1), 'adjacent travel needs 1 AP');
    assert(!validate_action(action, 1, 0), 'needs at least 1 AP');
}

#[test]
fn test_validate_travel_distant() {
    // Location 1 -> 5: not adjacent (mask=0b000110, bit 5 not set)
    let action = make_action(ActionType::Travel, 5, 0, 0);
    // Distant travel costs 2 AP
    assert(validate_action(action, 1, 2), 'distant travel needs 2 AP');
    assert(!validate_action(action, 1, 1), 'needs at least 2 AP');
}

#[test]
fn test_calculate_total_ap_cost_simple() {
    let actions = array![
        make_action(ActionType::Buy, 0, 1, 10),
        make_action(ActionType::Sell, 0, 2, 5),
    ];
    // Buy=1, Sell=1 => total=2
    let cost = calculate_total_ap_cost(actions.span(), 1, false);
    assert(cost == 2, 'total should be 2');
}

#[test]
fn test_validate_action_batch_fits() {
    let actions = array![
        make_action(ActionType::Buy, 0, 1, 10),
        make_action(ActionType::Sell, 0, 2, 5),
    ];
    assert(validate_action_batch(actions.span(), 1, 4), 'batch should fit in 4 AP');
    assert(!validate_action_batch(actions.span(), 1, 1), 'batch should not fit in 1 AP');
}
