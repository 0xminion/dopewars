#[derive(Copy, Drop)]
pub struct OpTypeConfig {
    pub purchase_cost: u32,      // dirty cash to buy
    pub capacity_per_turn: u16,  // dirty cash laundered per turn
    pub processing_turns: u8,    // turns to process a batch
    pub unlock_operator_lvl: u8, // minimum Operator reputation level
}

pub fn get_op_config(op_type: u8) -> OpTypeConfig {
    if op_type == 1 { // Laundromat
        OpTypeConfig { purchase_cost: 2000, capacity_per_turn: 500, processing_turns: 2, unlock_operator_lvl: 1 }
    } else if op_type == 2 { // Car Wash
        OpTypeConfig { purchase_cost: 5000, capacity_per_turn: 1200, processing_turns: 2, unlock_operator_lvl: 2 }
    } else if op_type == 3 { // Taco Shop
        OpTypeConfig { purchase_cost: 12000, capacity_per_turn: 2500, processing_turns: 2, unlock_operator_lvl: 3 }
    } else if op_type == 4 { // Post Office
        OpTypeConfig { purchase_cost: 25000, capacity_per_turn: 5000, processing_turns: 2, unlock_operator_lvl: 4 }
    } else {
        OpTypeConfig { purchase_cost: 0, capacity_per_turn: 0, processing_turns: 0, unlock_operator_lvl: 0 }
    }
}

pub const MAX_OPERATIONS: u8 = 4;
