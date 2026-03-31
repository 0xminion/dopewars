#[derive(Copy, Drop)]
pub struct IngredientConfig {
    pub effect_id: u8,
    pub cost: u16,
    pub unlock_rank: u8,
}

pub fn get_ingredient_config(ingredient_id: u8) -> IngredientConfig {
    if ingredient_id == 1 {
        IngredientConfig { effect_id: 1, cost: 5,  unlock_rank: 0 }
    } else if ingredient_id == 2 {
        IngredientConfig { effect_id: 2, cost: 10, unlock_rank: 0 }
    } else if ingredient_id == 3 {
        IngredientConfig { effect_id: 3, cost: 20, unlock_rank: 1 }
    } else if ingredient_id == 4 {
        IngredientConfig { effect_id: 4, cost: 8,  unlock_rank: 0 }
    } else if ingredient_id == 5 {
        IngredientConfig { effect_id: 5, cost: 12, unlock_rank: 1 }
    } else if ingredient_id == 6 {
        IngredientConfig { effect_id: 6, cost: 30, unlock_rank: 2 }
    } else if ingredient_id == 7 {
        IngredientConfig { effect_id: 7, cost: 40, unlock_rank: 3 }
    } else if ingredient_id == 8 {
        IngredientConfig { effect_id: 8, cost: 50, unlock_rank: 4 }
    } else {
        IngredientConfig { effect_id: 0, cost: 0, unlock_rank: 0 }
    }
}
