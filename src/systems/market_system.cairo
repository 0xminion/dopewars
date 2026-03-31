#[starknet::interface]
pub trait IMarketSystem<T> {
    fn get_visible_prices(
        self: @T, game_id: u32, player_idx: u8, location_id: u8,
    ) -> (u128, u128);
    fn get_all_visible(
        self: @T, game_id: u32, player_idx: u8,
    ) -> Array<(u8, u128, u128)>;
}

#[dojo::contract]
pub mod market_system {
    use dojo::model::ModelStorage;

    use crate::models::cartel_market::CartelMarket;
    use crate::systems::helpers::market_helpers::is_visible_to_player;
    use crate::types::location_types::LOCATION_COUNT;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl MarketSystemImpl of super::IMarketSystem<ContractState> {
        fn get_visible_prices(
            self: @ContractState, game_id: u32, player_idx: u8, location_id: u8,
        ) -> (u128, u128) {
            let world = self.world(ns());
            let market: CartelMarket = world.read_model((game_id, location_id));

            // Enforce fog-of-war: only return data if visible
            if is_visible_to_player(market.visible_to, player_idx) {
                (market.drug_prices, market.drug_supply)
            } else {
                (0, 0)
            }
        }

        fn get_all_visible(
            self: @ContractState, game_id: u32, player_idx: u8,
        ) -> Array<(u8, u128, u128)> {
            let world = self.world(ns());
            let mut result: Array<(u8, u128, u128)> = array![];

            let mut loc_id: u8 = 1;
            while loc_id <= LOCATION_COUNT {
                let market: CartelMarket = world.read_model((game_id, loc_id));
                if is_visible_to_player(market.visible_to, player_idx) {
                    result.append((loc_id, market.drug_prices, market.drug_supply));
                }
                loc_id += 1;
            };

            result
        }
    }
}
