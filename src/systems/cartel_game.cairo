use crate::types::action_types::Action;

#[starknet::interface]
pub trait ICartelGame<T> {
    fn create_game(ref self: T, mode: u8, player_name: felt252) -> u32;
    fn commit_actions(ref self: T, game_id: u32, action_hash: felt252, ap_spent: u8);
    fn reveal_resolve(ref self: T, game_id: u32, actions: Array<Action>, salt: felt252);
    fn end_game(ref self: T, game_id: u32);
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct GameCounter {
    #[key]
    pub singleton: u8,
    pub next_id: u32,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct ActionCommit {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: starknet::ContractAddress,
    pub action_hash: felt252,
    pub ap_spent: u8,
    pub turn: u16,
}

#[dojo::contract]
pub mod cartel_game {
    use dojo::model::ModelStorage;
    use starknet::{ContractAddress, get_caller_address};
    use core::poseidon::PoseidonTrait;
    use core::hash::HashStateTrait;

    use crate::models::cartel_player::CartelPlayer;
    use crate::models::inventory::{Inventory, pack_drug_slot, unpack_drug_slot};
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::models::heat::{HeatProfile, get_location_heat, set_location_heat};
    use crate::models::cartel_market::{
        CartelMarket, get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply,
    };
    use crate::models::game_config::GameConfig;
    use crate::models::cartel_location::CartelLocation;
    use crate::config::game_modes::get_mode_config;
    use crate::config::drugs_v2::get_drug_config;
    use crate::config::locations_v2::{get_location_config, is_adjacent};
    use crate::config::heat_config::{notoriety_to_tier, TRAVEL_WITH_DRUGS_NOTORIETY};
    use crate::config::ingredients::get_ingredient_config;
    use crate::types::action_types::{Action, ActionType, action_ap_cost};
    use crate::types::drug_types::DRUG_COUNT;
    use crate::types::location_types::LOCATION_COUNT;
    use crate::utils::action_hash::verify_action_hash;
    use crate::systems::helpers::action_executor::validate_action_batch;
    use crate::systems::helpers::market_helpers::{
        calculate_buy_price, calculate_sell_price, set_visible_to_player, drain_supply,
        replenish_supply,
    };
    use crate::systems::helpers::encounter_helpers::{
        should_trigger_encounter, resolve_encounter, calculate_crew_power, calculate_threat,
        get_loss_severity, EncounterOutcome,
    };
    use crate::systems::helpers::mixing_helpers::apply_ingredient;

    use super::{GameCounter, ActionCommit};

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    // Player status constants
    const STATUS_ACTIVE: u8 = 1;
    const STATUS_DEAD: u8 = 2;
    const STATUS_FINISHED: u8 = 3;

    // Safety cap on quantity per action to prevent u32 overflow in wallet arithmetic
    const MAX_QUANTITY_PER_ACTION: u16 = 999;

    #[abi(embed_v0)]
    impl CartelGameImpl of super::ICartelGame<ContractState> {
        fn create_game(ref self: ContractState, mode: u8, player_name: felt252) -> u32 {
            let mut world = self.world(ns());
            let player_id = get_caller_address();

            // Get next game_id from GameCounter
            let mut counter: GameCounter = world.read_model(0_u8);
            let game_id = counter.next_id;
            counter.next_id = game_id + 1;
            world.write_model(@counter);

            // Load mode config
            let mode_cfg = get_mode_config(mode);

            // Write GameConfig
            let game_config = GameConfig {
                game_id,
                mode,
                max_turns: mode_cfg.max_turns,
                ap_per_turn: mode_cfg.ap_per_turn,
                starting_dirty_cash: mode_cfg.starting_dirty_cash,
                starting_clean_cash: mode_cfg.starting_clean_cash,
                heat_decay_rate: mode_cfg.heat_decay_rate,
                max_dealer_slots: mode_cfg.max_dealer_slots,
                season_id: 0,
            };
            world.write_model(@game_config);

            // Write CartelPlayer — start at location 1 (Queens)
            let player = CartelPlayer {
                game_id,
                player_id,
                location: 1,
                ap_remaining: mode_cfg.ap_per_turn,
                turn: 1,
                max_turns: mode_cfg.max_turns,
                status: STATUS_ACTIVE,
                score: 0,
            };
            world.write_model(@player);

            // Write empty Inventory
            let inventory = Inventory {
                game_id, player_id, slot_0: 0, slot_1: 0, slot_2: 0, slot_3: 0,
            };
            world.write_model(@inventory);

            // Write WalletState
            let wallet = WalletState {
                game_id,
                player_id,
                dirty_cash: mode_cfg.starting_dirty_cash,
                clean_cash: mode_cfg.starting_clean_cash,
            };
            world.write_model(@wallet);

            // Write Reputation (all 0)
            let rep = Reputation {
                game_id,
                player_id,
                trader_xp: 0,
                enforcer_xp: 0,
                operator_xp: 0,
                trader_lvl: 0,
                enforcer_lvl: 0,
                operator_lvl: 0,
            };
            world.write_model(@rep);

            // Write HeatProfile (all 0)
            let heat = HeatProfile {
                game_id, player_id, tier: 0, notoriety: 0, location_heat: 0,
            };
            world.write_model(@heat);

            // Initialize markets for all 6 locations
            let mut loc_id: u8 = 1;
            while loc_id <= LOCATION_COUNT {
                let loc_cfg = get_location_config(loc_id);

                // Initialize drug prices (all at tick 32) and supply from drug config
                let mut prices: u128 = 0;
                let mut supply: u128 = 0;
                let mut d: u8 = 0;
                while d < DRUG_COUNT {
                    prices = set_drug_price_tick(prices, d, 32);
                    let drug_cfg = get_drug_config(d + 1);
                    supply = set_drug_supply(supply, d, drug_cfg.initial_supply);
                    d += 1;
                };

                // Set starting location (Queens=1) as visible
                let mut visible: felt252 = 0;
                if loc_id == 1 {
                    visible = set_visible_to_player(0, 0);
                }

                let market = CartelMarket {
                    game_id,
                    location_id: loc_id,
                    drug_prices: prices,
                    drug_supply: supply,
                    last_event: 0,
                    visible_to: visible,
                };
                world.write_model(@market);

                // Write CartelLocation
                let location = CartelLocation {
                    game_id,
                    location_id: loc_id,
                    danger_level: loc_cfg.danger_level,
                    is_adjacent_to: loc_cfg.adjacent_mask,
                };
                world.write_model(@location);

                loc_id += 1;
            };

            game_id
        }

        fn commit_actions(
            ref self: ContractState, game_id: u32, action_hash: felt252, ap_spent: u8,
        ) {
            let mut world = self.world(ns());
            let player_id = get_caller_address();

            // Load player
            let player: CartelPlayer = world.read_model((game_id, player_id));
            assert(player.status == STATUS_ACTIVE, 'player not active');

            // Verify ap_spent <= ap_remaining
            assert(ap_spent <= player.ap_remaining, 'not enough AP');

            // Guard against overwriting an existing commit for this turn (must reveal first)
            let existing_commit: ActionCommit = world.read_model((game_id, player_id));
            assert(
                existing_commit.action_hash == 0 || existing_commit.turn != player.turn,
                'must reveal before re-commit',
            );

            // Store ActionCommit
            let commit = ActionCommit {
                game_id, player_id, action_hash, ap_spent, turn: player.turn,
            };
            world.write_model(@commit);
        }

        fn reveal_resolve(
            ref self: ContractState, game_id: u32, actions: Array<Action>, salt: felt252,
        ) {
            let mut world = self.world(ns());
            let player_id = get_caller_address();

            // Verify commit hash matches
            let commit: ActionCommit = world.read_model((game_id, player_id));
            let actions_span = actions.span();
            assert(
                verify_action_hash(actions_span, salt, commit.action_hash), 'hash mismatch',
            );

            // Load all player state
            let mut player: CartelPlayer = world.read_model((game_id, player_id));
            assert(player.status == STATUS_ACTIVE, 'player not active');
            assert(commit.turn == player.turn, 'wrong turn');

            let game_config: GameConfig = world.read_model(game_id);

            // Validate action batch
            assert(
                validate_action_batch(actions_span, player.location, player.ap_remaining),
                'invalid action batch',
            );

            let mut inventory: Inventory = world.read_model((game_id, player_id));
            let mut wallet: WalletState = world.read_model((game_id, player_id));
            let mut rep: Reputation = world.read_model((game_id, player_id));
            let mut heat: HeatProfile = world.read_model((game_id, player_id));

            // Execute each action sequentially
            let mut i: usize = 0;
            let mut ap_used: u8 = 0;
            while i < actions_span.len() {
                let action = *actions_span.at(i);
                InternalImpl::execute_action(
                    ref world,
                    game_id,
                    player_id,
                    ref player,
                    ref inventory,
                    ref wallet,
                    ref rep,
                    ref heat,
                    @game_config,
                    action,
                    salt,
                    i.try_into().unwrap(),
                    ref ap_used,
                );
                i += 1;
            };

            // After all actions: advance turn, reset AP
            player.turn += 1;
            player.ap_remaining = game_config.ap_per_turn;

            // Decay heat at non-current locations
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                if loc != player.location {
                    let current_heat = get_location_heat(heat.location_heat, loc - 1);
                    if current_heat > game_config.heat_decay_rate {
                        heat
                            .location_heat =
                                set_location_heat(
                                    heat.location_heat,
                                    loc - 1,
                                    current_heat - game_config.heat_decay_rate,
                                );
                    } else if current_heat > 0 {
                        heat.location_heat = set_location_heat(heat.location_heat, loc - 1, 0);
                    }
                }
                loc += 1;
            };

            // Update heat tier
            heat.tier = notoriety_to_tier(heat.notoriety);

            // === Passive tick processing (inline) ===
            PassiveTickImpl::run_passive_tick(
                ref world, game_id, player_id, ref wallet, player.turn, salt,
            );

            // Check if game over
            if player.turn > player.max_turns {
                player.status = STATUS_FINISHED;
                player.score = wallet.clean_cash;
            }

            // Save all state
            world.write_model(@player);
            world.write_model(@inventory);
            world.write_model(@wallet);
            world.write_model(@rep);
            world.write_model(@heat);

            // Clear the commit
            let empty_commit = ActionCommit {
                game_id, player_id, action_hash: 0, ap_spent: 0, turn: 0,
            };
            world.write_model(@empty_commit);
        }

        fn end_game(ref self: ContractState, game_id: u32) {
            let mut world = self.world(ns());
            let player_id = get_caller_address();

            let mut player: CartelPlayer = world.read_model((game_id, player_id));
            let wallet: WalletState = world.read_model((game_id, player_id));

            // Verify game over (turn > max_turns or player dead)
            assert(
                player.turn > player.max_turns || player.status == STATUS_DEAD,
                'game not over',
            );

            player.status = STATUS_FINISHED;
            player.score = wallet.clean_cash;
            world.write_model(@player);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn execute_action(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            player_id: ContractAddress,
            ref player: CartelPlayer,
            ref inventory: Inventory,
            ref wallet: WalletState,
            ref rep: Reputation,
            ref heat: HeatProfile,
            game_config: @GameConfig,
            action: Action,
            salt: felt252,
            action_idx: u8,
            ref ap_used: u8,
        ) {
            // Determine is_distant for Travel; default false for all other action types
            let destination = action.target_location;
            let is_distant = match action.action_type {
                ActionType::Travel => {
                    // Validate destination range
                    assert(destination >= 1 && destination <= LOCATION_COUNT, 'invalid destination');
                    // Cannot travel to current location
                    assert(destination != player.location, 'already at destination');
                    !is_adjacent(player.location, destination)
                },
                _ => false,
            };
            let cost = action_ap_cost(action.action_type, is_distant);

            match action.action_type {
                ActionType::None => {},
                ActionType::Travel => {
                    Self::execute_travel(
                        ref world,
                        game_id,
                        player_id,
                        ref player,
                        ref inventory,
                        ref wallet,
                        ref heat,
                        ref rep,
                        destination,
                        salt,
                        action_idx,
                    );
                },
                ActionType::Buy => {
                    Self::execute_buy(
                        ref world,
                        game_id,
                        ref player,
                        ref inventory,
                        ref wallet,
                        action.drug_id,
                        action.quantity,
                        action.slot_index,
                    );
                },
                ActionType::Sell => {
                    Self::execute_sell(
                        ref world,
                        game_id,
                        ref player,
                        ref inventory,
                        ref wallet,
                        action.slot_index,
                        action.quantity,
                    );
                },
                ActionType::Mix => {
                    Self::execute_mix(
                        ref inventory, ref wallet, action.slot_index, action.ingredient_id,
                    );
                },
                ActionType::Scout => {
                    Self::execute_scout(ref world, game_id, action.target_location);
                },
                ActionType::Rest => {
                    Self::execute_rest(ref heat);
                },
                ActionType::Manage => {
                    PassiveTickImpl::execute_manage(
                        ref world, game_id, player_id, action.slot_index, action.drug_id,
                    );
                },
                ActionType::Invest => {
                    PassiveTickImpl::execute_invest(
                        ref world, game_id, player_id, ref wallet, action.slot_index,
                        action.quantity,
                    );
                },
            };

            ap_used += cost;
        }

        fn execute_travel(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            player_id: ContractAddress,
            ref player: CartelPlayer,
            ref inventory: Inventory,
            ref wallet: WalletState,
            ref heat: HeatProfile,
            ref rep: Reputation,
            destination: u8,
            salt: felt252,
            action_idx: u8,
        ) {
            // Update location
            player.location = destination;

            // Mark destination as visible
            let mut market: CartelMarket = world.read_model((game_id, destination));
            market.visible_to = set_visible_to_player(market.visible_to, 0);
            world.write_model(@market);

            // Add notoriety if carrying drugs
            let has_drugs = Self::has_any_drugs(@inventory);
            if has_drugs {
                heat.notoriety += TRAVEL_WITH_DRUGS_NOTORIETY;
                heat.tier = notoriety_to_tier(heat.notoriety);
            }

            // Check encounter
            let loc_cfg = get_location_config(destination);
            // Generate random roll from salt via Poseidon hashing
            let mut state = PoseidonTrait::new();
            state = state.update(salt);
            state = state.update(action_idx.into());
            state = state.update('encounter');
            let hash = state.finalize();
            let hash_u256: u256 = hash.into();
            let roll: u8 = (hash_u256 % 100).try_into().unwrap();

            if should_trigger_encounter(heat.tier, loc_cfg.danger_level, roll) {
                // Generate threat roll
                let mut state2 = PoseidonTrait::new();
                state2 = state2.update(salt);
                state2 = state2.update(action_idx.into());
                state2 = state2.update('threat');
                let hash2 = state2.finalize();
                let hash2_u256: u256 = hash2.into();
                let threat_roll: u8 = (hash2_u256 % 100).try_into().unwrap();

                let crew_power = calculate_crew_power(rep.enforcer_lvl, 0);
                let threat = calculate_threat(heat.tier, loc_cfg.danger_level, threat_roll);
                let outcome = resolve_encounter(crew_power, threat);

                match outcome {
                    EncounterOutcome::Win => {
                        // Win encounter — gain enforcer XP
                        rep.enforcer_xp += 10;
                    },
                    EncounterOutcome::Lose => {
                        // Apply losses
                        let loss = get_loss_severity(heat.tier);
                        let cash_loss = wallet.dirty_cash * loss.cash_percent.into() / 100;
                        if wallet.dirty_cash > cash_loss {
                            wallet.dirty_cash -= cash_loss;
                        } else {
                            wallet.dirty_cash = 0;
                        }
                        heat.notoriety += loss.notoriety_gain;
                        heat.tier = notoriety_to_tier(heat.notoriety);

                        // Lose some drugs from inventory (simplified: reduce quantities)
                        Self::apply_drug_loss(ref inventory, loss.drug_percent);
                    },
                };
            }
        }

        fn execute_buy(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            ref player: CartelPlayer,
            ref inventory: Inventory,
            ref wallet: WalletState,
            drug_id: u8,
            quantity: u16,
            slot_index: u8,
        ) {
            // Cap quantity to prevent overflow in price multiplication
            assert(quantity <= MAX_QUANTITY_PER_ACTION, 'quantity too large');

            let location = player.location;
            let mut market: CartelMarket = world.read_model((game_id, location));

            // drug_idx is drug_id - 1 (drug_id starts at 1)
            let drug_idx: u8 = drug_id - 1;
            let tick = get_drug_price_tick(market.drug_prices, drug_idx);
            let price = calculate_buy_price(drug_id, tick);
            let total_cost: u32 = price * quantity.into();

            // Check cash
            assert(wallet.dirty_cash >= total_cost, 'not enough cash');

            // Deduct cash
            wallet.dirty_cash -= total_cost;

            // Drain supply
            let current_supply = get_drug_supply(market.drug_supply, drug_idx);
            assert(current_supply >= quantity, 'not enough supply');
            market.drug_supply = set_drug_supply(market.drug_supply, drug_idx, drain_supply(current_supply, quantity));

            // Find/allocate inventory slot
            let current_slot = Self::get_slot(@inventory, slot_index);
            let (existing_drug, existing_qty, existing_quality, existing_effects) =
                unpack_drug_slot(current_slot);

            if existing_drug == 0 {
                // Empty slot — allocate
                let new_packed = pack_drug_slot(drug_id, quantity, 50, 0);
                Self::set_slot(ref inventory, slot_index, new_packed);
            } else {
                // Same drug — add quantity
                assert(existing_drug == drug_id, 'slot has different drug');
                let new_packed = pack_drug_slot(
                    existing_drug, existing_qty + quantity, existing_quality, existing_effects,
                );
                Self::set_slot(ref inventory, slot_index, new_packed);
            }

            // Save market
            world.write_model(@market);
        }

        fn execute_sell(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            ref player: CartelPlayer,
            ref inventory: Inventory,
            ref wallet: WalletState,
            slot_index: u8,
            quantity: u16,
        ) {
            // Cap quantity to prevent overflow in earnings multiplication
            assert(quantity <= MAX_QUANTITY_PER_ACTION, 'quantity too large');

            let location = player.location;
            let mut market: CartelMarket = world.read_model((game_id, location));

            let current_slot = Self::get_slot(@inventory, slot_index);
            let (drug_id, existing_qty, quality, effects) = unpack_drug_slot(current_slot);
            assert(drug_id != 0, 'empty slot');
            assert(existing_qty >= quantity, 'not enough quantity');

            let drug_idx: u8 = drug_id - 1;
            let tick = get_drug_price_tick(market.drug_prices, drug_idx);
            let sell_price = calculate_sell_price(drug_id, tick, effects);
            let earnings: u32 = sell_price * quantity.into();

            // Safe addition — saturate at u32::MAX to prevent overflow
            if wallet.dirty_cash > 0xFFFFFFFF_u32 - earnings {
                wallet.dirty_cash = 0xFFFFFFFF_u32;
            } else {
                wallet.dirty_cash += earnings;
            }

            // Update inventory
            let remaining = existing_qty - quantity;
            if remaining == 0 {
                Self::set_slot(ref inventory, slot_index, 0);
            } else {
                let new_packed = pack_drug_slot(drug_id, remaining, quality, effects);
                Self::set_slot(ref inventory, slot_index, new_packed);
            }

            // Replenish supply
            let current_supply = get_drug_supply(market.drug_supply, drug_idx);
            let drug_cfg = get_drug_config(drug_id);
            market
                .drug_supply =
                    set_drug_supply(
                        market.drug_supply,
                        drug_idx,
                        replenish_supply(current_supply, quantity, drug_cfg.initial_supply),
                    );

            world.write_model(@market);
        }

        fn execute_mix(
            ref inventory: Inventory,
            ref wallet: WalletState,
            slot_index: u8,
            ingredient_id: u8,
        ) {
            let current_slot = Self::get_slot(@inventory, slot_index);
            let (drug_id, qty, quality, effects) = unpack_drug_slot(current_slot);
            assert(drug_id != 0, 'empty slot');

            // Get ingredient config and deduct cost
            let ingr_cfg = get_ingredient_config(ingredient_id);
            let cost: u32 = ingr_cfg.cost.into();
            assert(wallet.dirty_cash >= cost, 'not enough cash for mix');
            wallet.dirty_cash -= cost;

            // Apply ingredient to effects
            let new_effects = apply_ingredient(effects, ingredient_id);
            let new_packed = pack_drug_slot(drug_id, qty, quality, new_effects);
            Self::set_slot(ref inventory, slot_index, new_packed);
        }

        fn execute_scout(
            ref world: dojo::world::WorldStorage, game_id: u32, target_location: u8,
        ) {
            // Mark target location as visible
            let mut market: CartelMarket = world.read_model((game_id, target_location));
            market.visible_to = set_visible_to_player(market.visible_to, 0);
            world.write_model(@market);
        }

        fn execute_rest(ref heat: HeatProfile) {
            // Reduce notoriety to drop below current tier threshold
            if heat.notoriety > 10 {
                heat.notoriety -= 10;
            } else {
                heat.notoriety = 0;
            }
            heat.tier = notoriety_to_tier(heat.notoriety);
        }

        fn has_any_drugs(inventory: @Inventory) -> bool {
            let (d0, _, _, _) = unpack_drug_slot(*inventory.slot_0);
            let (d1, _, _, _) = unpack_drug_slot(*inventory.slot_1);
            let (d2, _, _, _) = unpack_drug_slot(*inventory.slot_2);
            let (d3, _, _, _) = unpack_drug_slot(*inventory.slot_3);
            d0 != 0 || d1 != 0 || d2 != 0 || d3 != 0
        }

        fn get_slot(inventory: @Inventory, index: u8) -> u64 {
            if index == 0 {
                *inventory.slot_0
            } else if index == 1 {
                *inventory.slot_1
            } else if index == 2 {
                *inventory.slot_2
            } else {
                *inventory.slot_3
            }
        }

        fn set_slot(ref inventory: Inventory, index: u8, value: u64) {
            if index == 0 {
                inventory.slot_0 = value;
            } else if index == 1 {
                inventory.slot_1 = value;
            } else if index == 2 {
                inventory.slot_2 = value;
            } else {
                inventory.slot_3 = value;
            }
        }

        fn apply_drug_loss(ref inventory: Inventory, percent: u8) {
            let mut i: u8 = 0;
            while i < 4 {
                let slot = Self::get_slot(@inventory, i);
                let (drug_id, qty, quality, effects) = unpack_drug_slot(slot);
                if drug_id != 0 && qty > 0 {
                    let loss: u16 = qty * percent.into() / 100;
                    let remaining = if loss >= qty {
                        0_u16
                    } else {
                        qty - loss
                    };
                    if remaining == 0 {
                        Self::set_slot(ref inventory, i, 0);
                    } else {
                        Self::set_slot(
                            ref inventory,
                            i,
                            pack_drug_slot(drug_id, remaining, quality, effects),
                        );
                    }
                }
                i += 1;
            };
        }

        // Manage action: set dealer strategy (slot_index = slot_id, drug_id = strategy)
        fn execute_manage(
            ref world: dojo::world::WorldStorage,
            _game_id: u32,
            _player_id: ContractAddress,
            _slot_index: u8,
            _strategy: u8,
        ) {
            // TODO: full implementation once Dojo model cross-import issue resolved
        }

        // Invest action: start laundering on an operation
        fn execute_invest(
            ref world: dojo::world::WorldStorage,
            _game_id: u32,
            _player_id: ContractAddress,
            ref _wallet: WalletState,
            _op_id: u8,
            _amount_u16: u16,
        ) {
            // TODO: full implementation once Dojo model cross-import issue resolved
        }

    }

    #[generate_trait]
    impl PassiveTickImpl of PassiveTickTrait {
        fn execute_manage(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            player_id: ContractAddress,
            slot_index: u8,
            strategy: u8,
        ) {
            let mut slot: crate::models::agent_slot::AgentSlot = world
                .read_model((game_id, slot_index));
            assert(slot.owner == player_id, 'not slot owner');
            assert(strategy <= 2, 'invalid strategy');
            slot.strategy = strategy;
            world.write_model(@slot);
        }

        fn execute_invest(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            player_id: ContractAddress,
            ref wallet: WalletState,
            op_id: u8,
            amount_u16: u16,
        ) {
            let mut operation: crate::models::operation::Operation = world
                .read_model((game_id, op_id));
            assert(operation.owner == player_id, 'not op owner');
            assert(operation.processing_amount == 0, 'already processing');

            let amount: u32 = amount_u16.into() * 10;
            let capacity: u32 = operation.capacity_per_turn.into();
            let queue_amount = if amount > capacity { capacity } else { amount };
            assert(wallet.dirty_cash >= queue_amount, 'not enough dirty cash');

            wallet.dirty_cash = wallet.dirty_cash - queue_amount;

            let config = crate::config::operation_config::get_op_config(operation.op_type);
            operation.processing_amount = queue_amount;
            operation.processing_turns_left = config.processing_turns;
            world.write_model(@operation);
        }

        fn run_passive_tick(
            ref world: dojo::world::WorldStorage,
            game_id: u32,
            player_id: ContractAddress,
            ref wallet: WalletState,
            current_turn: u16,
            salt: felt252,
        ) {
            // 1. Process active dealer slots (sales + bust check)
            let slot_counter: crate::models::agent_slot::SlotCounter = world.read_model(game_id);
            let mut rng = salt;
            let mut i: u8 = 0;
            while i < slot_counter.next_slot_id {
                let mut slot: crate::models::agent_slot::AgentSlot = world
                    .read_model((game_id, i));
                if slot.owner == player_id {
                    if slot.status == 1 && slot.drug_quantity > 0 && slot.slot_type == 1 {
                        let market: CartelMarket = world.read_model((game_id, slot.location));
                        let price_tick = get_drug_price_tick(
                            market.drug_prices, slot.drug_id - 1,
                        );

                        let (qty_sold, revenue) =
                            crate::systems::helpers::slot_helpers::calculate_dealer_sales(
                            slot.drug_id,
                            slot.drug_quantity,
                            slot.salesmanship,
                            slot.strategy,
                            price_tick,
                        );
                        let (owner_cut, _dealer_cut) =
                            crate::systems::helpers::slot_helpers::apply_commission(revenue, 20);

                        slot.drug_quantity = slot.drug_quantity - qty_sold;
                        slot.earnings_held = slot.earnings_held + owner_cut;

                        // Bust risk check
                        rng = PoseidonTrait::new().update(rng).update(i.into()).finalize();
                        let roll: u8 = (Into::<felt252, u256>::into(rng) % 100)
                            .try_into()
                            .unwrap();
                        let heat: HeatProfile = world.read_model((game_id, player_id));
                        let loc_heat = get_location_heat(heat.location_heat, slot.location - 1);

                        if crate::systems::helpers::slot_helpers::calculate_bust_risk(
                            loc_heat, slot.stealth, slot.strategy, roll,
                        ) {
                            slot.status = 2; // Busted
                            slot.drug_quantity = 0;
                            slot.busted_until_turn = current_turn
                                + crate::config::slot_config::BUST_DURATION_TURNS;
                        }

                        world.write_model(@slot);
                    } else if slot.status == 2 && current_turn >= slot.busted_until_turn {
                        slot.status = 1; // Reactivate
                        world.write_model(@slot);
                    }
                }
                i += 1;
            };

            // 2. Process operations (laundering tick)
            let op_counter: crate::models::operation::OperationCounter = world
                .read_model(game_id);
            i = 0;
            while i < op_counter.next_op_id {
                let mut op: crate::models::operation::Operation = world
                    .read_model((game_id, i));
                if op.owner == player_id && op.processing_amount > 0 {
                    let (clean_produced, remaining, new_turns) =
                        crate::systems::helpers::operation_helpers::process_operation_tick(
                        op.op_type, op.processing_amount, op.processing_turns_left,
                    );
                    op.processing_amount = remaining;
                    op.processing_turns_left = new_turns;
                    op.total_laundered = op.total_laundered + clean_produced;
                    world.write_model(@op);

                    if clean_produced > 0 {
                        let max_cash: u32 = 0xFFFFFFFF;
                        if wallet.clean_cash > max_cash - clean_produced {
                            wallet.clean_cash = max_cash;
                        } else {
                            wallet.clean_cash = wallet.clean_cash + clean_produced;
                        }
                    }
                }
                i += 1;
            };

            // 3. Apply market drift to all locations
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                let mut market: CartelMarket = world.read_model((game_id, loc));
                rng = PoseidonTrait::new()
                    .update(rng)
                    .update(loc.into())
                    .update('market')
                    .finalize();
                market.drug_prices = crate::systems::helpers::market_drift::apply_price_drift(
                    market.drug_prices, rng,
                );
                market.drug_supply = crate::systems::helpers::market_drift::replenish_supply(
                    market.drug_supply,
                );

                // Random market event (10% chance per location)
                rng = PoseidonTrait::new().update(rng).update('event').finalize();
                let event_roll: u8 = (Into::<felt252, u256>::into(rng) % 100)
                    .try_into()
                    .unwrap();
                if event_roll < 10 {
                    let event_type: u8 = (Into::<felt252, u256>::into(rng) % 4)
                        .try_into()
                        .unwrap();
                    let target_drug: u8 = (Into::<felt252, u256>::into(
                        PoseidonTrait::new().update(rng).update('drug').finalize(),
                    ) % 8)
                        .try_into()
                        .unwrap();
                    let (new_prices, new_supply) =
                        crate::systems::helpers::market_drift::apply_market_event(
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
