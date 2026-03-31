use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct HeatProfile {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub tier: u8,
    pub notoriety: u16,
    pub location_heat: u64,
}

pub fn get_location_heat(packed: u64, location_idx: u8) -> u8 {
    let shift: u64 = 256;
    let mut divisor: u64 = 1;
    let mut i: u8 = 0;
    while i < location_idx {
        divisor = divisor * shift;
        i += 1;
    };
    ((packed / divisor) & 0xFF).try_into().unwrap()
}

pub fn set_location_heat(packed: u64, location_idx: u8, value: u8) -> u64 {
    let shift: u64 = 256;
    let mut divisor: u64 = 1;
    let mut i: u8 = 0;
    while i < location_idx {
        divisor = divisor * shift;
        i += 1;
    };
    let mask = 0xFF * divisor;
    let cleared = packed & (0xFFFFFFFFFFFFFFFF - mask);
    cleared + (value.into() * divisor)
}
