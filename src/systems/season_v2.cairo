use starknet::ContractAddress;

#[starknet::interface]
pub trait ISeasonSystem<T> {
    fn register_score(ref self: T, game_id: u32);
    fn get_leaderboard(
        self: @T, season_id: u32, count: u8,
    ) -> Array<(ContractAddress, u32)>;
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct LeaderboardEntry {
    #[key]
    pub season_id: u32,
    #[key]
    pub rank: u32,
    pub player: ContractAddress,
    pub score: u32,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct LeaderboardSize {
    #[key]
    pub season_id: u32,
    pub count: u32,
}

#[dojo::contract]
pub mod season_v2 {
    use dojo::model::ModelStorage;
    use starknet::{ContractAddress, get_caller_address};

    use crate::models::cartel_player::CartelPlayer;
    use crate::models::game_config::GameConfig;

    use super::{LeaderboardEntry, LeaderboardSize};

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    // Max leaderboard entries to keep
    const MAX_LEADERBOARD: u32 = 100;

    #[abi(embed_v0)]
    impl SeasonSystemImpl of super::ISeasonSystem<ContractState> {
        fn register_score(ref self: ContractState, game_id: u32) {
            let mut world = self.world(ns());
            let player_id = get_caller_address();

            // Load player and game config
            let player: CartelPlayer = world.read_model((game_id, player_id));
            let game_config: GameConfig = world.read_model(game_id);

            // Player must be finished (status 3)
            assert(player.status == 3, 'game not finished');

            let season_id = game_config.season_id;
            let score = player.score;

            // Load current leaderboard size
            let mut lb_size: LeaderboardSize = world.read_model(season_id);

            // Find insertion point (simple insertion sort - keep sorted descending)
            let mut insert_rank: u32 = lb_size.count;
            let mut i: u32 = 0;
            while i < lb_size.count {
                let entry: LeaderboardEntry = world.read_model((season_id, i));
                if score > entry.score {
                    insert_rank = i;
                    break;
                }
                i += 1;
            };

            // If we're beyond max, skip
            if insert_rank >= MAX_LEADERBOARD {
                return;
            }

            // Shift entries down from the end
            let new_count = if lb_size.count < MAX_LEADERBOARD {
                lb_size.count + 1
            } else {
                MAX_LEADERBOARD
            };

            // Shift down (from end to insert_rank)
            let mut j: u32 = new_count - 1;
            while j > insert_rank {
                let prev: LeaderboardEntry = world.read_model((season_id, j - 1));
                let shifted = LeaderboardEntry {
                    season_id, rank: j, player: prev.player, score: prev.score,
                };
                world.write_model(@shifted);
                if j == 0 {
                    break;
                }
                j -= 1;
            };

            // Insert new entry
            let new_entry = LeaderboardEntry {
                season_id, rank: insert_rank, player: player_id, score,
            };
            world.write_model(@new_entry);

            // Update size
            lb_size.count = new_count;
            world.write_model(@lb_size);
        }

        fn get_leaderboard(
            self: @ContractState, season_id: u32, count: u8,
        ) -> Array<(ContractAddress, u32)> {
            let world = self.world(ns());
            let lb_size: LeaderboardSize = world.read_model(season_id);

            let mut result: Array<(ContractAddress, u32)> = array![];
            let limit: u32 = if count.into() < lb_size.count {
                count.into()
            } else {
                lb_size.count
            };

            let mut i: u32 = 0;
            while i < limit {
                let entry: LeaderboardEntry = world.read_model((season_id, i));
                result.append((entry.player, entry.score));
                i += 1;
            };

            result
        }
    }
}
