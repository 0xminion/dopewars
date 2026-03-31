use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct CartelPlayer {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub location: u8,
    pub ap_remaining: u8,
    pub turn: u16,
    pub max_turns: u16,
    pub status: u8,
    pub score: u32,
}
