use starknet::ContractAddress;

#[starknet::interface]
pub trait ISlotSystem<T> {
    fn hire_slot(ref self: T, game_id: u32, slot_type: u8, location: u8) -> u8;
    fn set_strategy(ref self: T, game_id: u32, slot_id: u8, strategy: u8);
    fn restock_slot(ref self: T, game_id: u32, slot_id: u8, drug_id: u8, quantity: u16, effects: u32);
    fn collect_earnings(ref self: T, game_id: u32, slot_id: u8) -> u32;
    fn fire_slot(ref self: T, game_id: u32, slot_id: u8);
    fn get_slot_status(self: @T, game_id: u32, slot_id: u8) -> (u8, u32, u16); // (status, earnings, quantity)
}

#[dojo::contract]
pub mod slot_system {
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;

    use crate::models::agent_slot::{AgentSlot, SlotCounter};
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::models::inventory::{Inventory, pack_drug_slot, unpack_drug_slot};
    use crate::config::slot_config::get_slot_type_config;
    use crate::systems::helpers::reputation_helpers::{get_max_slots, can_access_drug};

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl SlotSystemImpl of super::ISlotSystem<ContractState> {

        fn hire_slot(ref self: ContractState, game_id: u32, slot_type: u8, location: u8) -> u8 {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            // Check slot limit
            let mut counter: SlotCounter = world.read_model((game_id, caller));
            let reputation: Reputation = world.read_model((game_id, caller));
            let config: crate::models::game_config::GameConfig = world.read_model(game_id);
            let rep_max = get_max_slots(reputation.operator_lvl);
            let game_max = config.max_dealer_slots;
            let effective_max = if rep_max < game_max { rep_max } else { game_max };
            assert(counter.active_count < effective_max, 'slot limit reached');

            // Check cost
            let config = get_slot_type_config(slot_type);
            assert(config.hire_cost > 0, 'invalid slot type');
            let mut wallet: WalletState = world.read_model((game_id, caller));
            assert(wallet.dirty_cash >= config.hire_cost, 'not enough cash');
            wallet.dirty_cash = wallet.dirty_cash - config.hire_cost;
            world.write_model(@wallet);

            // Validate location
            assert(location >= 1 && location <= 6, 'invalid location');

            // Create slot
            let slot_id = counter.next_slot_id;
            let slot = AgentSlot {
                game_id,
                slot_id,
                owner: caller,
                slot_type,
                controller_type: 0, // NPC
                controller_addr: caller,
                strategy: 2, // balanced default
                reliability: config.base_reliability,
                stealth: config.base_stealth,
                salesmanship: config.base_salesmanship,
                combat: config.base_combat,
                location,
                drug_id: 0,
                drug_quantity: 0,
                drug_effects: 0,
                status: 1, // Active
                earnings_held: 0,
                busted_until_turn: 0,
            };
            world.write_model(@slot);

            counter.next_slot_id = slot_id + 1;
            counter.active_count = counter.active_count + 1;
            world.write_model(@counter);

            // Award operator XP
            let mut rep: Reputation = world.read_model((game_id, caller));
            rep.operator_xp = rep.operator_xp + 10;
            world.write_model(@rep);

            slot_id
        }

        fn set_strategy(ref self: ContractState, game_id: u32, slot_id: u8, strategy: u8) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let mut slot: AgentSlot = world.read_model((game_id, slot_id));
            assert(slot.owner == caller, 'not slot owner');
            assert(strategy <= 2, 'invalid strategy');
            slot.strategy = strategy;
            world.write_model(@slot);
        }

        fn restock_slot(
            ref self: ContractState,
            game_id: u32,
            slot_id: u8,
            drug_id: u8,
            quantity: u16,
            effects: u32,
        ) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let mut slot: AgentSlot = world.read_model((game_id, slot_id));
            assert(slot.owner == caller, 'not slot owner');
            assert(slot.status == 1, 'slot not active');

            // Validate drug_id
            assert(drug_id >= 1 && drug_id <= 8, 'invalid drug id');

            // Check drug tier access via reputation
            let reputation: Reputation = world.read_model((game_id, caller));
            assert(can_access_drug(reputation.trader_lvl, drug_id), 'drug tier locked');

            // Deduct from player inventory
            let mut inv: Inventory = world.read_model((game_id, caller));
            let mut found = false;
            let mut i: u8 = 0;
            while i < 4 {
                let packed = if i == 0 { inv.slot_0 }
                    else if i == 1 { inv.slot_1 }
                    else if i == 2 { inv.slot_2 }
                    else { inv.slot_3 };
                let (slot_drug, slot_qty, slot_quality, slot_effects) = unpack_drug_slot(packed);
                if slot_drug == drug_id && slot_qty >= quantity {
                    let remaining = slot_qty - quantity;
                    let new_packed = if remaining == 0 {
                        0_u64
                    } else {
                        pack_drug_slot(slot_drug, remaining, slot_quality, slot_effects)
                    };
                    if i == 0 { inv.slot_0 = new_packed; }
                    else if i == 1 { inv.slot_1 = new_packed; }
                    else if i == 2 { inv.slot_2 = new_packed; }
                    else { inv.slot_3 = new_packed; };
                    found = true;
                    break;
                }
                i += 1;
            };
            assert(found, 'insufficient inventory');
            world.write_model(@inv);

            // Transfer to dealer slot
            slot.drug_id = drug_id;
            slot.drug_quantity = slot.drug_quantity + quantity;
            slot.drug_effects = effects;
            world.write_model(@slot);
        }

        fn collect_earnings(ref self: ContractState, game_id: u32, slot_id: u8) -> u32 {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let mut slot: AgentSlot = world.read_model((game_id, slot_id));
            assert(slot.owner == caller, 'not slot owner');

            let earnings = slot.earnings_held;
            slot.earnings_held = 0;
            world.write_model(@slot);

            // Add to player dirty cash
            let mut wallet: WalletState = world.read_model((game_id, caller));
            let max_cash: u32 = 0xFFFFFFFF;
            if wallet.dirty_cash > max_cash - earnings {
                wallet.dirty_cash = max_cash;
            } else {
                wallet.dirty_cash = wallet.dirty_cash + earnings;
            }
            world.write_model(@wallet);

            earnings
        }

        fn fire_slot(ref self: ContractState, game_id: u32, slot_id: u8) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let mut slot: AgentSlot = world.read_model((game_id, slot_id));
            assert(slot.owner == caller, 'not slot owner');
            assert(slot.status == 1, 'slot not active');

            slot.status = 0; // Inactive
            slot.drug_quantity = 0;
            world.write_model(@slot);

            let mut counter: SlotCounter = world.read_model((game_id, caller));
            if counter.active_count > 0 {
                counter.active_count = counter.active_count - 1;
            }
            world.write_model(@counter);
        }

        fn get_slot_status(self: @ContractState, game_id: u32, slot_id: u8) -> (u8, u32, u16) {
            let world = self.world(ns());
            let slot: AgentSlot = world.read_model((game_id, slot_id));
            (slot.status, slot.earnings_held, slot.drug_quantity)
        }
    }
}
