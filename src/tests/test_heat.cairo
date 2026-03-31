use crate::models::heat::{get_location_heat, set_location_heat};
use crate::config::heat_config::notoriety_to_tier;

#[test]
fn test_location_heat_pack_unpack() {
    let packed: u64 = 0;
    // Set location index 0 to value 42
    let p1 = set_location_heat(packed, 0, 42);
    assert(get_location_heat(p1, 0) == 42, 'wrong heat at idx 0');

    // Set location index 2 to value 100
    let p2 = set_location_heat(p1, 2, 100);
    assert(get_location_heat(p2, 0) == 42, 'idx 0 corrupted');
    assert(get_location_heat(p2, 2) == 100, 'wrong heat at idx 2');
    assert(get_location_heat(p2, 1) == 0, 'idx 1 should be 0');

    // Overwrite index 0
    let p3 = set_location_heat(p2, 0, 7);
    assert(get_location_heat(p3, 0) == 7, 'wrong overwrite idx 0');
    assert(get_location_heat(p3, 2) == 100, 'idx 2 corrupted after overwrite');
}

#[test]
fn test_notoriety_to_tier_thresholds() {
    // Below surveillance threshold (20) => tier 0
    assert(notoriety_to_tier(0) == 0, 'notoriety 0 should be tier 0');
    assert(notoriety_to_tier(19) == 0, 'notoriety 19 should be tier 0');

    // At/above surveillance threshold => tier 1
    assert(notoriety_to_tier(20) == 1, 'notoriety 20 should be tier 1');
    assert(notoriety_to_tier(49) == 1, 'notoriety 49 should be tier 1');

    // At/above wanted threshold (50) => tier 2
    assert(notoriety_to_tier(50) == 2, 'notoriety 50 should be tier 2');
    assert(notoriety_to_tier(99) == 2, 'notoriety 99 should be tier 2');

    // At/above DOA threshold (100) => tier 3
    assert(notoriety_to_tier(100) == 3, 'notoriety 100 should be tier 3');
    assert(notoriety_to_tier(200) == 3, 'notoriety 200 should be tier 3');
}
