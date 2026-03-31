#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct CartelLocation {
    #[key]
    pub game_id: u32,
    #[key]
    pub location_id: u8,
    pub danger_level: u8,
    pub is_adjacent_to: u64,
}
