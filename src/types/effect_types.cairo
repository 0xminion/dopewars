#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum EffectId {
    #[default]
    None,
    Cut,
    Energizing,
    Potent,
    Bulking,
    Healthy,
    Toxic,
    Speedy,
    Electric,
}

pub const EFFECT_COUNT: u8 = 8;

pub fn effect_multiplier_bps(effect_id: u8) -> u16 {
    match effect_id {
        0 => 0,
        1 => 5,
        2 => 22,
        3 => 30,
        4 => 10,
        5 => 15,
        6 => 35,
        7 => 40,
        8 => 50,
        _ => 0,
    }
}
