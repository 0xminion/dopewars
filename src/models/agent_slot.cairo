use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum SlotType {
    #[default]
    None,
    Dealer,
    Cook,
    Runner,
    Muscle,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum ControllerType {
    #[default]
    NPC,
    Agent,
    Human,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum SlotStatus {
    #[default]
    Inactive,
    Active,
    Busted,
    LayingLow,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct AgentSlot {
    #[key]
    pub game_id: u32,
    #[key]
    pub slot_id: u8,
    pub owner: ContractAddress,
    pub slot_type: u8,           // SlotType as u8 (1=Dealer)
    pub controller_type: u8,     // ControllerType as u8 (0=NPC, 1=Agent)
    pub controller_addr: ContractAddress,
    pub strategy: u8,            // 0=cautious, 1=aggressive, 2=balanced
    pub reliability: u8,         // 1-100
    pub stealth: u8,             // 1-100
    pub salesmanship: u8,        // 1-100
    pub combat: u8,              // 1-100
    pub location: u8,            // assigned location (1-6)
    pub drug_id: u8,             // drug they're selling
    pub drug_quantity: u16,      // inventory they hold
    pub drug_effects: u32,       // effects on their product
    pub status: u8,              // SlotStatus as u8
    pub earnings_held: u32,      // uncollected dirty cash
    pub busted_until_turn: u16,  // turn when bust ends
}

// Slot counter per game
#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct SlotCounter {
    #[key]
    pub game_id: u32,
    pub next_slot_id: u8,
    pub active_count: u8,
}
