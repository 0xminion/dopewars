#[derive(Copy, Drop)]
pub struct SlotTypeConfig {
    pub hire_cost: u32,          // dirty cash to hire
    pub base_reliability: u8,
    pub base_stealth: u8,
    pub base_salesmanship: u8,
    pub base_combat: u8,
    pub commission_pct: u8,      // % of sales kept by slot
}

pub fn get_slot_type_config(slot_type: u8) -> SlotTypeConfig {
    if slot_type == 1 { // Dealer
        SlotTypeConfig {
            hire_cost: 500,
            base_reliability: 60,
            base_stealth: 40,
            base_salesmanship: 70,
            base_combat: 20,
            commission_pct: 20,
        }
    } else if slot_type == 4 { // Muscle
        SlotTypeConfig {
            hire_cost: 800,
            base_reliability: 70,
            base_stealth: 30,
            base_salesmanship: 10,
            base_combat: 80,
            commission_pct: 0,
        }
    } else {
        SlotTypeConfig {
            hire_cost: 0,
            base_reliability: 0,
            base_stealth: 0,
            base_salesmanship: 0,
            base_combat: 0,
            commission_pct: 0,
        }
    }
}

pub const BUST_DURATION_TURNS: u16 = 3;
pub const MAX_SLOTS_PER_GAME: u8 = 6;
