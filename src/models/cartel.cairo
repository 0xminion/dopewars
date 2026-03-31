use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Cartel {
    #[key]
    pub game_id: u32,
    #[key]
    pub owner: ContractAddress,
    pub name: felt252,
    pub slot_count: u8,
    pub stash_slot_0: u64,       // packed DrugSlot (same format as Inventory)
    pub stash_slot_1: u64,
    pub stash_slot_2: u64,
    pub stash_slot_3: u64,
    pub stash_slot_4: u64,       // extra stash capacity vs inventory
    pub stash_slot_5: u64,
    pub treasury: u32,           // cartel clean cash reserve
}
