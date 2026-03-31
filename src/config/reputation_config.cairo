// XP thresholds per level (already defined in models/reputation.cairo)
// This file defines what each level unlocks

#[derive(Copy, Drop)]
pub struct ReputationUnlocks {
    pub max_drug_tier: u8,       // Trader: highest drug_id accessible
    pub price_discount_pct: u8,  // Trader: % discount on buys
    pub crew_power_bonus: u32,   // Enforcer: added to crew_power
    pub max_slots: u8,           // Operator: max agent slots
    pub max_operations: u8,      // Operator: max laundering ops
}

pub fn get_trader_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 5, price_discount_pct: 5, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 6, price_discount_pct: 10, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 7, price_discount_pct: 15, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 8, price_discount_pct: 18, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else {
        ReputationUnlocks { max_drug_tier: 8, price_discount_pct: 20, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    }
}

pub fn get_enforcer_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 5, max_slots: 2, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 12, max_slots: 2, max_operations: 1 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 20, max_slots: 2, max_operations: 1 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 30, max_slots: 2, max_operations: 1 }
    } else {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 40, max_slots: 2, max_operations: 1 }
    }
}

pub fn get_operator_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 3, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 4, max_operations: 2 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 5, max_operations: 3 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 6, max_operations: 4 }
    } else {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 6, max_operations: 4 }
    }
}
