use crate::systems::helpers::encounter_helpers::{
    EncounterOutcome, should_trigger_encounter, calculate_crew_power,
    calculate_threat, resolve_encounter, get_loss_severity,
};

#[test]
fn test_no_encounter_tier_zero() {
    // tier 0 => rate 0%, no danger => effective rate 0, any roll should not trigger
    assert(!should_trigger_encounter(0, 0, 0), 'tier 0 should never trigger');
    assert(!should_trigger_encounter(0, 0, 50), 'tier 0 roll 50 no trigger');
}

#[test]
fn test_encounter_triggers_tier_3() {
    // tier 3 => rate 40%, danger 6 => effective ~43%, roll=30 should trigger
    assert(should_trigger_encounter(3, 6, 30), 'should trigger at tier 3');
}

#[test]
fn test_encounter_does_not_trigger_high_roll() {
    // tier 1 => rate 5%, roll=99 should not trigger
    assert(!should_trigger_encounter(1, 0, 99), 'should not trigger high roll');
}

#[test]
fn test_crew_power() {
    // base 10 + enforcer_lvl * 5 + crew
    let power = calculate_crew_power(3, 20);
    assert(power == 45, 'wrong crew power');
}

#[test]
fn test_resolve_win() {
    let outcome = resolve_encounter(50, 30);
    assert(outcome == EncounterOutcome::Win, 'should win');
}

#[test]
fn test_resolve_lose() {
    let outcome = resolve_encounter(10, 50);
    assert(outcome == EncounterOutcome::Lose, 'should lose');
}

#[test]
fn test_loss_severity() {
    let loss = get_loss_severity(2);
    assert(loss.cash_percent == 25, 'wrong cash percent');
    assert(loss.drug_percent == 15, 'wrong drug percent');
    assert(loss.notoriety_gain == 15, 'wrong notoriety gain');
}
