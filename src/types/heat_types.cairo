#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum HeatTier {
    #[default]
    None,
    Surveillance,
    Wanted,
    DeadOrAlive,
}

pub fn encounter_rate_pct(tier: HeatTier) -> u8 {
    match tier {
        HeatTier::None => 0,
        HeatTier::Surveillance => 5,
        HeatTier::Wanted => 20,
        HeatTier::DeadOrAlive => 40,
    }
}

pub fn heat_tier_multiplier(tier: HeatTier) -> u8 {
    match tier {
        HeatTier::None => 0,
        HeatTier::Surveillance => 1,
        HeatTier::Wanted => 3,
        HeatTier::DeadOrAlive => 6,
    }
}
