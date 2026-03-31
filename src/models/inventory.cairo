use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Inventory {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub slot_0: u64,
    pub slot_1: u64,
    pub slot_2: u64,
    pub slot_3: u64,
}

pub fn pack_drug_slot(drug_id: u8, quantity: u16, quality: u8, effects: u32) -> u64 {
    let mut packed: u64 = 0;
    packed = packed | (drug_id.into());
    packed = packed | ((quantity.into()) * 0x100);
    packed = packed | ((quality.into()) * 0x1000000);
    packed = packed | ((effects.into()) * 0x100000000);
    packed
}

pub fn unpack_drug_slot(packed: u64) -> (u8, u16, u8, u32) {
    let drug_id: u8 = (packed & 0xFF).try_into().unwrap();
    let quantity: u16 = ((packed / 0x100) & 0xFFFF).try_into().unwrap();
    let quality: u8 = ((packed / 0x1000000) & 0xFF).try_into().unwrap();
    let effects: u32 = ((packed / 0x100000000) & 0xFFFFFFFF).try_into().unwrap();
    (drug_id, quantity, quality, effects)
}
