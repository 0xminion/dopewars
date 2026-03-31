#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct CartelMarket {
    #[key]
    pub game_id: u32,
    #[key]
    pub location_id: u8,
    pub drug_prices: u128,
    pub drug_supply: u128,
    pub last_event: u8,
    pub visible_to: felt252,
}

pub fn get_drug_price_tick(packed: u128, drug_idx: u8) -> u16 {
    let shift: u128 = 65536;
    let mut divisor: u128 = 1;
    let mut i: u8 = 0;
    while i < drug_idx {
        divisor = divisor * shift;
        i += 1;
    };
    ((packed / divisor) & 0xFFFF).try_into().unwrap()
}

pub fn set_drug_price_tick(packed: u128, drug_idx: u8, value: u16) -> u128 {
    let shift: u128 = 65536;
    let mut divisor: u128 = 1;
    let mut i: u8 = 0;
    while i < drug_idx {
        divisor = divisor * shift;
        i += 1;
    };
    let mask: u128 = 0xFFFF * divisor;
    let max_u128: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    let cleared = packed & (max_u128 - mask);
    cleared + (value.into() * divisor)
}

pub fn get_drug_supply(packed: u128, drug_idx: u8) -> u16 {
    get_drug_price_tick(packed, drug_idx)
}

pub fn set_drug_supply(packed: u128, drug_idx: u8, value: u16) -> u128 {
    set_drug_price_tick(packed, drug_idx, value)
}
