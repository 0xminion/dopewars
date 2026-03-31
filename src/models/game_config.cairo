#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct GameConfig {
    #[key]
    pub game_id: u32,
    pub mode: u8,
    pub max_turns: u16,
    pub ap_per_turn: u8,
    pub starting_dirty_cash: u32,
    pub starting_clean_cash: u32,
    pub heat_decay_rate: u8,
    pub max_dealer_slots: u8,
    pub season_id: u32,
}
