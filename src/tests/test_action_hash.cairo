use crate::utils::action_hash::{hash_actions, verify_action_hash};
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
fn test_hash_actions_deterministic() {
    let actions = array![
        make_action(ActionType::Travel, 2, 0, 0),
        make_action(ActionType::Buy, 2, 1, 10),
    ];
    let salt: felt252 = 0xABCD;
    let h1 = hash_actions(actions.span(), salt);
    let h2 = hash_actions(actions.span(), salt);
    assert(h1 == h2, 'hash not deterministic');
    assert(h1 != 0, 'hash is zero');
}

#[test]
fn test_hash_actions_different_salt() {
    let actions = array![make_action(ActionType::Buy, 1, 2, 5)];
    let h1 = hash_actions(actions.span(), 111);
    let h2 = hash_actions(actions.span(), 222);
    assert(h1 != h2, 'same hash for diff salt');
}

#[test]
fn test_verify_action_hash() {
    let actions = array![
        make_action(ActionType::Sell, 3, 1, 20),
    ];
    let salt: felt252 = 0x1234;
    let h = hash_actions(actions.span(), salt);
    assert(verify_action_hash(actions.span(), salt, h), 'verify failed with correct salt');
    assert(!verify_action_hash(actions.span(), 0x9999, h), 'verify passed with wrong salt');
}
