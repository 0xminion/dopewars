use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Operation {
    #[key]
    pub game_id: u32,
    #[key]
    pub op_id: u8,
    pub owner: ContractAddress,
    pub op_type: u8,             // 1=Laundromat, 2=CarWash, 3=TacoShop, 4=PostOffice
    pub level: u8,               // upgrade tier
    pub capacity_per_turn: u16,  // max dirty cash processed per turn
    pub processing_amount: u32,  // dirty cash currently in pipeline
    pub processing_turns_left: u8, // turns until current batch completes
    pub total_laundered: u32,    // lifetime total
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct OperationCounter {
    #[key]
    pub game_id: u32,
    pub next_op_id: u8,
    pub active_count: u8,
}
