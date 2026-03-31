#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum ActionType {
    #[default]
    None,
    Travel,
    Buy,
    Sell,
    Mix,
    Scout,
    Manage,
    Invest,
    Rest,
}

#[derive(Copy, Drop, Serde, Introspect)]
pub struct Action {
    pub action_type: ActionType,
    pub target_location: u8,
    pub drug_id: u8,
    pub quantity: u16,
    pub ingredient_id: u8,
    pub slot_index: u8,
}

pub fn action_ap_cost(action_type: ActionType, is_distant: bool) -> u8 {
    match action_type {
        ActionType::None => 0,
        ActionType::Travel => if is_distant { 2 } else { 1 },
        ActionType::Buy => 1,
        ActionType::Sell => 1,
        ActionType::Mix => 2,
        ActionType::Scout => 1,
        ActionType::Manage => 1,
        ActionType::Invest => 1,
        ActionType::Rest => 2,
    }
}

pub const MAX_ACTIONS_PER_TURN: u8 = 4;
