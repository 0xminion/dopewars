#[derive(Copy, Drop)]
pub struct LocationConfig {
    pub name_id: u8,
    pub danger_level: u8,
    pub adjacent_mask: u64,
}

pub fn get_location_config(location_id: u8) -> LocationConfig {
    if location_id == 1 {
        LocationConfig { name_id: 1, danger_level: 3, adjacent_mask: 0b000110 }
    } else if location_id == 2 {
        LocationConfig { name_id: 2, danger_level: 7, adjacent_mask: 0b010001 }
    } else if location_id == 3 {
        LocationConfig { name_id: 3, danger_level: 5, adjacent_mask: 0b101001 }
    } else if location_id == 4 {
        LocationConfig { name_id: 4, danger_level: 4, adjacent_mask: 0b010100 }
    } else if location_id == 5 {
        LocationConfig { name_id: 5, danger_level: 6, adjacent_mask: 0b001010 }
    } else if location_id == 6 {
        LocationConfig { name_id: 6, danger_level: 2, adjacent_mask: 0b000100 }
    } else {
        LocationConfig { name_id: 0, danger_level: 0, adjacent_mask: 0 }
    }
}

pub fn is_adjacent(from: u8, to: u8) -> bool {
    if from == 0 || to == 0 || from > 6 || to > 6 {
        return false;
    }
    let config = get_location_config(from);
    let mut shift: u64 = 1;
    let mut i: u8 = 1;
    while i < to {
        shift = shift * 2;
        i += 1;
    };
    (config.adjacent_mask & shift) != 0
}
