use crate::models::reputation::{Reputation, xp_to_level};
use crate::config::reputation_config::{get_trader_unlocks, get_enforcer_unlocks, get_operator_unlocks};

pub fn award_xp(ref reputation: Reputation, branch: u8, amount: u16) {
    // branch: 0=trader, 1=enforcer, 2=operator
    if branch == 0 {
        reputation.trader_xp = reputation.trader_xp + amount;
        reputation.trader_lvl = xp_to_level(reputation.trader_xp);
    } else if branch == 1 {
        reputation.enforcer_xp = reputation.enforcer_xp + amount;
        reputation.enforcer_lvl = xp_to_level(reputation.enforcer_xp);
    } else if branch == 2 {
        reputation.operator_xp = reputation.operator_xp + amount;
        reputation.operator_lvl = xp_to_level(reputation.operator_xp);
    }
}

pub fn can_access_drug(trader_lvl: u8, drug_id: u8) -> bool {
    let unlocks = get_trader_unlocks(trader_lvl);
    drug_id <= unlocks.max_drug_tier
}

pub fn get_max_slots(operator_lvl: u8) -> u8 {
    let unlocks = get_operator_unlocks(operator_lvl);
    unlocks.max_slots
}

pub fn get_max_operations(operator_lvl: u8) -> u8 {
    let unlocks = get_operator_unlocks(operator_lvl);
    unlocks.max_operations
}

pub fn get_crew_power_bonus(enforcer_lvl: u8) -> u32 {
    let unlocks = get_enforcer_unlocks(enforcer_lvl);
    unlocks.crew_power_bonus
}

pub fn get_price_discount(trader_lvl: u8) -> u8 {
    let unlocks = get_trader_unlocks(trader_lvl);
    unlocks.price_discount_pct
}

// XP branch constants
pub const BRANCH_TRADER: u8 = 0;
pub const BRANCH_ENFORCER: u8 = 1;
pub const BRANCH_OPERATOR: u8 = 2;
