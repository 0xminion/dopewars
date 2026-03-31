pub const TIER_SURVEILLANCE_THRESHOLD: u16 = 20;
pub const TIER_WANTED_THRESHOLD: u16 = 50;
pub const TIER_DOA_THRESHOLD: u16 = 100;

pub const SELL_NOTORIETY: u16 = 3;
pub const FIGHT_COP_NOTORIETY: u16 = 15;
pub const TRAVEL_WITH_DRUGS_NOTORIETY: u16 = 2;

pub const BRIBE_COST_WANTED: u32 = 1000;
pub const BRIBE_COST_DOA: u32 = 5000;
pub const REST_TURNS_SURVEILLANCE: u8 = 2;
pub const REST_TURNS_WANTED: u8 = 3;
pub const REST_TURNS_DOA: u8 = 5;

pub fn notoriety_to_tier(notoriety: u16) -> u8 {
    if notoriety >= TIER_DOA_THRESHOLD { 3 }
    else if notoriety >= TIER_WANTED_THRESHOLD { 2 }
    else if notoriety >= TIER_SURVEILLANCE_THRESHOLD { 1 }
    else { 0 }
}
