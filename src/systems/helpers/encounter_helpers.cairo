#[derive(Copy, Drop, PartialEq)]
pub enum EncounterOutcome {
    Win,
    Lose,
}

#[derive(Copy, Drop)]
pub struct EncounterLoss {
    pub cash_percent: u8,
    pub drug_percent: u8,
    pub notoriety_gain: u16,
}

// Encounter trigger rates per heat tier (percent)
// tier 0=0%, 1=5%, 2=20%, 3=40%
fn encounter_rate(heat_tier: u8) -> u8 {
    match heat_tier {
        0 => 0,
        1 => 5,
        2 => 20,
        3 => 40,
        _ => 40,
    }
}

// Heat tier multipliers: [0, 1, 3, 6]
fn heat_tier_multiplier(heat_tier: u8) -> u32 {
    match heat_tier {
        0 => 0,
        1 => 1,
        2 => 3,
        3 => 6,
        _ => 6,
    }
}

pub fn should_trigger_encounter(heat_tier: u8, danger_level: u8, roll: u8) -> bool {
    let rate = encounter_rate(heat_tier);
    let danger: u16 = danger_level.into();
    let base: u16 = rate.into();
    // Combine heat rate with location danger (danger_level up to 10)
    let effective_rate: u16 = base + danger / 2;
    roll.into() < effective_rate
}

pub fn calculate_crew_power(enforcer_lvl: u8, crew_combat_stats: u32) -> u32 {
    let base: u32 = 10;
    let enf: u32 = enforcer_lvl.into();
    base + enf * 5 + crew_combat_stats
}

pub fn calculate_threat(heat_tier: u8, danger_level: u8, vrf_roll_percent: u8) -> u32 {
    let mult = heat_tier_multiplier(heat_tier);
    let danger: u32 = danger_level.into();
    let roll: u32 = vrf_roll_percent.into();
    let base_threat = mult * danger * 2;
    base_threat + roll / 10
}

pub fn resolve_encounter(crew_power: u32, threat: u32) -> EncounterOutcome {
    if crew_power >= threat {
        EncounterOutcome::Win
    } else {
        EncounterOutcome::Lose
    }
}

pub fn get_loss_severity(heat_tier: u8) -> EncounterLoss {
    match heat_tier {
        0 => EncounterLoss { cash_percent: 0, drug_percent: 0, notoriety_gain: 0 },
        1 => EncounterLoss { cash_percent: 10, drug_percent: 5, notoriety_gain: 5 },
        2 => EncounterLoss { cash_percent: 25, drug_percent: 15, notoriety_gain: 15 },
        3 => EncounterLoss { cash_percent: 50, drug_percent: 30, notoriety_gain: 30 },
        _ => EncounterLoss { cash_percent: 50, drug_percent: 30, notoriety_gain: 30 },
    }
}
