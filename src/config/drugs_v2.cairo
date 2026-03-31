#[derive(Copy, Drop)]
pub struct DrugConfig {
    pub base_price: u16,
    pub price_step: u16,
    pub weight: u8,
    pub initial_supply: u16,
    pub unlock_rank: u8,
}

pub fn get_drug_config(drug_id: u8) -> DrugConfig {
    if drug_id == 1 {
        DrugConfig { base_price: 15,  price_step: 2,  weight: 1, initial_supply: 200, unlock_rank: 0 }
    } else if drug_id == 2 {
        DrugConfig { base_price: 30,  price_step: 4,  weight: 1, initial_supply: 150, unlock_rank: 0 }
    } else if drug_id == 3 {
        DrugConfig { base_price: 60,  price_step: 6,  weight: 1, initial_supply: 100, unlock_rank: 1 }
    } else if drug_id == 4 {
        DrugConfig { base_price: 100, price_step: 10, weight: 2, initial_supply: 80,  unlock_rank: 1 }
    } else if drug_id == 5 {
        DrugConfig { base_price: 200, price_step: 15, weight: 2, initial_supply: 60,  unlock_rank: 2 }
    } else if drug_id == 6 {
        DrugConfig { base_price: 400, price_step: 25, weight: 3, initial_supply: 40,  unlock_rank: 3 }
    } else if drug_id == 7 {
        DrugConfig { base_price: 600, price_step: 40, weight: 3, initial_supply: 30,  unlock_rank: 4 }
    } else if drug_id == 8 {
        DrugConfig { base_price: 1000, price_step: 60, weight: 4, initial_supply: 20, unlock_rank: 5 }
    } else {
        DrugConfig { base_price: 0, price_step: 0, weight: 0, initial_supply: 0, unlock_rank: 0 }
    }
}
