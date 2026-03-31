use rollyourown::systems::helpers::operation_helpers::{
    process_operation_tick, start_laundering, total_laundering_capacity,
};

#[test]
fn test_process_tick_completes() {
    // Laundromat, 500 processing, 1 turn left -> produces 500 clean
    let (clean, remaining, turns) = process_operation_tick(1, 500, 1);
    assert(clean == 500, 'produces 500 clean');
    assert(remaining == 0, 'nothing remaining');
    assert(turns == 0, 'no turns left');
}

#[test]
fn test_process_tick_still_processing() {
    // 2 turns left -> nothing produced yet
    let (clean, remaining, turns) = process_operation_tick(1, 500, 2);
    assert(clean == 0, 'nothing yet');
    assert(remaining == 500, 'still processing 500');
    assert(turns == 1, '1 turn left');
}

#[test]
fn test_process_tick_empty() {
    let (clean, _, _) = process_operation_tick(1, 0, 0);
    assert(clean == 0, 'nothing to process');
}

#[test]
fn test_start_laundering_within_capacity() {
    // Laundromat capacity = 500, have 300 dirty
    let (amount, turns) = start_laundering(1, 300, 0);
    assert(amount == 300, 'queue all 300');
    assert(turns == 2, '2 turns to process');
}

#[test]
fn test_start_laundering_exceeds_capacity() {
    // Laundromat capacity = 500, have 1000 dirty
    let (amount, turns) = start_laundering(1, 1000, 0);
    assert(amount == 500, 'capped at 500');
    assert(turns == 2, '2 turns');
}

#[test]
fn test_start_laundering_already_processing() {
    let (amount, _) = start_laundering(1, 1000, 500);
    assert(amount == 0, 'cannot start while processing');
}

#[test]
fn test_total_capacity() {
    let ops: Array<u8> = array![1, 2]; // Laundromat(500) + CarWash(1200)
    let total = total_laundering_capacity(ops.span());
    assert(total == 1700, 'total 1700');
}
