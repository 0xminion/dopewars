use crate::types::action_types::{Action, ActionType, action_ap_cost};
use crate::config::locations_v2::is_adjacent;

pub fn validate_action(action: Action, current_location: u8, ap_remaining: u8) -> bool {
    match action.action_type {
        ActionType::None => false,
        ActionType::Travel => {
            let dest = action.target_location;
            let distant = !is_adjacent(current_location, dest);
            let cost = action_ap_cost(ActionType::Travel, distant);
            ap_remaining >= cost
        },
        _ => {
            let cost = action_ap_cost(action.action_type, false);
            ap_remaining >= cost
        },
    }
}

pub fn calculate_total_ap_cost(
    actions: Span<Action>, current_location: u8, any_distant_travel: bool
) -> u8 {
    let mut total: u8 = 0;
    let mut loc = current_location;
    let mut i: usize = 0;
    loop {
        if i >= actions.len() {
            break;
        }
        let action = *actions.at(i);
        let cost = match action.action_type {
            ActionType::Travel => {
                let distant = if any_distant_travel {
                    true
                } else {
                    !is_adjacent(loc, action.target_location)
                };
                let c = action_ap_cost(ActionType::Travel, distant);
                // Update location after travel
                loc = action.target_location;
                c
            },
            _ => action_ap_cost(action.action_type, false),
        };
        total += cost;
        i += 1;
    };
    total
}

pub fn validate_action_batch(
    actions: Span<Action>, current_location: u8, ap_available: u8
) -> bool {
    let total = calculate_total_ap_cost(actions, current_location, false);
    total <= ap_available
}
