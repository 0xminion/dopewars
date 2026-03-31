#[starknet::interface]
pub trait IPassiveTick<T> {
    fn process_tick(ref self: T, game_id: u32, tick_seed: felt252);
}

#[dojo::contract]
pub mod passive_tick {
    use dojo::model::ModelStorage;
    use core::poseidon::PoseidonTrait;
    use core::hash::HashStateTrait;

    use crate::models::agent_slot::{AgentSlot, SlotCounter};
    use crate::models::operation::{Operation, OperationCounter};
    use crate::models::wallet::WalletState;
    use crate::models::cartel_player::CartelPlayer;
    use crate::models::cartel_market::{CartelMarket, get_drug_price_tick};
    use crate::models::heat::{HeatProfile, get_location_heat};
    use crate::config::slot_config::BUST_DURATION_TURNS;
    use crate::systems::helpers::slot_helpers::{calculate_dealer_sales, calculate_bust_risk, apply_commission};
    use crate::systems::helpers::operation_helpers::process_operation_tick;
    use crate::systems::helpers::market_drift::{apply_price_drift, replenish_supply, apply_market_event};
    use crate::types::location_types::LOCATION_COUNT;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl PassiveTickImpl of super::IPassiveTick<ContractState> {

        fn process_tick(ref self: ContractState, game_id: u32, tick_seed: felt252) {
            let mut world = self.world(ns());

            // 1. Process dealer slots
            let slot_counter: SlotCounter = world.read_model(game_id);
            let mut rng = tick_seed;
            let mut i: u8 = 0;
            while i < slot_counter.next_slot_id {
                let mut slot: AgentSlot = world.read_model((game_id, i));
                if slot.status == 1 && slot.drug_quantity > 0 && slot.slot_type == 1 {
                    // Active dealer with product
                    let market: CartelMarket = world.read_model((game_id, slot.location));
                    let price_tick = get_drug_price_tick(market.drug_prices, slot.drug_id - 1);

                    // Calculate sales
                    let (qty_sold, revenue) = calculate_dealer_sales(
                        slot.drug_id, slot.drug_quantity, slot.salesmanship, slot.strategy, price_tick,
                    );
                    let (owner_cut, _dealer_cut) = apply_commission(revenue, 20);

                    slot.drug_quantity = slot.drug_quantity - qty_sold;
                    slot.earnings_held = slot.earnings_held + owner_cut;

                    // Check bust risk
                    rng = PoseidonTrait::new().update(rng).update(i.into()).finalize();
                    let roll: u8 = (Into::<felt252, u256>::into(rng) % 100).try_into().unwrap();
                    let heat: HeatProfile = world.read_model((game_id, slot.owner));
                    let loc_heat = get_location_heat(heat.location_heat, slot.location - 1);

                    if calculate_bust_risk(loc_heat, slot.stealth, slot.strategy, roll) {
                        let player: CartelPlayer = world.read_model((game_id, slot.owner));
                        slot.status = 2; // Busted
                        slot.drug_quantity = 0; // Lose inventory
                        slot.busted_until_turn = player.turn + BUST_DURATION_TURNS;
                    }

                    world.write_model(@slot);
                } else if slot.status == 2 {
                    // Check if bust period is over
                    let player: CartelPlayer = world.read_model((game_id, slot.owner));
                    if player.turn >= slot.busted_until_turn {
                        slot.status = 1; // Reactivate
                        world.write_model(@slot);
                    }
                }
                i += 1;
            };

            // 2. Process operations (laundering)
            let op_counter: OperationCounter = world.read_model(game_id);
            i = 0;
            while i < op_counter.next_op_id {
                let mut op: Operation = world.read_model((game_id, i));
                if op.processing_amount > 0 {
                    let (clean_produced, remaining, new_turns) = process_operation_tick(
                        op.op_type, op.processing_amount, op.processing_turns_left,
                    );
                    op.processing_amount = remaining;
                    op.processing_turns_left = new_turns;
                    op.total_laundered = op.total_laundered + clean_produced;
                    world.write_model(@op);

                    if clean_produced > 0 {
                        // Add clean cash to owner's wallet
                        let mut wallet: WalletState = world.read_model((game_id, op.owner));
                        let max_cash: u32 = 0xFFFFFFFF;
                        if wallet.clean_cash > max_cash - clean_produced {
                            wallet.clean_cash = max_cash;
                        } else {
                            wallet.clean_cash = wallet.clean_cash + clean_produced;
                        }
                        world.write_model(@wallet);
                    }
                }
                i += 1;
            };

            // 3. Market drift + supply replenish
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                let mut market: CartelMarket = world.read_model((game_id, loc));
                rng = PoseidonTrait::new().update(rng).update(loc.into()).update('market').finalize();
                market.drug_prices = apply_price_drift(market.drug_prices, rng);
                market.drug_supply = replenish_supply(market.drug_supply);

                // Random market event (10% chance per location)
                rng = PoseidonTrait::new().update(rng).update('event').finalize();
                let event_roll: u8 = (Into::<felt252, u256>::into(rng) % 100).try_into().unwrap();
                if event_roll < 10 {
                    let event_type: u8 = (Into::<felt252, u256>::into(rng) % 4).try_into().unwrap();
                    let target_drug: u8 = (Into::<felt252, u256>::into(
                        PoseidonTrait::new().update(rng).update('drug').finalize()
                    ) % 8).try_into().unwrap();
                    let (new_prices, new_supply) = apply_market_event(
                        market.drug_prices, market.drug_supply, event_type + 1, target_drug,
                    );
                    market.drug_prices = new_prices;
                    market.drug_supply = new_supply;
                    market.last_event = event_type + 1;
                } else {
                    market.last_event = 0;
                }

                world.write_model(@market);
                loc += 1;
            };
        }
    }
}
