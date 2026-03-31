use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Reputation {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub trader_xp: u16,
    pub enforcer_xp: u16,
    pub operator_xp: u16,
    pub trader_lvl: u8,
    pub enforcer_lvl: u8,
    pub operator_lvl: u8,
}

pub const LEVEL_THRESHOLDS: [u16; 5] = [100, 300, 600, 1000, 1500];

pub fn xp_to_level(xp: u16) -> u8 {
    if xp >= 1500 { 5 }
    else if xp >= 1000 { 4 }
    else if xp >= 600 { 3 }
    else if xp >= 300 { 2 }
    else if xp >= 100 { 1 }
    else { 0 }
}
