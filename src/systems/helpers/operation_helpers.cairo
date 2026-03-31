use crate::config::operation_config::get_op_config;

// Process one tick of laundering for an operation
// Returns amount of dirty cash converted to clean cash this tick
pub fn process_operation_tick(
    op_type: u8,
    processing_amount: u32,
    processing_turns_left: u8,
) -> (u32, u32, u8) { // (clean_cash_produced, remaining_processing, new_turns_left)
    if processing_turns_left == 0 || processing_amount == 0 {
        return (0, processing_amount, processing_turns_left);
    }

    let new_turns = processing_turns_left - 1;
    if new_turns == 0 {
        // Processing complete — all dirty cash becomes clean
        (processing_amount, 0, 0)
    } else {
        // Still processing
        (0, processing_amount, new_turns)
    }
}

// Start a new laundering batch
// Returns (amount_queued, processing_turns)
pub fn start_laundering(
    op_type: u8,
    dirty_cash_available: u32,
    current_processing: u32,
) -> (u32, u8) { // (amount_to_queue, processing_turns)
    // Can only start if not currently processing
    if current_processing > 0 {
        return (0, 0);
    }

    let config = get_op_config(op_type);
    let capacity: u32 = config.capacity_per_turn.into();

    // Queue up to capacity
    let amount = if dirty_cash_available > capacity { capacity } else { dirty_cash_available };
    (amount, config.processing_turns)
}

// Calculate total laundering capacity across all operations
pub fn total_laundering_capacity(op_types: Span<u8>) -> u32 {
    let mut total: u32 = 0;
    let mut i: u32 = 0;
    let len = op_types.len();
    while i < len {
        let config = get_op_config(*op_types.at(i));
        total = total + config.capacity_per_turn.into();
        i += 1;
    };
    total
}
