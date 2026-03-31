use core::poseidon::PoseidonTrait;
use core::hash::HashStateTrait;
use crate::types::action_types::{Action, ActionType};

fn action_type_to_u8(action_type: ActionType) -> u8 {
    match action_type {
        ActionType::None => 0,
        ActionType::Travel => 1,
        ActionType::Buy => 2,
        ActionType::Sell => 3,
        ActionType::Mix => 4,
        ActionType::Scout => 5,
        ActionType::Manage => 6,
        ActionType::Invest => 7,
        ActionType::Rest => 8,
    }
}

fn action_to_felt(action: Action) -> felt252 {
    let type_u8: u128 = action_type_to_u8(action.action_type).into();
    let target: u128 = action.target_location.into();
    let drug: u128 = action.drug_id.into();
    let qty: u128 = action.quantity.into();
    let ingr: u128 = action.ingredient_id.into();
    let slot: u128 = action.slot_index.into();

    let packed: u128 = type_u8
        + target * 0x100
        + drug * 0x10000
        + qty * 0x1000000
        + ingr * 0x10000000000
        + slot * 0x1000000000000;

    packed.try_into().unwrap()
}

pub fn hash_actions(actions: Span<Action>, salt: felt252) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update(salt);
    let mut i: usize = 0;
    loop {
        if i >= actions.len() {
            break;
        }
        let felt = action_to_felt(*actions.at(i));
        state = state.update(felt);
        i += 1;
    };
    state.finalize()
}

pub fn verify_action_hash(actions: Span<Action>, salt: felt252, expected: felt252) -> bool {
    hash_actions(actions, salt) == expected
}
