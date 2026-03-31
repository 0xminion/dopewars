#[derive(Copy, Drop)]
pub struct ModeConfig {
    pub max_turns: u16,
    pub ap_per_turn: u8,
    pub starting_dirty_cash: u32,
    pub starting_clean_cash: u32,
    pub heat_decay_rate: u8,
    pub max_dealer_slots: u8,
}

pub fn get_mode_config(mode: u8) -> ModeConfig {
    match mode {
        0 => ModeConfig {
            max_turns: 25, ap_per_turn: 4, starting_dirty_cash: 5000,
            starting_clean_cash: 2000, heat_decay_rate: 2, max_dealer_slots: 2,
        },
        1 => ModeConfig {
            max_turns: 60, ap_per_turn: 3, starting_dirty_cash: 2000,
            starting_clean_cash: 500, heat_decay_rate: 1, max_dealer_slots: 4,
        },
        _ => ModeConfig {
            max_turns: 25, ap_per_turn: 4, starting_dirty_cash: 5000,
            starting_clean_cash: 2000, heat_decay_rate: 2, max_dealer_slots: 2,
        },
    }
}
