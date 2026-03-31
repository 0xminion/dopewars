#[starknet::interface]
pub trait IOperationSystem<T> {
    fn buy_operation(ref self: T, game_id: u32, op_type: u8) -> u8;
    fn start_laundering(ref self: T, game_id: u32, op_id: u8, amount: u32);
    fn get_operation_status(self: @T, game_id: u32, op_id: u8) -> (u8, u32, u8); // (op_type, processing, turns_left)
}

#[dojo::contract]
pub mod operation_system {
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;

    use crate::models::operation::{Operation, OperationCounter};
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::config::operation_config::get_op_config;
    use crate::systems::helpers::reputation_helpers::get_max_operations;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl OperationSystemImpl of super::IOperationSystem<ContractState> {

        fn buy_operation(ref self: ContractState, game_id: u32, op_type: u8) -> u8 {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            let config = get_op_config(op_type);
            assert(config.purchase_cost > 0, 'invalid op type');

            // Check operator level unlock
            let reputation: Reputation = world.read_model((game_id, caller));
            let max_ops = get_max_operations(reputation.operator_lvl);
            let mut counter: OperationCounter = world.read_model((game_id, caller));
            assert(counter.active_count < max_ops, 'op limit reached');
            assert(reputation.operator_lvl >= config.unlock_operator_lvl, 'operator level too low');

            // Check cost
            let mut wallet: WalletState = world.read_model((game_id, caller));
            assert(wallet.dirty_cash >= config.purchase_cost, 'not enough cash');
            wallet.dirty_cash = wallet.dirty_cash - config.purchase_cost;
            world.write_model(@wallet);

            // Create operation
            let op_id = counter.next_op_id;
            let operation = Operation {
                game_id,
                op_id,
                owner: caller,
                op_type,
                level: 1,
                capacity_per_turn: config.capacity_per_turn,
                processing_amount: 0,
                processing_turns_left: 0,
                total_laundered: 0,
            };
            world.write_model(@operation);

            counter.next_op_id = op_id + 1;
            counter.active_count = counter.active_count + 1;
            world.write_model(@counter);

            // Award operator XP
            let mut rep: Reputation = world.read_model((game_id, caller));
            rep.operator_xp = rep.operator_xp + 20;
            world.write_model(@rep);

            op_id
        }

        fn start_laundering(ref self: ContractState, game_id: u32, op_id: u8, amount: u32) {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            assert(amount > 0, 'amount must be positive');

            let mut operation: Operation = world.read_model((game_id, op_id));
            assert(operation.owner == caller, 'not op owner');
            assert(operation.processing_amount == 0, 'already processing');

            let mut wallet: WalletState = world.read_model((game_id, caller));
            let capacity: u32 = operation.capacity_per_turn.into();
            let queue_amount = if amount > capacity { capacity } else { amount };
            assert(wallet.dirty_cash >= queue_amount, 'not enough dirty cash');

            // Deduct dirty cash and start processing
            wallet.dirty_cash = wallet.dirty_cash - queue_amount;
            world.write_model(@wallet);

            let config = get_op_config(operation.op_type);
            operation.processing_amount = queue_amount;
            operation.processing_turns_left = config.processing_turns;
            world.write_model(@operation);

            // Award operator XP
            let mut rep: Reputation = world.read_model((game_id, caller));
            rep.operator_xp = rep.operator_xp + 5;
            world.write_model(@rep);
        }

        fn get_operation_status(self: @ContractState, game_id: u32, op_id: u8) -> (u8, u32, u8) {
            let world = self.world(ns());
            let operation: Operation = world.read_model((game_id, op_id));
            (operation.op_type, operation.processing_amount, operation.processing_turns_left)
        }
    }
}
