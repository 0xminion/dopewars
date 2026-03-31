use rollyourown::systems::helpers::reputation_helpers::{
    award_xp, can_access_drug, get_max_slots, get_max_operations,
    get_crew_power_bonus, get_price_discount,
    BRANCH_TRADER, BRANCH_ENFORCER, BRANCH_OPERATOR,
};
use rollyourown::models::reputation::Reputation;
use starknet::contract_address_const;

#[test]
fn test_award_xp_trader() {
    let mut rep = Reputation {
        game_id: 1, player_id: contract_address_const::<0x1>(),
        trader_xp: 0, enforcer_xp: 0, operator_xp: 0,
        trader_lvl: 0, enforcer_lvl: 0, operator_lvl: 0,
    };
    award_xp(ref rep, BRANCH_TRADER, 100);
    assert(rep.trader_xp == 100, 'trader xp 100');
    assert(rep.trader_lvl == 1, 'trader lvl 1 at 100');
}

#[test]
fn test_award_xp_levels_up() {
    let mut rep = Reputation {
        game_id: 1, player_id: contract_address_const::<0x1>(),
        trader_xp: 0, enforcer_xp: 0, operator_xp: 0,
        trader_lvl: 0, enforcer_lvl: 0, operator_lvl: 0,
    };
    award_xp(ref rep, BRANCH_OPERATOR, 600);
    assert(rep.operator_lvl == 3, 'operator lvl 3 at 600');
}

#[test]
fn test_can_access_drug_by_level() {
    assert(can_access_drug(0, 4), 'lvl 0 can access drug 4');
    assert(!can_access_drug(0, 5), 'lvl 0 cannot access drug 5');
    assert(can_access_drug(1, 5), 'lvl 1 can access drug 5');
    assert(can_access_drug(5, 8), 'lvl 5 can access drug 8');
}

#[test]
fn test_max_slots_by_operator_level() {
    assert(get_max_slots(0) == 2, 'lvl 0 = 2 slots');
    assert(get_max_slots(2) == 4, 'lvl 2 = 4 slots');
    assert(get_max_slots(4) == 6, 'lvl 4 = 6 slots');
}

#[test]
fn test_crew_power_bonus() {
    assert(get_crew_power_bonus(0) == 0, 'lvl 0 no bonus');
    assert(get_crew_power_bonus(3) == 20, 'lvl 3 = 20');
}

#[test]
fn test_price_discount() {
    assert(get_price_discount(0) == 0, 'lvl 0 no discount');
    assert(get_price_discount(5) == 20, 'lvl 5 = 20%');
}
