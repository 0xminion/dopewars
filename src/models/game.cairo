use dojo::world::{WorldStorage};

// use dope_types::dope_hustlers::{HustlerSlots};  // commented out for cartel-game-stage1
// use dope_types::dope_hustlers::{HustlerStoreImpl, HustlerStoreTrait};  // commented out for cartel-game-stage1
// use dope_types::dope_loot::{LootStoreImpl, LootStoreTrait};  // commented out for cartel-game-stage1

use rollyourown::store::StoreImpl;
use rollyourown::{utils::{bytes16::{Bytes16, Bytes16Impl}}};
use starknet::ContractAddress;

pub type GearId = felt252;

#[derive(Copy, Drop, Serde, PartialEq, Introspect, DojoStore, Default)]
pub enum TokenId {
    #[default]
    GuestLootId: felt252,
    LootId: felt252,
    HustlerId: felt252,
}


#[derive(Copy, Drop, Serde, PartialEq, IntrospectPacked, DojoStore, Default)]
pub enum GameMode {
    #[default]
    Ranked,
    Noob,
    Warrior,
}

// IntrospectPacked : doesnt supports array
#[derive(Introspect, Copy, Drop, Serde, DojoStore)]
#[dojo::model]
pub struct Game {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    //
    pub season_version: u16,
    pub game_mode: GameMode,
    //
    pub player_name: Bytes16,
    pub multiplier: u8,
    //
    pub game_over: bool,
    pub final_score: u32,
    pub registered: bool,
    pub claimed: bool,
    pub claimable: u32,
    pub position: u16,
    //
    pub token_id: TokenId,
    // sorted by slot order 0,1,2,3
    pub equipment_by_slot: Span<GearId>,
}

#[generate_trait]
pub impl GameImpl of GameTrait {
    fn new(
        dope_world: WorldStorage,
        game_id: u32,
        player_id: ContractAddress,
        season_version: u16,
        game_mode: GameMode,
        player_name: felt252,
        multiplier: u8,
        token_id: TokenId,
    ) -> Game {
        // commented out for cartel-game-stage1: dope_types not available
        // equipment_by_slot was populated from dope_types loot/hustler stores
        let equipment_by_slot: Span<GearId> = array![].span();
        Game {
            game_id,
            player_id,
            //
            season_version,
            game_mode,
            //
            player_name: Bytes16Impl::from(player_name),
            multiplier,
            //
            game_over: false,
            final_score: 0,
            registered: false,
            claimed: false,
            claimable: 0,
            position: 0,
            //
            token_id,
            equipment_by_slot,
        }
    }

    fn exists(self: Game) -> bool {
        self.season_version > 0
    }

    fn is_ranked(self: Game) -> bool {
        self.game_mode == GameMode::Ranked
    }
}


#[generate_trait]
pub impl GearIdImpl of GearIdTrait {
    fn item_id(self: @GearId) -> u8 {
        let value: u256 = (*self).into();
        (value & 0xff).try_into().unwrap()
    }
    fn slot_id(self: @GearId) -> u8 {
        let value: u256 = (*self).into();
        (value & 0xff00).try_into().unwrap()
    }
}
