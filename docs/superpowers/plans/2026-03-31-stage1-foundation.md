# Stage 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable cartel empire game on Starknet with multi-drug inventory, fog of war, action points, auto-resolve encounters, mixing, and simultaneous human + agent play.

**Architecture:** Clean room Dojo world with new ECS models. Commit-reveal action system with Cartridge VRF. Next.js frontend reusing existing shell. All systems are separate Dojo contracts, independently upgradable.

**Tech Stack:** Cairo 2.12.2, Dojo 1.7.1, Starknet, Cartridge VRF, Next.js 16, React 19, Chakra UI v2, MobX, Torii GraphQL, TypeScript.

**Spec:** `docs/superpowers/specs/2026-03-31-cartel-game-revamp-design.md`

---

## File Structure

### New Cairo Files (src/)

```
src/
├── lib.cairo                          # MODIFY — register new modules
├── constants.cairo                    # MODIFY — add new namespace "cartel_v0"
├── store.cairo                        # MODIFY — add new model read/write methods
│
├── models/
│   ├── player.cairo                   # CREATE — Player model
│   ├── inventory.cairo                # CREATE — Inventory model (4 drug slots)
│   ├── wallet.cairo                   # CREATE — WalletState model (dirty/clean cash)
│   ├── reputation.cairo               # CREATE — Reputation model (3 branches)
│   ├── heat.cairo                     # CREATE — HeatProfile model (tier + location heat)
│   ├── market.cairo                   # CREATE — Market model (per location, fog of war)
│   ├── location.cairo                 # CREATE — LocationState model
│   ├── game_config.cairo              # CREATE — GameConfig model (mode settings)
│   ├── season.cairo                   # MODIFY — extend for new modes
│
├── config/
│   ├── drugs_v2.cairo                 # CREATE — 8 drug types with pricing
│   ├── locations_v2.cairo             # CREATE — 6 NYC locations with properties
│   ├── ingredients.cairo              # CREATE — 8 mixing ingredients + effects
│   ├── game_modes.cairo               # CREATE — Casual/Ranked mode configs
│   ├── heat_config.cairo              # CREATE — Heat tier thresholds + encounter rates
│
├── systems/
│   ├── cartel_game.cairo              # CREATE — Main game contract (create, end, commit, reveal)
│   ├── market_system.cairo            # CREATE — Market engine (pricing, fog, supply/demand)
│   ├── encounter_system.cairo         # CREATE — Auto-resolve encounters
│   ├── mixing_system.cairo            # CREATE — Modifier stacking mixing
│   ├── season_v2.cairo                # CREATE — Leaderboard + season management
│   ├── helpers/
│   │   ├── action_executor.cairo      # CREATE — Executes action batches
│   │   ├── market_helpers.cairo       # CREATE — Price calculation, supply drain
│   │   ├── encounter_helpers.cairo    # CREATE — Crew power vs threat resolution
│   │   ├── mixing_helpers.cairo       # CREATE — Effect stacking + price calc
│
├── utils/
│   ├── random.cairo                   # REUSE — existing VRF random
│   ├── math.cairo                     # REUSE — existing capped math
│   ├── bits.cairo                     # REUSE — existing bit manipulation
│   ├── action_hash.cairo              # CREATE — Commit-reveal hash utilities
│
├── types/
│   ├── drug_types.cairo               # CREATE — Drug enum + DrugSlot struct
│   ├── action_types.cairo             # CREATE — Action enum + ActionBatch
│   ├── location_types.cairo           # CREATE — Location enum
│   ├── effect_types.cairo             # CREATE — Effect enum + multipliers
│   ├── game_types.cairo               # CREATE — GameMode, GameStatus enums
│   ├── heat_types.cairo               # CREATE — HeatTier enum
│
├── tests/
│   ├── test_player.cairo              # CREATE
│   ├── test_inventory.cairo           # CREATE
│   ├── test_market.cairo              # CREATE
│   ├── test_actions.cairo             # CREATE
│   ├── test_encounters.cairo          # CREATE
│   ├── test_mixing.cairo              # CREATE
│   ├── test_heat.cairo                # CREATE
│   ├── test_game_lifecycle.cairo      # CREATE
```

### New Frontend Files (web/src/)

```
web/src/
├── dojo/
│   ├── class/
│   │   ├── CartelGame.ts              # CREATE — Game state class
│   │   ├── CartelPlayer.ts            # CREATE — Player state class
│   │   ├── CartelInventory.ts         # CREATE — Inventory management
│   │   ├── CartelMarket.ts            # CREATE — Market data + fog
│   │   ├── CartelHeat.ts              # CREATE — Heat profile
│   │   ├── CartelReputation.ts        # CREATE — Reputation branches
│   │
│   ├── hooks/
│   │   ├── useCartelSystems.ts        # CREATE — Contract call wrappers
│   │   ├── useCartelGame.ts           # CREATE — Game state hook
│   │   ├── useCartelMarket.ts         # CREATE — Market data hook
│   │
│   ├── stores/
│   │   ├── cartelGame.tsx             # CREATE — MobX game store
│
├── pages/
│   ├── cartel/
│   │   ├── index.tsx                  # CREATE — Game lobby / create game
│   │   ├── [gameId]/
│   │   │   ├── index.tsx              # CREATE — Main game view
│   │   │   ├── travel.tsx             # CREATE — Location map + travel
│   │   │   ├── trade.tsx              # CREATE — Buy/sell drugs
│   │   │   ├── mix.tsx                # CREATE — Mixing station
│   │   │   ├── inventory.tsx          # CREATE — Inventory management
│   │   │   ├── end.tsx                # CREATE — Game over + score
│
├── components/
│   ├── cartel/
│   │   ├── ActionBar.tsx              # CREATE — AP tracker + action buttons
│   │   ├── LocationMap.tsx            # CREATE — NYC map with fog
│   │   ├── DrugSlot.tsx               # CREATE — Single drug inventory slot
│   │   ├── InventoryPanel.tsx         # CREATE — 4-slot inventory display
│   │   ├── MarketTable.tsx            # CREATE — Buy/sell price table
│   │   ├── MixingStation.tsx          # CREATE — Ingredient + product mixer
│   │   ├── HeatMeter.tsx              # CREATE — Heat tier display
│   │   ├── ReputationTree.tsx         # CREATE — 3-branch reputation display
│   │   ├── TurnInfo.tsx               # CREATE — Turn counter + game info
│   │   ├── EncounterResult.tsx        # CREATE — Auto-resolve outcome display
│   │   ├── Leaderboard.tsx            # CREATE — Score rankings
│   │   ├── GameLobby.tsx              # CREATE — Create/join game
```

### Configuration Files

```
├── dojo_cartel_dev.toml               # CREATE — New Dojo world config
├── torii_cartel_dev.toml              # CREATE — New Torii config
├── katana_cartel_dev.toml             # CREATE — New Katana config
```

---

## Task 1: Dojo World Setup + Namespace

**Files:**
- Modify: `src/constants.cairo`
- Modify: `src/lib.cairo`
- Create: `dojo_cartel_dev.toml`
- Create: `torii_cartel_dev.toml`
- Create: `katana_cartel_dev.toml`

- [ ] **Step 1: Create Dojo dev config for new cartel world**

Create `dojo_cartel_dev.toml`:

```toml
[world]
name = "cartel"
description = "Drug Cartel Empire Game"
seed = "cartel"

[namespace]
default = "cartel_v0"
mappings = {}

[env]
rpc_url = "http://localhost:5050"
account_address = "0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec"
private_key = "0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912"
world_address = ""

[migration]
skip_contracts = []
```

- [ ] **Step 2: Create Katana config**

Create `katana_cartel_dev.toml`:

```toml
[server]
port = 5050

[starknet]
seed = "cartel"

[dev]
no_fee = true
```

- [ ] **Step 3: Create Torii config**

Create `torii_cartel_dev.toml`:

```toml
[indexing]
world_address = ""
rpc = "http://localhost:5050"

[server]
http_addr = "0.0.0.0:8080"
```

- [ ] **Step 4: Add cartel namespace to constants**

In `src/constants.cairo`, add:

```cairo
pub fn ns() -> @ByteArray {
    @"cartel_v0"
}
```

Keep the existing `dopewars_v0` namespace function — the old game still works. If the existing `ns()` function name conflicts, name the new one `cartel_ns()`.

- [ ] **Step 5: Register new module structure in lib.cairo**

Add to `src/lib.cairo`:

```cairo
// Cartel types
pub mod types {
    pub mod drug_types;
    pub mod action_types;
    pub mod location_types;
    pub mod effect_types;
    pub mod game_types;
    pub mod heat_types;
}
```

Don't register systems or models yet — we'll add those as we create them in subsequent tasks.

- [ ] **Step 6: Verify build compiles**

Run: `scarb build`
Expected: Build succeeds (types modules are empty stubs for now, but lib.cairo parses)

- [ ] **Step 7: Commit**

```bash
git add dojo_cartel_dev.toml torii_cartel_dev.toml katana_cartel_dev.toml src/constants.cairo src/lib.cairo
git commit -m "feat: scaffold cartel world with new Dojo config and namespace"
```

---

## Task 2: Core Type Definitions

**Files:**
- Create: `src/types/drug_types.cairo`
- Create: `src/types/location_types.cairo`
- Create: `src/types/effect_types.cairo`
- Create: `src/types/game_types.cairo`
- Create: `src/types/heat_types.cairo`
- Create: `src/types/action_types.cairo`

- [ ] **Step 1: Create drug types**

Create `src/types/drug_types.cairo`:

```cairo
use core::num::traits::Zero;

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum DrugId {
    #[default]
    None,
    Weed,
    Shrooms,
    Acid,
    Ecstasy,
    Speed,
    Heroin,
    Meth,
    Cocaine,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub struct DrugSlot {
    pub drug_id: u8,
    pub quantity: u16,
    pub quality: u8,
    pub effects: u32, // packed 4 effects × 8-bit IDs
}

impl DrugSlotZeroable of Zero<DrugSlot> {
    fn zero() -> DrugSlot {
        DrugSlot { drug_id: 0, quantity: 0, quality: 0, effects: 0 }
    }
    fn is_zero(self: @DrugSlot) -> bool {
        *self.drug_id == 0 && *self.quantity == 0
    }
    fn is_non_zero(self: @DrugSlot) -> bool {
        *self.drug_id != 0 || *self.quantity != 0
    }
}

pub const DRUG_COUNT: u8 = 8;
pub const MAX_INVENTORY_SLOTS: u8 = 4;
pub const MAX_EFFECTS_PER_DRUG: u8 = 4;
```

- [ ] **Step 2: Create location types**

Create `src/types/location_types.cairo`:

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum LocationId {
    #[default]
    Home,
    Queens,
    Bronx,
    Brooklyn,
    JerseyCity,
    CentralPark,
    ConeyIsland,
}

pub const LOCATION_COUNT: u8 = 6; // excludes Home
```

- [ ] **Step 3: Create effect types**

Create `src/types/effect_types.cairo`:

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum EffectId {
    #[default]
    None,
    Cut,        // +0.05
    Energizing, // +0.22
    Potent,     // +0.30
    Bulking,    // +0.10
    Healthy,    // +0.15
    Toxic,      // +0.35
    Speedy,     // +0.40
    Electric,   // +0.50
}

pub const EFFECT_COUNT: u8 = 8;

// Multipliers stored as basis points (100 = 1.00x, 105 = 1.05x)
// To get sell price: base_price * (100 + sum_of_multipliers) / 100
pub fn effect_multiplier_bps(effect_id: u8) -> u16 {
    match effect_id {
        0 => 0,   // None
        1 => 5,   // Cut: +5%
        2 => 22,  // Energizing: +22%
        3 => 30,  // Potent: +30%
        4 => 10,  // Bulking: +10%
        5 => 15,  // Healthy: +15%
        6 => 35,  // Toxic: +35%
        7 => 40,  // Speedy: +40%
        8 => 50,  // Electric: +50%
        _ => 0,
    }
}
```

- [ ] **Step 4: Create game types**

Create `src/types/game_types.cairo`:

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum GameMode {
    #[default]
    Casual,
    Ranked,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum GameStatus {
    #[default]
    NotStarted,
    InProgress,
    Finished,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum PlayerStatus {
    #[default]
    Normal,
    Jailed,
    Hospitalized,
    Dead,
}
```

- [ ] **Step 5: Create heat types**

Create `src/types/heat_types.cairo`:

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum HeatTier {
    #[default]
    None,        // 0% encounter rate
    Surveillance, // 5% per action
    Wanted,       // 20% per action
    DeadOrAlive,  // 40% per action
}

pub fn encounter_rate_pct(tier: HeatTier) -> u8 {
    match tier {
        HeatTier::None => 0,
        HeatTier::Surveillance => 5,
        HeatTier::Wanted => 20,
        HeatTier::DeadOrAlive => 40,
    }
}

pub fn heat_tier_multiplier(tier: HeatTier) -> u8 {
    match tier {
        HeatTier::None => 0,
        HeatTier::Surveillance => 1,
        HeatTier::Wanted => 3,
        HeatTier::DeadOrAlive => 6,
    }
}
```

- [ ] **Step 6: Create action types**

Create `src/types/action_types.cairo`:

```cairo
use super::drug_types::DrugSlot;

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum ActionType {
    #[default]
    None,
    Travel,   // 1-2 AP
    Buy,      // 1 AP
    Sell,     // 1 AP
    Mix,      // 2 AP
    Scout,    // 1 AP
    Manage,   // 1 AP — placeholder for Stage 2
    Invest,   // 1 AP — placeholder for Stage 2
    Rest,     // 2 AP
}

#[derive(Copy, Drop, Serde, Introspect)]
pub struct Action {
    pub action_type: ActionType,
    pub target_location: u8,   // for Travel/Scout
    pub drug_id: u8,           // for Buy/Sell
    pub quantity: u16,         // for Buy/Sell
    pub ingredient_id: u8,     // for Mix
    pub slot_index: u8,        // inventory slot for Mix/Sell
}

pub fn action_ap_cost(action_type: ActionType, is_distant: bool) -> u8 {
    match action_type {
        ActionType::None => 0,
        ActionType::Travel => if is_distant { 2 } else { 1 },
        ActionType::Buy => 1,
        ActionType::Sell => 1,
        ActionType::Mix => 2,
        ActionType::Scout => 1,
        ActionType::Manage => 1,
        ActionType::Invest => 1,
        ActionType::Rest => 2,
    }
}

pub const MAX_ACTIONS_PER_TURN: u8 = 4; // max AP in casual mode
```

- [ ] **Step 7: Register all type modules in lib.cairo**

Ensure `src/lib.cairo` has the types module block from Task 1 Step 5. Verify all 6 files are registered.

- [ ] **Step 8: Verify build**

Run: `scarb build`
Expected: Build succeeds with all types compiling

- [ ] **Step 9: Commit**

```bash
git add src/types/ src/lib.cairo
git commit -m "feat: add core type definitions for cartel game (drugs, locations, effects, actions, heat)"
```

---

## Task 3: ECS Models — Player, Inventory, Wallet, Heat, Reputation

**Files:**
- Create: `src/models/player.cairo`
- Create: `src/models/inventory.cairo`
- Create: `src/models/wallet.cairo`
- Create: `src/models/reputation.cairo`
- Create: `src/models/heat.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create Player model**

Create `src/models/player.cairo`:

```cairo
use starknet::ContractAddress;
use dojo::model::ModelStorage;
use crate::types::game_types::PlayerStatus;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Player {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub location: u8,
    pub ap_remaining: u8,
    pub turn: u16,
    pub max_turns: u16,
    pub status: u8,         // PlayerStatus as u8
    pub score: u32,         // clean_cash at game end
}
```

- [ ] **Step 2: Create Inventory model**

Create `src/models/inventory.cairo`:

```cairo
use starknet::ContractAddress;
use dojo::model::ModelStorage;

// 4 drug slots, each slot is: drug_id(8) + quantity(16) + quality(8) + effects(32) = 64 bits
// Total: 256 bits packed into slot_0..slot_3 as u64 each
#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Inventory {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub slot_0: u64, // packed DrugSlot
    pub slot_1: u64,
    pub slot_2: u64,
    pub slot_3: u64,
}

pub fn pack_drug_slot(drug_id: u8, quantity: u16, quality: u8, effects: u32) -> u64 {
    let mut packed: u64 = 0;
    packed = packed | (drug_id.into());
    packed = packed | ((quantity.into()) * 0x100); // shift left 8
    packed = packed | ((quality.into()) * 0x1000000); // shift left 24
    packed = packed | ((effects.into()) * 0x100000000); // shift left 32
    packed
}

pub fn unpack_drug_slot(packed: u64) -> (u8, u16, u8, u32) {
    let drug_id: u8 = (packed & 0xFF).try_into().unwrap();
    let quantity: u16 = ((packed / 0x100) & 0xFFFF).try_into().unwrap();
    let quality: u8 = ((packed / 0x1000000) & 0xFF).try_into().unwrap();
    let effects: u32 = ((packed / 0x100000000) & 0xFFFFFFFF).try_into().unwrap();
    (drug_id, quantity, quality, effects)
}
```

- [ ] **Step 3: Create Wallet model**

Create `src/models/wallet.cairo`:

```cairo
use starknet::ContractAddress;
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct WalletState {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub dirty_cash: u32,
    pub clean_cash: u32,
}
```

- [ ] **Step 4: Create Reputation model**

Create `src/models/reputation.cairo`:

```cairo
use starknet::ContractAddress;
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Reputation {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub trader_xp: u16,
    pub enforcer_xp: u16,
    pub operator_xp: u16,
    pub trader_lvl: u8,
    pub enforcer_lvl: u8,
    pub operator_lvl: u8,
}

// XP thresholds per level: 100, 300, 600, 1000, 1500
pub const LEVEL_THRESHOLDS: [u16; 5] = [100, 300, 600, 1000, 1500];

pub fn xp_to_level(xp: u16) -> u8 {
    if xp >= 1500 { 5 }
    else if xp >= 1000 { 4 }
    else if xp >= 600 { 3 }
    else if xp >= 300 { 2 }
    else if xp >= 100 { 1 }
    else { 0 }
}
```

- [ ] **Step 5: Create Heat model**

Create `src/models/heat.cairo`:

```cairo
use starknet::ContractAddress;
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct HeatProfile {
    #[key]
    pub game_id: u32,
    #[key]
    pub player_id: ContractAddress,
    pub tier: u8,           // HeatTier as u8 (0-3)
    pub notoriety: u16,     // cumulative, never fully resets
    pub location_heat: u64, // packed 6 locations × 8-bit heat (48 bits used)
}

// Pack/unpack location heat: 6 locations, each 8 bits, packed into u64
pub fn get_location_heat(packed: u64, location_idx: u8) -> u8 {
    let shift: u64 = 256; // 2^8
    let mut divisor: u64 = 1;
    let mut i: u8 = 0;
    while i < location_idx {
        divisor = divisor * shift;
        i += 1;
    };
    ((packed / divisor) & 0xFF).try_into().unwrap()
}

pub fn set_location_heat(packed: u64, location_idx: u8, value: u8) -> u64 {
    let shift: u64 = 256;
    let mut divisor: u64 = 1;
    let mut i: u8 = 0;
    while i < location_idx {
        divisor = divisor * shift;
        i += 1;
    };
    let mask = 0xFF * divisor;
    let cleared = packed & (0xFFFFFFFFFFFFFFFF - mask);
    cleared + (value.into() * divisor)
}
```

- [ ] **Step 6: Register models in lib.cairo**

Add to `src/lib.cairo`:

```cairo
// Cartel models
pub mod models {
    // Keep existing models...
    pub mod player;      // new cartel player
    pub mod inventory;
    pub mod wallet;
    pub mod reputation;
    pub mod heat;
}
```

Note: if existing `models/` module block exists, add these under a `// cartel` comment. If the existing models use a different module name (like `game.cairo`), nest these new files under a `cartel` submodule to avoid conflicts.

- [ ] **Step 7: Verify build**

Run: `scarb build`
Expected: Build succeeds. Models compile with `#[dojo::model]` macros expanding correctly.

- [ ] **Step 8: Commit**

```bash
git add src/models/player.cairo src/models/inventory.cairo src/models/wallet.cairo src/models/reputation.cairo src/models/heat.cairo src/lib.cairo
git commit -m "feat: add ECS models for Player, Inventory, Wallet, Reputation, HeatProfile"
```

---

## Task 4: ECS Models — Market, Location, GameConfig

**Files:**
- Create: `src/models/market.cairo`
- Create: `src/models/location.cairo`
- Create: `src/models/game_config.cairo`
- Create: `src/config/drugs_v2.cairo`
- Create: `src/config/locations_v2.cairo`
- Create: `src/config/game_modes.cairo`
- Create: `src/config/heat_config.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create Market model**

Create `src/models/market.cairo`:

```cairo
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Market {
    #[key]
    pub game_id: u32,
    #[key]
    pub location_id: u8,
    pub drug_prices: u128,  // packed 8 drugs × 16-bit ticks
    pub drug_supply: u128,  // packed 8 drugs × 16-bit quantity
    pub last_event: u8,     // MarketEvent enum
    pub visible_to: felt252, // bitmask of player indices who've scouted/visited
}

// Price tick packing: 8 drugs × 16 bits = 128 bits (fits in u128)
pub fn get_drug_price_tick(packed: u128, drug_idx: u8) -> u16 {
    let shift: u128 = 65536; // 2^16
    let mut divisor: u128 = 1;
    let mut i: u8 = 0;
    while i < drug_idx {
        divisor = divisor * shift;
        i += 1;
    };
    ((packed / divisor) & 0xFFFF).try_into().unwrap()
}

pub fn set_drug_price_tick(packed: u128, drug_idx: u8, value: u16) -> u128 {
    let shift: u128 = 65536;
    let mut divisor: u128 = 1;
    let mut i: u8 = 0;
    while i < drug_idx {
        divisor = divisor * shift;
        i += 1;
    };
    let mask: u128 = 0xFFFF * divisor;
    let max_u128: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    let cleared = packed & (max_u128 - mask);
    cleared + (value.into() * divisor)
}

// Supply uses same packing scheme
pub fn get_drug_supply(packed: u128, drug_idx: u8) -> u16 {
    get_drug_price_tick(packed, drug_idx) // same unpacking logic
}

pub fn set_drug_supply(packed: u128, drug_idx: u8, value: u16) -> u128 {
    set_drug_price_tick(packed, drug_idx, value)
}
```

- [ ] **Step 2: Create LocationState model**

Create `src/models/location.cairo`:

```cairo
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct LocationState {
    #[key]
    pub game_id: u32,
    #[key]
    pub location_id: u8,
    pub danger_level: u8,   // base encounter difficulty (1-10)
    pub is_adjacent_to: u64, // bitmask of adjacent locations
}
```

- [ ] **Step 3: Create GameConfig model**

Create `src/models/game_config.cairo`:

```cairo
use dojo::model::ModelStorage;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct GameConfig {
    #[key]
    pub game_id: u32,
    pub mode: u8,            // GameMode as u8
    pub max_turns: u16,
    pub ap_per_turn: u8,
    pub starting_dirty_cash: u32,
    pub starting_clean_cash: u32,
    pub heat_decay_rate: u8, // heat points decayed per turn per location
    pub max_dealer_slots: u8,
    pub season_id: u32,
}
```

- [ ] **Step 4: Create drug config**

Create `src/config/drugs_v2.cairo`:

```cairo
// Drug pricing: price = base_price + (tick * step)
// tick ranges from 0-63 (6 bits), but we use 16-bit for future expansion

pub struct DrugConfig {
    pub base_price: u16,
    pub price_step: u16,
    pub weight: u8,         // transport weight per unit
    pub initial_supply: u16,
    pub unlock_rank: u8,    // reputation level needed
}

pub fn get_drug_config(drug_id: u8) -> DrugConfig {
    match drug_id {
        1 => DrugConfig { base_price: 15,  price_step: 2,  weight: 1, initial_supply: 200, unlock_rank: 0 }, // Weed
        2 => DrugConfig { base_price: 30,  price_step: 4,  weight: 1, initial_supply: 150, unlock_rank: 0 }, // Shrooms
        3 => DrugConfig { base_price: 60,  price_step: 6,  weight: 1, initial_supply: 100, unlock_rank: 1 }, // Acid
        4 => DrugConfig { base_price: 100, price_step: 10, weight: 2, initial_supply: 80,  unlock_rank: 1 }, // Ecstasy
        5 => DrugConfig { base_price: 200, price_step: 15, weight: 2, initial_supply: 60,  unlock_rank: 2 }, // Speed
        6 => DrugConfig { base_price: 400, price_step: 25, weight: 3, initial_supply: 40,  unlock_rank: 3 }, // Heroin
        7 => DrugConfig { base_price: 600, price_step: 40, weight: 3, initial_supply: 30,  unlock_rank: 4 }, // Meth
        8 => DrugConfig { base_price: 1000, price_step: 60, weight: 4, initial_supply: 20, unlock_rank: 5 }, // Cocaine
        _ => DrugConfig { base_price: 0, price_step: 0, weight: 0, initial_supply: 0, unlock_rank: 0 },
    }
}
```

- [ ] **Step 5: Create location config**

Create `src/config/locations_v2.cairo`:

```cairo
pub struct LocationConfig {
    pub name_id: u8,
    pub danger_level: u8,  // 1-10, affects encounter threat
    pub adjacent_mask: u64, // bitmask of adjacent location IDs
}

// Location IDs: 1=Queens, 2=Bronx, 3=Brooklyn, 4=JerseyCity, 5=CentralPark, 6=ConeyIsland
// Adjacency: Queens<->Bronx, Queens<->Brooklyn, Bronx<->CentralPark,
//            Brooklyn<->ConeyIsland, Brooklyn<->JerseyCity, CentralPark<->JerseyCity
pub fn get_location_config(location_id: u8) -> LocationConfig {
    match location_id {
        1 => LocationConfig { name_id: 1, danger_level: 3, adjacent_mask: 0b000110 }, // Queens: adj Bronx(2), Brooklyn(3)
        2 => LocationConfig { name_id: 2, danger_level: 7, adjacent_mask: 0b010001 }, // Bronx: adj Queens(1), CentralPark(5)
        3 => LocationConfig { name_id: 3, danger_level: 5, adjacent_mask: 0b101001 }, // Brooklyn: adj Queens(1), JerseyCity(4), ConeyIsland(6)
        4 => LocationConfig { name_id: 4, danger_level: 4, adjacent_mask: 0b010100 }, // JerseyCity: adj Brooklyn(3), CentralPark(5)
        5 => LocationConfig { name_id: 5, danger_level: 6, adjacent_mask: 0b001010 }, // CentralPark: adj Bronx(2), JerseyCity(4)
        6 => LocationConfig { name_id: 6, danger_level: 2, adjacent_mask: 0b000100 }, // ConeyIsland: adj Brooklyn(3)
        _ => LocationConfig { name_id: 0, danger_level: 0, adjacent_mask: 0 },
    }
}

pub fn is_adjacent(from: u8, to: u8) -> bool {
    let config = get_location_config(from);
    let bit: u64 = 1;
    let mut shift: u64 = 1;
    let mut i: u8 = 1;
    while i < to {
        shift = shift * 2;
        i += 1;
    };
    (config.adjacent_mask & shift) != 0
}
```

- [ ] **Step 6: Create game mode config**

Create `src/config/game_modes.cairo`:

```cairo
pub struct ModeConfig {
    pub max_turns: u16,
    pub ap_per_turn: u8,
    pub starting_dirty_cash: u32,
    pub starting_clean_cash: u32,
    pub heat_decay_rate: u8,
    pub max_dealer_slots: u8,
}

pub fn get_mode_config(mode: u8) -> ModeConfig {
    match mode {
        0 => ModeConfig { // Casual
            max_turns: 25,
            ap_per_turn: 4,
            starting_dirty_cash: 5000,
            starting_clean_cash: 2000,
            heat_decay_rate: 2,
            max_dealer_slots: 2,
        },
        1 => ModeConfig { // Ranked
            max_turns: 60,
            ap_per_turn: 3,
            starting_dirty_cash: 2000,
            starting_clean_cash: 500,
            heat_decay_rate: 1,
            max_dealer_slots: 4,
        },
        _ => ModeConfig {
            max_turns: 25, ap_per_turn: 4, starting_dirty_cash: 5000,
            starting_clean_cash: 2000, heat_decay_rate: 2, max_dealer_slots: 2,
        },
    }
}
```

- [ ] **Step 7: Create heat config**

Create `src/config/heat_config.cairo`:

```cairo
// Heat tier escalation thresholds (cumulative notoriety)
pub const TIER_SURVEILLANCE_THRESHOLD: u16 = 20;
pub const TIER_WANTED_THRESHOLD: u16 = 50;
pub const TIER_DOA_THRESHOLD: u16 = 100;

// Notoriety gains per action
pub const SELL_NOTORIETY: u16 = 3;
pub const FIGHT_COP_NOTORIETY: u16 = 15;
pub const TRAVEL_WITH_DRUGS_NOTORIETY: u16 = 2;

// De-escalation costs
pub const BRIBE_COST_WANTED: u32 = 1000;       // clean cash
pub const BRIBE_COST_DOA: u32 = 5000;          // clean cash
pub const REST_TURNS_SURVEILLANCE: u8 = 2;
pub const REST_TURNS_WANTED: u8 = 3;
pub const REST_TURNS_DOA: u8 = 5;

pub fn notoriety_to_tier(notoriety: u16) -> u8 {
    if notoriety >= TIER_DOA_THRESHOLD { 3 }
    else if notoriety >= TIER_WANTED_THRESHOLD { 2 }
    else if notoriety >= TIER_SURVEILLANCE_THRESHOLD { 1 }
    else { 0 }
}
```

- [ ] **Step 8: Register all new modules in lib.cairo**

Add models and config modules:

```cairo
// In models block:
pub mod market;
pub mod location;
pub mod game_config;

// In config block (create if needed):
pub mod config {
    pub mod drugs_v2;
    pub mod locations_v2;
    pub mod game_modes;
    pub mod heat_config;
    pub mod ingredients; // placeholder for Task 10
}
```

- [ ] **Step 9: Verify build**

Run: `scarb build`
Expected: Build succeeds

- [ ] **Step 10: Commit**

```bash
git add src/models/market.cairo src/models/location.cairo src/models/game_config.cairo src/config/drugs_v2.cairo src/config/locations_v2.cairo src/config/game_modes.cairo src/config/heat_config.cairo src/lib.cairo
git commit -m "feat: add Market, Location, GameConfig models and drug/location/mode configs"
```

---

## Task 5: Action Hash Utilities (Commit-Reveal)

**Files:**
- Create: `src/utils/action_hash.cairo`
- Create: `src/tests/test_action_hash.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write the failing test**

Create `src/tests/test_action_hash.cairo`:

```cairo
use rollyourown::utils::action_hash::{hash_actions, verify_action_hash};
use rollyourown::types::action_types::{Action, ActionType};

#[test]
fn test_hash_actions_deterministic() {
    let actions: Array<Action> = array![
        Action {
            action_type: ActionType::Travel,
            target_location: 2,
            drug_id: 0,
            quantity: 0,
            ingredient_id: 0,
            slot_index: 0,
        },
        Action {
            action_type: ActionType::Buy,
            target_location: 0,
            drug_id: 1,
            quantity: 10,
            ingredient_id: 0,
            slot_index: 0,
        },
    ];
    let salt: felt252 = 12345;
    let hash1 = hash_actions(actions.span(), salt);
    let hash2 = hash_actions(actions.span(), salt);
    assert(hash1 == hash2, 'hashes must be deterministic');
    assert(hash1 != 0, 'hash must be non-zero');
}

#[test]
fn test_hash_actions_different_salt() {
    let actions: Array<Action> = array![
        Action {
            action_type: ActionType::Travel,
            target_location: 2,
            drug_id: 0,
            quantity: 0,
            ingredient_id: 0,
            slot_index: 0,
        },
    ];
    let hash1 = hash_actions(actions.span(), 111);
    let hash2 = hash_actions(actions.span(), 222);
    assert(hash1 != hash2, 'different salt different hash');
}

#[test]
fn test_verify_action_hash() {
    let actions: Array<Action> = array![
        Action {
            action_type: ActionType::Sell,
            target_location: 0,
            drug_id: 3,
            quantity: 5,
            ingredient_id: 0,
            slot_index: 1,
        },
    ];
    let salt: felt252 = 99999;
    let hash = hash_actions(actions.span(), salt);
    assert(verify_action_hash(actions.span(), salt, hash), 'verify must pass');
    assert(!verify_action_hash(actions.span(), 11111, hash), 'wrong salt must fail');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scarb test -f test_hash_actions`
Expected: FAIL — module `action_hash` not found

- [ ] **Step 3: Implement action hash utilities**

Create `src/utils/action_hash.cairo`:

```cairo
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use crate::types::action_types::{Action, ActionType};

pub fn hash_actions(actions: Span<Action>, salt: felt252) -> felt252 {
    let mut state = PoseidonTrait::new();
    state = state.update(salt);
    let mut i: u32 = 0;
    let len = actions.len();
    while i < len {
        let action = *actions.at(i);
        state = state.update(action_to_felt(action));
        i += 1;
    };
    state.finalize()
}

pub fn verify_action_hash(actions: Span<Action>, salt: felt252, expected_hash: felt252) -> bool {
    let computed = hash_actions(actions, salt);
    computed == expected_hash
}

fn action_to_felt(action: Action) -> felt252 {
    let action_type_u8: u8 = match action.action_type {
        ActionType::None => 0,
        ActionType::Travel => 1,
        ActionType::Buy => 2,
        ActionType::Sell => 3,
        ActionType::Mix => 4,
        ActionType::Scout => 5,
        ActionType::Manage => 6,
        ActionType::Invest => 7,
        ActionType::Rest => 8,
    };
    // Pack action fields into a single felt252
    let packed: u64 = action_type_u8.into()
        + (action.target_location.into() * 0x100)
        + (action.drug_id.into() * 0x10000)
        + (action.quantity.into() * 0x1000000)
        + (action.ingredient_id.into() * 0x10000000000)
        + (action.slot_index.into() * 0x1000000000000);
    packed.into()
}
```

- [ ] **Step 4: Register modules in lib.cairo**

Add to utils block:
```cairo
pub mod action_hash;
```

Add to tests block:
```cairo
pub mod test_action_hash;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scarb test -f test_hash_actions`
Expected: All 3 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/utils/action_hash.cairo src/tests/test_action_hash.cairo src/lib.cairo
git commit -m "feat: add commit-reveal action hash utilities with Poseidon hashing"
```

---

## Task 6: Market Helpers (Price Calc, Supply Drain, Fog of War)

**Files:**
- Create: `src/systems/helpers/market_helpers.cairo`
- Create: `src/tests/test_market.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_market.cairo`:

```cairo
use rollyourown::systems::helpers::market_helpers::{
    calculate_buy_price, calculate_sell_price, drain_supply, replenish_supply,
    apply_market_drift, is_visible_to_player,
};
use rollyourown::config::drugs_v2::get_drug_config;

#[test]
fn test_calculate_buy_price() {
    let drug_id: u8 = 1; // Weed: base=15, step=2
    let tick: u16 = 20;
    let price = calculate_buy_price(drug_id, tick);
    // price = base + tick * step = 15 + 20 * 2 = 55
    assert(price == 55, 'weed price at tick 20');
}

#[test]
fn test_calculate_sell_price_with_effects() {
    let drug_id: u8 = 1; // Weed: base=15, step=2
    let tick: u16 = 20;
    let effects: u32 = 0x00000302; // effect_id 2 (Energizing +22%) and 3 (Potent +30%)
    let price = calculate_sell_price(drug_id, tick, effects);
    // base_sell = 55, multiplier = 100 + 22 + 30 = 152 bps
    // price = 55 * 152 / 100 = 83
    assert(price == 83, 'weed with 2 effects');
}

#[test]
fn test_drain_supply() {
    let initial_supply: u16 = 200;
    let buy_qty: u16 = 50;
    let remaining = drain_supply(initial_supply, buy_qty);
    assert(remaining == 150, 'supply after drain');
}

#[test]
fn test_drain_supply_cannot_exceed() {
    let initial_supply: u16 = 30;
    let buy_qty: u16 = 50;
    let remaining = drain_supply(initial_supply, buy_qty);
    assert(remaining == 0, 'supply floors at 0');
}

#[test]
fn test_visibility_bitmask() {
    let visible_to: felt252 = 0; // nobody has scouted
    let player_idx: u8 = 3;
    assert(!is_visible_to_player(visible_to, player_idx), 'should not be visible');
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scarb test -f test_market`
Expected: FAIL — module not found

- [ ] **Step 3: Implement market helpers**

Create `src/systems/helpers/market_helpers.cairo`:

```cairo
use crate::config::drugs_v2::get_drug_config;
use crate::types::effect_types::effect_multiplier_bps;

pub fn calculate_buy_price(drug_id: u8, tick: u16) -> u32 {
    let config = get_drug_config(drug_id);
    let price: u32 = config.base_price.into() + (tick.into() * config.price_step.into());
    price
}

pub fn calculate_sell_price(drug_id: u8, tick: u16, effects: u32) -> u32 {
    let base_price = calculate_buy_price(drug_id, tick);
    let total_multiplier_bps = calculate_effect_multiplier(effects);
    // price = base * (100 + multiplier) / 100
    let price: u32 = base_price * (100 + total_multiplier_bps.into()) / 100;
    price
}

pub fn calculate_effect_multiplier(effects: u32) -> u16 {
    let mut total: u16 = 0;
    // Unpack 4 effects, each 8 bits
    let e0: u8 = (effects & 0xFF).try_into().unwrap();
    let e1: u8 = ((effects / 0x100) & 0xFF).try_into().unwrap();
    let e2: u8 = ((effects / 0x10000) & 0xFF).try_into().unwrap();
    let e3: u8 = ((effects / 0x1000000) & 0xFF).try_into().unwrap();
    total = total + effect_multiplier_bps(e0);
    total = total + effect_multiplier_bps(e1);
    total = total + effect_multiplier_bps(e2);
    total = total + effect_multiplier_bps(e3);
    total
}

pub fn drain_supply(current_supply: u16, buy_quantity: u16) -> u16 {
    if buy_quantity >= current_supply {
        0
    } else {
        current_supply - buy_quantity
    }
}

pub fn replenish_supply(current_supply: u16, sell_quantity: u16, max_supply: u16) -> u16 {
    let new_supply = current_supply + sell_quantity;
    if new_supply > max_supply {
        max_supply
    } else {
        new_supply
    }
}

pub fn apply_market_drift(tick: u16, drift: i8, max_tick: u16) -> u16 {
    if drift < 0 {
        let abs_drift: u16 = (-drift).try_into().unwrap();
        if abs_drift > tick { 0 } else { tick - abs_drift }
    } else {
        let pos_drift: u16 = drift.try_into().unwrap();
        let new_tick = tick + pos_drift;
        if new_tick > max_tick { max_tick } else { new_tick }
    }
}

pub fn is_visible_to_player(visible_to: felt252, player_idx: u8) -> bool {
    // Check if bit at player_idx is set
    // For simplicity, we convert to u256 for bit operations
    let mask: u256 = 1;
    let shifted = mask * pow2(player_idx);
    let vis_u256: u256 = visible_to.into();
    (vis_u256 & shifted) != 0
}

pub fn set_visible_to_player(visible_to: felt252, player_idx: u8) -> felt252 {
    let mask: u256 = 1;
    let shifted = mask * pow2(player_idx);
    let vis_u256: u256 = visible_to.into();
    let new_vis = vis_u256 | shifted;
    new_vis.try_into().unwrap()
}

fn pow2(exp: u8) -> u256 {
    let mut result: u256 = 1;
    let mut i: u8 = 0;
    while i < exp {
        result = result * 2;
        i += 1;
    };
    result
}
```

- [ ] **Step 4: Register modules**

Add `market_helpers` to the helpers module in `src/lib.cairo`, and `test_market` to the tests module.

- [ ] **Step 5: Run tests**

Run: `scarb test -f test_market`
Expected: All 5 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/systems/helpers/market_helpers.cairo src/tests/test_market.cairo src/lib.cairo
git commit -m "feat: add market helpers — price calc, supply drain, fog of war visibility"
```

---

## Task 7: Encounter Helpers (Auto-Resolve)

**Files:**
- Create: `src/systems/helpers/encounter_helpers.cairo`
- Create: `src/tests/test_encounters.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_encounters.cairo`:

```cairo
use rollyourown::systems::helpers::encounter_helpers::{
    should_trigger_encounter, resolve_encounter, calculate_crew_power,
    calculate_threat, EncounterOutcome,
};

#[test]
fn test_no_encounter_at_tier_0() {
    // heat tier 0 = 0% encounter rate, should never trigger
    let triggers = should_trigger_encounter(0, 5, 50); // tier=0, danger=5, roll=50
    assert(!triggers, 'tier 0 never triggers');
}

#[test]
fn test_encounter_triggers_at_tier_2() {
    // heat tier 2 = 20% encounter rate
    // roll must be < 20 to trigger
    let triggers = should_trigger_encounter(2, 5, 10); // tier=2, danger=5, roll=10 (< 20)
    assert(triggers, 'tier 2 low roll triggers');
}

#[test]
fn test_encounter_no_trigger_high_roll() {
    let triggers = should_trigger_encounter(2, 5, 50); // roll=50 (> 20)
    assert(!triggers, 'high roll no trigger');
}

#[test]
fn test_crew_power_base() {
    let power = calculate_crew_power(0, 0); // enforcer_lvl=0, no crew
    assert(power == 10, 'base crew power is 10');
}

#[test]
fn test_crew_power_with_enforcer() {
    let power = calculate_crew_power(3, 0); // enforcer_lvl=3
    // base(10) + enforcer_bonus(3 * 5 = 15) = 25
    assert(power == 25, 'enforcer lvl 3 power');
}

#[test]
fn test_resolve_encounter_win() {
    let outcome = resolve_encounter(50, 20); // crew_power=50 > threat=20
    match outcome {
        EncounterOutcome::Win => {},
        _ => { assert(false, 'should win'); },
    }
}

#[test]
fn test_resolve_encounter_lose() {
    let outcome = resolve_encounter(10, 40); // crew_power=10 < threat=40
    match outcome {
        EncounterOutcome::Lose => {},
        _ => { assert(false, 'should lose'); },
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scarb test -f test_encounter`
Expected: FAIL — module not found

- [ ] **Step 3: Implement encounter helpers**

Create `src/systems/helpers/encounter_helpers.cairo`:

```cairo
use crate::types::heat_types::encounter_rate_pct;

#[derive(Copy, Drop, PartialEq)]
pub enum EncounterOutcome {
    Win,
    Lose,
}

// Determines if an encounter triggers this action
// roll is a VRF-derived random 0-99
pub fn should_trigger_encounter(heat_tier: u8, danger_level: u8, roll: u8) -> bool {
    let base_rate = encounter_rate_pct_from_tier(heat_tier);
    if base_rate == 0 {
        return false;
    }
    // Effective rate = base_rate + (danger_level - 5) to shift for location danger
    let effective_rate: u16 = if danger_level > 5 {
        base_rate.into() + (danger_level - 5).into()
    } else {
        let reduction: u16 = (5 - danger_level).into();
        if reduction >= base_rate.into() { 1 } else { base_rate.into() - reduction }
    };
    roll.into() < effective_rate
}

fn encounter_rate_pct_from_tier(tier: u8) -> u8 {
    match tier {
        0 => 0,
        1 => 5,
        2 => 20,
        3 => 40,
        _ => 0,
    }
}

pub fn calculate_crew_power(enforcer_lvl: u8, crew_combat_stats: u32) -> u32 {
    let base_power: u32 = 10;
    let enforcer_bonus: u32 = enforcer_lvl.into() * 5;
    let crew_bonus: u32 = crew_combat_stats; // sum of active crew combat stats (Stage 2)
    base_power + enforcer_bonus + crew_bonus
}

pub fn calculate_threat(heat_tier: u8, danger_level: u8, vrf_roll_percent: u8) -> u32 {
    // heat_tier_multiplier: [0, 1, 3, 6]
    let tier_mult: u32 = match heat_tier {
        0 => 0,
        1 => 1,
        2 => 3,
        3 => 6,
        _ => 0,
    };
    // threat = tier_mult * danger * (100 + roll_variance) / 100
    // roll_variance is 0-100, representing 1.0x to 2.0x
    let base_threat: u32 = tier_mult * danger_level.into();
    let scaled: u32 = base_threat * (100 + vrf_roll_percent.into()) / 100;
    scaled
}

pub fn resolve_encounter(crew_power: u32, threat: u32) -> EncounterOutcome {
    if crew_power >= threat {
        EncounterOutcome::Win
    } else {
        EncounterOutcome::Lose
    }
}

// Losses by tier
pub struct EncounterLoss {
    pub cash_loss_pct: u8,   // % of dirty cash lost
    pub drugs_lost: u8,      // number of drug slots cleared
    pub turns_jailed: u8,    // turns unable to act
}

pub fn get_loss_severity(heat_tier: u8) -> EncounterLoss {
    match heat_tier {
        1 => EncounterLoss { cash_loss_pct: 10, drugs_lost: 0, turns_jailed: 0 },
        2 => EncounterLoss { cash_loss_pct: 25, drugs_lost: 1, turns_jailed: 1 },
        3 => EncounterLoss { cash_loss_pct: 50, drugs_lost: 4, turns_jailed: 2 },
        _ => EncounterLoss { cash_loss_pct: 0, drugs_lost: 0, turns_jailed: 0 },
    }
}
```

- [ ] **Step 4: Register modules in lib.cairo**

- [ ] **Step 5: Run tests**

Run: `scarb test -f test_encounter`
Expected: All 7 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/systems/helpers/encounter_helpers.cairo src/tests/test_encounters.cairo src/lib.cairo
git commit -m "feat: add auto-resolve encounter system with heat tier scaling"
```

---

## Task 8: Mixing Helpers

**Files:**
- Create: `src/config/ingredients.cairo`
- Create: `src/systems/helpers/mixing_helpers.cairo`
- Create: `src/tests/test_mixing.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_mixing.cairo`:

```cairo
use rollyourown::systems::helpers::mixing_helpers::{
    apply_ingredient, count_effects, get_effect_at_index,
};

#[test]
fn test_apply_first_ingredient() {
    let effects: u32 = 0; // no effects yet
    let ingredient_id: u8 = 2; // Energizing (effect_id = 2)
    let new_effects = apply_ingredient(effects, ingredient_id);
    // Effect 2 should be in slot 0
    let e0 = get_effect_at_index(new_effects, 0);
    assert(e0 == 2, 'first effect should be 2');
}

#[test]
fn test_apply_multiple_ingredients() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 2); // Energizing
    effects = apply_ingredient(effects, 3); // Potent
    let e0 = get_effect_at_index(effects, 0);
    let e1 = get_effect_at_index(effects, 1);
    assert(e0 == 2, 'slot 0 = Energizing');
    assert(e1 == 3, 'slot 1 = Potent');
    assert(count_effects(effects) == 2, 'should have 2 effects');
}

#[test]
fn test_cannot_exceed_4_effects() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 1);
    effects = apply_ingredient(effects, 2);
    effects = apply_ingredient(effects, 3);
    effects = apply_ingredient(effects, 4);
    // 5th ingredient should be rejected (returns same effects)
    let before = effects;
    effects = apply_ingredient(effects, 5);
    assert(effects == before, 'max 4 effects');
}

#[test]
fn test_no_duplicate_effects() {
    let mut effects: u32 = 0;
    effects = apply_ingredient(effects, 2); // Energizing
    let before = effects;
    effects = apply_ingredient(effects, 2); // Energizing again
    assert(effects == before, 'no duplicate effects');
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scarb test -f test_mixing`
Expected: FAIL

- [ ] **Step 3: Create ingredient config**

Create `src/config/ingredients.cairo`:

```cairo
pub struct IngredientConfig {
    pub effect_id: u8,      // which effect this ingredient adds
    pub cost: u16,          // purchase price
    pub unlock_rank: u8,    // minimum reputation level to access
}

// Ingredient IDs map directly to effect IDs for simplicity in Stage 1
// In Stage 3 (combinatorial mixing), ingredients will map to different effects
// based on existing effects on the product
pub fn get_ingredient_config(ingredient_id: u8) -> IngredientConfig {
    match ingredient_id {
        1 => IngredientConfig { effect_id: 1, cost: 5,  unlock_rank: 0 },  // Baking Soda -> Cut
        2 => IngredientConfig { effect_id: 2, cost: 10, unlock_rank: 0 },  // Caffeine -> Energizing
        3 => IngredientConfig { effect_id: 3, cost: 20, unlock_rank: 1 },  // Acetone -> Potent
        4 => IngredientConfig { effect_id: 4, cost: 8,  unlock_rank: 0 },  // Laxatives -> Bulking
        5 => IngredientConfig { effect_id: 5, cost: 12, unlock_rank: 1 },  // Vitamin -> Healthy
        6 => IngredientConfig { effect_id: 6, cost: 30, unlock_rank: 2 },  // Methanol -> Toxic
        7 => IngredientConfig { effect_id: 7, cost: 40, unlock_rank: 3 },  // Ephedrine -> Speedy
        8 => IngredientConfig { effect_id: 8, cost: 50, unlock_rank: 4 },  // Lithium -> Electric
        _ => IngredientConfig { effect_id: 0, cost: 0, unlock_rank: 0 },
    }
}
```

- [ ] **Step 4: Implement mixing helpers**

Create `src/systems/helpers/mixing_helpers.cairo`:

```cairo
use crate::config::ingredients::get_ingredient_config;
use crate::types::drug_types::MAX_EFFECTS_PER_DRUG;

pub fn get_effect_at_index(effects: u32, index: u8) -> u8 {
    let shift: u32 = match index {
        0 => 1,
        1 => 0x100,
        2 => 0x10000,
        3 => 0x1000000,
        _ => 1,
    };
    ((effects / shift) & 0xFF).try_into().unwrap()
}

fn set_effect_at_index(effects: u32, index: u8, effect_id: u8) -> u32 {
    let shift: u32 = match index {
        0 => 1,
        1 => 0x100,
        2 => 0x10000,
        3 => 0x1000000,
        _ => 1,
    };
    let mask: u32 = 0xFF * shift;
    let cleared = effects & (0xFFFFFFFF - mask);
    cleared + (effect_id.into() * shift)
}

pub fn count_effects(effects: u32) -> u8 {
    let mut count: u8 = 0;
    let mut i: u8 = 0;
    while i < 4 {
        if get_effect_at_index(effects, i) != 0 {
            count += 1;
        }
        i += 1;
    };
    count
}

fn has_effect(effects: u32, effect_id: u8) -> bool {
    let mut i: u8 = 0;
    let mut found = false;
    while i < 4 {
        if get_effect_at_index(effects, i) == effect_id {
            found = true;
        }
        i += 1;
    };
    found
}

// Applies an ingredient to a drug's effects.
// Returns the new effects packed u32, or same value if at max or duplicate.
pub fn apply_ingredient(effects: u32, ingredient_id: u8) -> u32 {
    let config = get_ingredient_config(ingredient_id);
    let effect_id = config.effect_id;

    // Check for duplicate
    if has_effect(effects, effect_id) {
        return effects;
    }

    // Find first empty slot
    let current_count = count_effects(effects);
    if current_count >= MAX_EFFECTS_PER_DRUG {
        return effects;
    }

    // Find first zero slot and fill it
    let mut i: u8 = 0;
    let mut result = effects;
    let mut placed = false;
    while i < 4 {
        if !placed && get_effect_at_index(effects, i) == 0 {
            result = set_effect_at_index(result, i, effect_id);
            placed = true;
        }
        i += 1;
    };
    result
}
```

- [ ] **Step 5: Register modules**

- [ ] **Step 6: Run tests**

Run: `scarb test -f test_mixing`
Expected: All 4 tests PASS

- [ ] **Step 7: Commit**

```bash
git add src/config/ingredients.cairo src/systems/helpers/mixing_helpers.cairo src/tests/test_mixing.cairo src/lib.cairo
git commit -m "feat: add mixing system — ingredient config, effect stacking, max 4 effects"
```

---

## Task 9: Heat System Helpers

**Files:**
- Create: `src/tests/test_heat.cairo`
- Modify: `src/models/heat.cairo` (add helper functions)

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_heat.cairo`:

```cairo
use rollyourown::models::heat::{get_location_heat, set_location_heat};
use rollyourown::config::heat_config::{
    notoriety_to_tier, SELL_NOTORIETY, TIER_SURVEILLANCE_THRESHOLD,
};

#[test]
fn test_location_heat_pack_unpack() {
    let mut packed: u64 = 0;
    packed = set_location_heat(packed, 0, 10); // Queens heat = 10
    packed = set_location_heat(packed, 2, 25); // Brooklyn heat = 25
    assert(get_location_heat(packed, 0) == 10, 'queens heat');
    assert(get_location_heat(packed, 1) == 0, 'bronx heat');
    assert(get_location_heat(packed, 2) == 25, 'brooklyn heat');
}

#[test]
fn test_notoriety_to_tier_none() {
    assert(notoriety_to_tier(0) == 0, 'zero is tier 0');
    assert(notoriety_to_tier(19) == 0, 'just below surveillance');
}

#[test]
fn test_notoriety_to_tier_surveillance() {
    assert(notoriety_to_tier(20) == 1, 'at surveillance threshold');
    assert(notoriety_to_tier(49) == 1, 'just below wanted');
}

#[test]
fn test_notoriety_to_tier_wanted() {
    assert(notoriety_to_tier(50) == 2, 'at wanted threshold');
}

#[test]
fn test_notoriety_to_tier_doa() {
    assert(notoriety_to_tier(100) == 3, 'at DOA threshold');
    assert(notoriety_to_tier(200) == 3, 'well above DOA');
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scarb test -f test_heat`
Expected: FAIL (or PASS if models already compile — the tests exercise existing code from Task 3)

- [ ] **Step 3: If tests fail, fix any compilation issues in heat.cairo or heat_config.cairo**

These tests exercise code already written in Tasks 3 and 4. If they pass immediately, that validates the packing/unpacking logic.

- [ ] **Step 4: Register test module**

Add `test_heat` to tests module in `src/lib.cairo`.

- [ ] **Step 5: Run tests**

Run: `scarb test -f test_heat`
Expected: All 5 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/tests/test_heat.cairo src/lib.cairo
git commit -m "test: add heat system unit tests — location packing, tier thresholds"
```

---

## Task 10: Action Executor (Core Game Logic)

**Files:**
- Create: `src/systems/helpers/action_executor.cairo`
- Create: `src/tests/test_actions.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_actions.cairo`:

```cairo
use rollyourown::systems::helpers::action_executor::{
    validate_action, calculate_total_ap_cost,
};
use rollyourown::types::action_types::{Action, ActionType, action_ap_cost};

#[test]
fn test_calculate_total_ap_cost_simple() {
    let actions: Array<Action> = array![
        Action { action_type: ActionType::Travel, target_location: 2, drug_id: 0, quantity: 0, ingredient_id: 0, slot_index: 0 },
        Action { action_type: ActionType::Buy, target_location: 0, drug_id: 1, quantity: 10, ingredient_id: 0, slot_index: 0 },
    ];
    // Travel(1, adjacent) + Buy(1) = 2
    let total = calculate_total_ap_cost(actions.span(), 1, false); // from location 1, travel to 2 is adjacent
    assert(total == 2, 'travel + buy = 2 AP');
}

#[test]
fn test_calculate_total_ap_cost_with_mix() {
    let actions: Array<Action> = array![
        Action { action_type: ActionType::Mix, target_location: 0, drug_id: 0, quantity: 0, ingredient_id: 2, slot_index: 0 },
    ];
    let total = calculate_total_ap_cost(actions.span(), 1, false);
    assert(total == 2, 'mix = 2 AP');
}

#[test]
fn test_validate_action_travel_needs_target() {
    let action = Action {
        action_type: ActionType::Travel,
        target_location: 0, // 0 = Home, not a valid travel destination
        drug_id: 0,
        quantity: 0,
        ingredient_id: 0,
        slot_index: 0,
    };
    assert(!validate_action(action, 1, 3), 'travel to home invalid');
}

#[test]
fn test_validate_action_buy_needs_drug() {
    let action = Action {
        action_type: ActionType::Buy,
        target_location: 0,
        drug_id: 0, // no drug specified
        quantity: 10,
        ingredient_id: 0,
        slot_index: 0,
    };
    assert(!validate_action(action, 1, 3), 'buy needs drug_id');
}

#[test]
fn test_validate_action_buy_needs_quantity() {
    let action = Action {
        action_type: ActionType::Buy,
        target_location: 0,
        drug_id: 1,
        quantity: 0, // no quantity
        ingredient_id: 0,
        slot_index: 0,
    };
    assert(!validate_action(action, 1, 3), 'buy needs quantity');
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scarb test -f test_actions`
Expected: FAIL

- [ ] **Step 3: Implement action executor**

Create `src/systems/helpers/action_executor.cairo`:

```cairo
use crate::types::action_types::{Action, ActionType, action_ap_cost};
use crate::config::locations_v2::is_adjacent;

// Validates a single action's fields
pub fn validate_action(action: Action, current_location: u8, ap_remaining: u8) -> bool {
    match action.action_type {
        ActionType::None => false,
        ActionType::Travel => {
            // Must have a valid destination (1-6), not same as current
            action.target_location >= 1
                && action.target_location <= 6
                && action.target_location != current_location
        },
        ActionType::Buy => {
            action.drug_id >= 1 && action.drug_id <= 8 && action.quantity > 0
        },
        ActionType::Sell => {
            action.drug_id >= 1 && action.drug_id <= 8 && action.quantity > 0 && action.slot_index < 4
        },
        ActionType::Mix => {
            action.ingredient_id >= 1 && action.ingredient_id <= 8 && action.slot_index < 4
        },
        ActionType::Scout => {
            action.target_location >= 1 && action.target_location <= 6
        },
        ActionType::Rest => true,
        ActionType::Manage => true,
        ActionType::Invest => true,
    }
}

// Calculates total AP cost for a batch of actions
// `current_location` is where the player starts the turn
// `any_distant_travel` indicates if any travel action is non-adjacent (costs 2 AP)
pub fn calculate_total_ap_cost(
    actions: Span<Action>,
    current_location: u8,
    any_distant_travel: bool,
) -> u8 {
    let mut total: u8 = 0;
    let mut i: u32 = 0;
    let mut loc = current_location;
    let len = actions.len();
    while i < len {
        let action = *actions.at(i);
        let is_distant = match action.action_type {
            ActionType::Travel => !is_adjacent(loc, action.target_location),
            _ => false,
        };
        total = total + action_ap_cost(action.action_type, is_distant);
        // Update simulated location for subsequent actions
        if action.action_type == ActionType::Travel {
            loc = action.target_location;
        }
        i += 1;
    };
    total
}

// Validates an entire action batch
pub fn validate_action_batch(
    actions: Span<Action>,
    current_location: u8,
    ap_available: u8,
) -> bool {
    // Check total AP doesn't exceed available
    let total_cost = calculate_total_ap_cost(actions, current_location, false);
    if total_cost > ap_available {
        return false;
    }

    // Validate each action individually
    let mut i: u32 = 0;
    let mut loc = current_location;
    let mut valid = true;
    let len = actions.len();
    while i < len {
        let action = *actions.at(i);
        if !validate_action(action, loc, ap_available) {
            valid = false;
        }
        if action.action_type == ActionType::Travel {
            loc = action.target_location;
        }
        i += 1;
    };
    valid
}
```

- [ ] **Step 4: Register modules**

- [ ] **Step 5: Run tests**

Run: `scarb test -f test_actions`
Expected: All 5 tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/systems/helpers/action_executor.cairo src/tests/test_actions.cairo src/lib.cairo
git commit -m "feat: add action executor — validation, AP cost calculation, batch validation"
```

---

## Task 11: Main Game Contract (cartel_game.cairo)

**Files:**
- Create: `src/systems/cartel_game.cairo`
- Create: `src/tests/test_game_lifecycle.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml` (add writer permissions)

This is the largest task — the main game contract that orchestrates create_game, commit_actions, reveal_resolve, and end_game.

- [ ] **Step 1: Write the failing test for game creation**

Create `src/tests/test_game_lifecycle.cairo`:

```cairo
// Integration tests will require a full Dojo test harness setup.
// For now, test the internal logic functions.

use rollyourown::systems::helpers::action_executor::validate_action_batch;
use rollyourown::types::action_types::{Action, ActionType};

#[test]
fn test_full_turn_batch_validation() {
    // Simulate: Travel to Bronx (1 AP), Buy Weed (1 AP), Scout Brooklyn (1 AP) = 3 AP
    let actions: Array<Action> = array![
        Action { action_type: ActionType::Travel, target_location: 2, drug_id: 0, quantity: 0, ingredient_id: 0, slot_index: 0 },
        Action { action_type: ActionType::Buy, target_location: 0, drug_id: 1, quantity: 20, ingredient_id: 0, slot_index: 0 },
        Action { action_type: ActionType::Scout, target_location: 3, drug_id: 0, quantity: 0, ingredient_id: 0, slot_index: 0 },
    ];
    let valid = validate_action_batch(actions.span(), 1, 3); // start at Queens, 3 AP
    assert(valid, 'valid 3-action batch');
}

#[test]
fn test_batch_exceeds_ap() {
    // Mix (2 AP) + Mix (2 AP) = 4 AP, but only 3 available
    let actions: Array<Action> = array![
        Action { action_type: ActionType::Mix, target_location: 0, drug_id: 0, quantity: 0, ingredient_id: 1, slot_index: 0 },
        Action { action_type: ActionType::Mix, target_location: 0, drug_id: 0, quantity: 0, ingredient_id: 2, slot_index: 1 },
    ];
    let valid = validate_action_batch(actions.span(), 1, 3); // only 3 AP
    assert(!valid, 'exceeds AP');
}

#[test]
fn test_empty_batch_valid() {
    let actions: Array<Action> = array![];
    let valid = validate_action_batch(actions.span(), 1, 3);
    assert(valid, 'empty batch ok');
}
```

- [ ] **Step 2: Run tests**

Run: `scarb test -f test_game_lifecycle`
Expected: Tests should PASS (they exercise existing helper code)

- [ ] **Step 3: Create the main game contract**

Create `src/systems/cartel_game.cairo`:

```cairo
use starknet::ContractAddress;
use crate::types::action_types::Action;

#[starknet::interface]
pub trait ICartelGame<T> {
    // Create a new game instance
    fn create_game(ref self: T, mode: u8, player_name: felt252) -> u32;

    // Commit phase: submit hashed action batch
    fn commit_actions(ref self: T, game_id: u32, action_hash: felt252, ap_spent: u8);

    // Reveal phase: reveal actions + VRF seed resolves outcomes
    fn reveal_resolve(ref self: T, game_id: u32, actions: Array<Action>, salt: felt252);

    // End the game and register score
    fn end_game(ref self: T, game_id: u32);
}

#[dojo::contract]
pub mod cartel_game {
    use super::{ICartelGame, Action};
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    use crate::models::player::Player;
    use crate::models::inventory::Inventory;
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::models::heat::HeatProfile;
    use crate::models::market::{Market, get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply};
    use crate::models::game_config::GameConfig;
    use crate::models::location::LocationState;
    use crate::models::inventory::{pack_drug_slot, unpack_drug_slot};

    use crate::config::game_modes::get_mode_config;
    use crate::config::drugs_v2::get_drug_config;
    use crate::config::locations_v2::get_location_config;
    use crate::config::heat_config::notoriety_to_tier;
    use crate::config::ingredients::get_ingredient_config;

    use crate::types::action_types::{ActionType, action_ap_cost};
    use crate::types::game_types::{GameStatus, PlayerStatus};
    use crate::types::drug_types::DRUG_COUNT;
    use crate::types::location_types::LOCATION_COUNT;

    use crate::utils::action_hash::{hash_actions, verify_action_hash};
    use crate::systems::helpers::action_executor::{validate_action_batch, calculate_total_ap_cost};
    use crate::systems::helpers::market_helpers::{
        calculate_buy_price, calculate_sell_price, drain_supply, replenish_supply,
        set_visible_to_player, is_visible_to_player,
    };
    use crate::systems::helpers::encounter_helpers::{
        should_trigger_encounter, resolve_encounter, calculate_crew_power,
        calculate_threat, get_loss_severity, EncounterOutcome,
    };
    use crate::systems::helpers::mixing_helpers::apply_ingredient;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    // Simple game ID counter stored as a model
    #[dojo::model]
    #[derive(Copy, Drop, Serde)]
    pub struct GameCounter {
        #[key]
        pub singleton: u8, // always 0
        pub next_id: u32,
    }

    // Stores committed action hash for a player's current turn
    #[dojo::model]
    #[derive(Copy, Drop, Serde)]
    pub struct ActionCommit {
        #[key]
        pub game_id: u32,
        #[key]
        pub player_id: ContractAddress,
        pub action_hash: felt252,
        pub ap_spent: u8,
        pub turn: u16,
    }

    #[abi(embed_v0)]
    impl CartelGameImpl of super::ICartelGame<ContractState> {

        fn create_game(ref self: ContractState, mode: u8, player_name: felt252) -> u32 {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            // Get next game ID
            let mut counter: GameCounter = world.read_model(0_u8);
            let game_id = counter.next_id;
            counter.next_id = game_id + 1;
            world.write_model(@counter);

            // Load mode config
            let mode_config = get_mode_config(mode);

            // Write GameConfig
            let config = GameConfig {
                game_id,
                mode,
                max_turns: mode_config.max_turns,
                ap_per_turn: mode_config.ap_per_turn,
                starting_dirty_cash: mode_config.starting_dirty_cash,
                starting_clean_cash: mode_config.starting_clean_cash,
                heat_decay_rate: mode_config.heat_decay_rate,
                max_dealer_slots: mode_config.max_dealer_slots,
                season_id: 0, // set later
            };
            world.write_model(@config);

            // Write Player (starts at Queens = location 1)
            let player = Player {
                game_id,
                player_id: caller,
                location: 1,
                ap_remaining: mode_config.ap_per_turn,
                turn: 1,
                max_turns: mode_config.max_turns,
                status: 0, // Normal
                score: 0,
            };
            world.write_model(@player);

            // Write empty Inventory
            let inventory = Inventory {
                game_id, player_id: caller,
                slot_0: 0, slot_1: 0, slot_2: 0, slot_3: 0,
            };
            world.write_model(@inventory);

            // Write WalletState
            let wallet = WalletState {
                game_id, player_id: caller,
                dirty_cash: mode_config.starting_dirty_cash,
                clean_cash: mode_config.starting_clean_cash,
            };
            world.write_model(@wallet);

            // Write Reputation (all zero)
            let reputation = Reputation {
                game_id, player_id: caller,
                trader_xp: 0, enforcer_xp: 0, operator_xp: 0,
                trader_lvl: 0, enforcer_lvl: 0, operator_lvl: 0,
            };
            world.write_model(@reputation);

            // Write HeatProfile (all zero)
            let heat = HeatProfile {
                game_id, player_id: caller,
                tier: 0, notoriety: 0, location_heat: 0,
            };
            world.write_model(@heat);

            // Initialize markets for all 6 locations
            self._init_markets(game_id);

            // Mark starting location as visible
            let mut start_market: Market = world.read_model((game_id, 1_u8));
            start_market.visible_to = set_visible_to_player(start_market.visible_to, 0);
            world.write_model(@start_market);

            game_id
        }

        fn commit_actions(
            ref self: ContractState,
            game_id: u32,
            action_hash: felt252,
            ap_spent: u8,
        ) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let player: Player = world.read_model((game_id, caller));

            // Verify game is in progress
            assert(player.status == 0, 'player not active');
            assert(player.turn <= player.max_turns, 'game over');
            assert(ap_spent <= player.ap_remaining, 'not enough AP');

            // Store the commit
            let commit = ActionCommit {
                game_id,
                player_id: caller,
                action_hash,
                ap_spent,
                turn: player.turn,
            };
            world.write_model(@commit);
        }

        fn reveal_resolve(
            ref self: ContractState,
            game_id: u32,
            actions: Array<Action>,
            salt: felt252,
        ) {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            // Verify commit exists and hash matches
            let commit: ActionCommit = world.read_model((game_id, caller));
            let computed_hash = hash_actions(actions.span(), salt);
            assert(commit.action_hash == computed_hash, 'hash mismatch');

            // Load all player state
            let mut player: Player = world.read_model((game_id, caller));
            let mut inventory: Inventory = world.read_model((game_id, caller));
            let mut wallet: WalletState = world.read_model((game_id, caller));
            let mut heat: HeatProfile = world.read_model((game_id, caller));
            let mut reputation: Reputation = world.read_model((game_id, caller));
            let config: GameConfig = world.read_model(game_id);

            // Validate batch
            assert(
                validate_action_batch(actions.span(), player.location, config.ap_per_turn),
                'invalid action batch'
            );

            // Execute each action
            let mut i: u32 = 0;
            let len = actions.len();
            // Use a simple pseudo-random seed from salt for encounter rolls
            let mut rng_state: felt252 = salt;

            while i < len {
                let action = *actions.at(i);
                self._execute_action(
                    game_id,
                    ref player, ref inventory, ref wallet, ref heat, ref reputation,
                    action, ref rng_state,
                );
                i += 1;
            };

            // Advance turn
            player.turn = player.turn + 1;
            player.ap_remaining = config.ap_per_turn;

            // Decay heat at non-current locations
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                if loc != player.location {
                    let current_heat = crate::models::heat::get_location_heat(heat.location_heat, loc - 1);
                    if current_heat > config.heat_decay_rate {
                        heat.location_heat = crate::models::heat::set_location_heat(
                            heat.location_heat, loc - 1, current_heat - config.heat_decay_rate
                        );
                    } else {
                        heat.location_heat = crate::models::heat::set_location_heat(
                            heat.location_heat, loc - 1, 0
                        );
                    }
                }
                loc += 1;
            };

            // Recalculate heat tier from notoriety
            heat.tier = notoriety_to_tier(heat.notoriety);

            // Save all state
            world.write_model(@player);
            world.write_model(@inventory);
            world.write_model(@wallet);
            world.write_model(@heat);
            world.write_model(@reputation);
        }

        fn end_game(ref self: ContractState, game_id: u32) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let mut player: Player = world.read_model((game_id, caller));
            let wallet: WalletState = world.read_model((game_id, caller));

            assert(
                player.turn > player.max_turns || player.status == 3, // Dead
                'game not over'
            );

            player.score = wallet.clean_cash;
            player.status = 4; // Finished (add to GameStatus enum)
            world.write_model(@player);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {

        fn _init_markets(ref self: ContractState, game_id: u32) {
            let mut world = self.world(ns());
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                let mut drug_prices: u128 = 0;
                let mut drug_supply: u128 = 0;
                let mut drug_id: u8 = 1;
                while drug_id <= DRUG_COUNT {
                    let drug_config = get_drug_config(drug_id);
                    // Start at middle tick (32 of 64 range)
                    drug_prices = set_drug_price_tick(drug_prices, drug_id - 1, 32);
                    drug_supply = set_drug_supply(drug_supply, drug_id - 1, drug_config.initial_supply);
                    drug_id += 1;
                };
                let loc_config = get_location_config(loc);
                let market = Market {
                    game_id,
                    location_id: loc,
                    drug_prices,
                    drug_supply,
                    last_event: 0,
                    visible_to: 0,
                };
                world.write_model(@market);

                let location_state = LocationState {
                    game_id,
                    location_id: loc,
                    danger_level: loc_config.danger_level,
                    is_adjacent_to: loc_config.adjacent_mask,
                };
                world.write_model(@location_state);
                loc += 1;
            };
        }

        fn _execute_action(
            ref self: ContractState,
            game_id: u32,
            ref player: Player,
            ref inventory: Inventory,
            ref wallet: WalletState,
            ref heat: HeatProfile,
            ref reputation: Reputation,
            action: Action,
            ref rng_state: felt252,
        ) {
            let mut world = self.world(ns());

            match action.action_type {
                ActionType::Travel => {
                    player.location = action.target_location;
                    // Mark new location as visible
                    let mut market: Market = world.read_model((game_id, action.target_location));
                    market.visible_to = set_visible_to_player(market.visible_to, 0);
                    world.write_model(@market);
                    // Add travel-with-drugs notoriety if carrying
                    if self._has_any_drugs(ref inventory) {
                        heat.notoriety = heat.notoriety + crate::config::heat_config::TRAVEL_WITH_DRUGS_NOTORIETY;
                    }
                    // Check encounter
                    rng_state = core::poseidon::PoseidonTrait::new().update(rng_state).update(1).finalize();
                    let roll: u8 = (Into::<felt252, u256>::into(rng_state) % 100).try_into().unwrap();
                    let location_state: LocationState = world.read_model((game_id, action.target_location));
                    if should_trigger_encounter(heat.tier, location_state.danger_level, roll) {
                        self._handle_encounter(
                            ref player, ref inventory, ref wallet, ref heat, ref reputation,
                            location_state.danger_level, ref rng_state,
                        );
                    }
                    // Add reputation XP for trading
                    reputation.trader_xp = reputation.trader_xp + 2;
                },
                ActionType::Buy => {
                    let mut market: Market = world.read_model((game_id, player.location));
                    let tick = get_drug_price_tick(market.drug_prices, action.drug_id - 1);
                    let price = calculate_buy_price(action.drug_id, tick);
                    let total_cost: u32 = price * action.quantity.into();
                    assert(wallet.dirty_cash >= total_cost, 'not enough cash');

                    // Find empty inventory slot or matching drug slot
                    let slot_idx = self._find_or_allocate_slot(ref inventory, action.drug_id);
                    assert(slot_idx < 4, 'inventory full');

                    // Update inventory
                    self._add_to_slot(ref inventory, slot_idx, action.drug_id, action.quantity, 100, 0);

                    // Drain supply, deduct cash
                    let supply = get_drug_supply(market.drug_supply, action.drug_id - 1);
                    market.drug_supply = set_drug_supply(
                        market.drug_supply, action.drug_id - 1, drain_supply(supply, action.quantity)
                    );
                    world.write_model(@market);
                    wallet.dirty_cash = wallet.dirty_cash - total_cost;

                    // Reputation
                    reputation.trader_xp = reputation.trader_xp + 5;

                    // Heat
                    heat.notoriety = heat.notoriety + crate::config::heat_config::SELL_NOTORIETY;
                    let loc_idx = player.location - 1;
                    let loc_heat = crate::models::heat::get_location_heat(heat.location_heat, loc_idx);
                    heat.location_heat = crate::models::heat::set_location_heat(
                        heat.location_heat, loc_idx, loc_heat + 5
                    );
                },
                ActionType::Sell => {
                    let slot = self._get_slot(ref inventory, action.slot_index);
                    let (drug_id, qty, _quality, effects) = unpack_drug_slot(slot);
                    assert(drug_id == action.drug_id, 'wrong drug in slot');
                    assert(qty >= action.quantity, 'not enough quantity');

                    let market: Market = world.read_model((game_id, player.location));
                    let tick = get_drug_price_tick(market.drug_prices, action.drug_id - 1);
                    let price = calculate_sell_price(action.drug_id, tick, effects);
                    let earnings: u32 = price * action.quantity.into();

                    // Update inventory (reduce quantity)
                    self._reduce_slot_quantity(ref inventory, action.slot_index, action.quantity);

                    // Add earnings as dirty cash
                    wallet.dirty_cash = wallet.dirty_cash + earnings;

                    // Reputation
                    reputation.trader_xp = reputation.trader_xp + 5;

                    // Heat
                    heat.notoriety = heat.notoriety + crate::config::heat_config::SELL_NOTORIETY;
                },
                ActionType::Mix => {
                    let slot = self._get_slot(ref inventory, action.slot_index);
                    let (drug_id, qty, quality, effects) = unpack_drug_slot(slot);
                    assert(drug_id > 0, 'slot is empty');

                    let ingredient_config = get_ingredient_config(action.ingredient_id);
                    let cost: u32 = ingredient_config.cost.into();
                    assert(wallet.dirty_cash >= cost, 'not enough cash for ingredient');

                    let new_effects = apply_ingredient(effects, action.ingredient_id);
                    wallet.dirty_cash = wallet.dirty_cash - cost;

                    // Update slot with new effects
                    self._set_slot(ref inventory, action.slot_index, drug_id, qty, quality, new_effects);

                    // Reputation
                    reputation.operator_xp = reputation.operator_xp + 3;
                },
                ActionType::Scout => {
                    let mut market: Market = world.read_model((game_id, action.target_location));
                    market.visible_to = set_visible_to_player(market.visible_to, 0);
                    world.write_model(@market);
                    reputation.trader_xp = reputation.trader_xp + 3;
                },
                ActionType::Rest => {
                    // Reduce heat tier by 1
                    if heat.tier > 0 {
                        // Reduce notoriety to just below current tier threshold
                        if heat.tier == 3 {
                            heat.notoriety = crate::config::heat_config::TIER_WANTED_THRESHOLD - 1;
                        } else if heat.tier == 2 {
                            heat.notoriety = crate::config::heat_config::TIER_SURVEILLANCE_THRESHOLD - 1;
                        } else {
                            heat.notoriety = 0;
                        }
                    }
                },
                ActionType::Manage => {
                    // Stage 2: dealer management
                },
                ActionType::Invest => {
                    // Stage 2: operations investment
                },
                ActionType::None => {},
            }
        }

        fn _handle_encounter(
            ref self: ContractState,
            ref player: Player,
            ref inventory: Inventory,
            ref wallet: WalletState,
            ref heat: HeatProfile,
            ref reputation: Reputation,
            danger_level: u8,
            ref rng_state: felt252,
        ) {
            let crew_power = calculate_crew_power(reputation.enforcer_lvl, 0);

            rng_state = core::poseidon::PoseidonTrait::new().update(rng_state).update(2).finalize();
            let threat_roll: u8 = (Into::<felt252, u256>::into(rng_state) % 100).try_into().unwrap();
            let threat = calculate_threat(heat.tier, danger_level, threat_roll);

            let outcome = resolve_encounter(crew_power, threat);

            match outcome {
                EncounterOutcome::Win => {
                    // Survived — gain enforcer XP
                    reputation.enforcer_xp = reputation.enforcer_xp + 10;
                },
                EncounterOutcome::Lose => {
                    let severity = get_loss_severity(heat.tier);
                    // Lose cash
                    let cash_loss = wallet.dirty_cash * severity.cash_loss_pct.into() / 100;
                    wallet.dirty_cash = wallet.dirty_cash - cash_loss;
                    // Lose drugs (clear slots)
                    let mut cleared: u8 = 0;
                    if severity.drugs_lost >= 1 && cleared < severity.drugs_lost {
                        inventory.slot_0 = 0; cleared += 1;
                    }
                    if severity.drugs_lost >= 2 && cleared < severity.drugs_lost {
                        inventory.slot_1 = 0; cleared += 1;
                    }
                    if severity.drugs_lost >= 3 && cleared < severity.drugs_lost {
                        inventory.slot_2 = 0; cleared += 1;
                    }
                    if severity.drugs_lost >= 4 && cleared < severity.drugs_lost {
                        inventory.slot_3 = 0;
                    }
                    // Jail
                    if severity.turns_jailed > 0 {
                        player.status = 1; // Jailed
                    }
                },
            }
        }

        fn _has_any_drugs(ref self: ContractState, ref inventory: Inventory) -> bool {
            inventory.slot_0 != 0 || inventory.slot_1 != 0 || inventory.slot_2 != 0 || inventory.slot_3 != 0
        }

        fn _get_slot(ref self: ContractState, ref inventory: Inventory, index: u8) -> u64 {
            match index {
                0 => inventory.slot_0,
                1 => inventory.slot_1,
                2 => inventory.slot_2,
                3 => inventory.slot_3,
                _ => 0,
            }
        }

        fn _set_slot(
            ref self: ContractState,
            ref inventory: Inventory,
            index: u8,
            drug_id: u8, quantity: u16, quality: u8, effects: u32,
        ) {
            let packed = pack_drug_slot(drug_id, quantity, quality, effects);
            match index {
                0 => inventory.slot_0 = packed,
                1 => inventory.slot_1 = packed,
                2 => inventory.slot_2 = packed,
                3 => inventory.slot_3 = packed,
                _ => {},
            }
        }

        fn _add_to_slot(
            ref self: ContractState,
            ref inventory: Inventory,
            index: u8,
            drug_id: u8, quantity: u16, quality: u8, effects: u32,
        ) {
            let current = self._get_slot(ref inventory, index);
            let (existing_drug, existing_qty, existing_quality, existing_effects) = unpack_drug_slot(current);
            if existing_drug == 0 {
                // Empty slot — fill it
                self._set_slot(ref inventory, index, drug_id, quantity, quality, effects);
            } else {
                // Same drug — add quantity
                self._set_slot(ref inventory, index, drug_id, existing_qty + quantity, existing_quality, existing_effects);
            }
        }

        fn _reduce_slot_quantity(
            ref self: ContractState,
            ref inventory: Inventory,
            index: u8,
            amount: u16,
        ) {
            let current = self._get_slot(ref inventory, index);
            let (drug_id, qty, quality, effects) = unpack_drug_slot(current);
            if amount >= qty {
                // Clear the slot
                match index {
                    0 => inventory.slot_0 = 0,
                    1 => inventory.slot_1 = 0,
                    2 => inventory.slot_2 = 0,
                    3 => inventory.slot_3 = 0,
                    _ => {},
                }
            } else {
                self._set_slot(ref inventory, index, drug_id, qty - amount, quality, effects);
            }
        }

        fn _find_or_allocate_slot(
            ref self: ContractState,
            ref inventory: Inventory,
            drug_id: u8,
        ) -> u8 {
            // First check for existing slot with same drug
            let mut i: u8 = 0;
            while i < 4 {
                let slot = self._get_slot(ref inventory, i);
                let (existing_drug, _, _, _) = unpack_drug_slot(slot);
                if existing_drug == drug_id {
                    return i;
                }
                i += 1;
            };
            // Find first empty slot
            i = 0;
            while i < 4 {
                let slot = self._get_slot(ref inventory, i);
                if slot == 0 {
                    return i;
                }
                i += 1;
            };
            // No slot available
            255 // sentinel for "full"
        }
    }
}
```

- [ ] **Step 4: Register contract and models in lib.cairo**

Add to systems block:
```cairo
pub mod cartel_game;
```

- [ ] **Step 5: Add writer permissions to dojo_cartel_dev.toml**

Add to `dojo_cartel_dev.toml`:

```toml
[writers]
"cartel_v0-Player" = ["cartel_v0-cartel_game"]
"cartel_v0-Inventory" = ["cartel_v0-cartel_game"]
"cartel_v0-WalletState" = ["cartel_v0-cartel_game"]
"cartel_v0-Reputation" = ["cartel_v0-cartel_game"]
"cartel_v0-HeatProfile" = ["cartel_v0-cartel_game"]
"cartel_v0-Market" = ["cartel_v0-cartel_game"]
"cartel_v0-LocationState" = ["cartel_v0-cartel_game"]
"cartel_v0-GameConfig" = ["cartel_v0-cartel_game"]
"cartel_v0-GameCounter" = ["cartel_v0-cartel_game"]
"cartel_v0-ActionCommit" = ["cartel_v0-cartel_game"]
```

- [ ] **Step 6: Verify build**

Run: `scarb build`
Expected: Build succeeds. May need to fix import paths — adjust based on actual module structure.

- [ ] **Step 7: Run all tests**

Run: `scarb test`
Expected: All tests pass (unit tests don't test contract directly, but helper code still works)

- [ ] **Step 8: Commit**

```bash
git add src/systems/cartel_game.cairo src/tests/test_game_lifecycle.cairo src/lib.cairo dojo_cartel_dev.toml
git commit -m "feat: add main cartel game contract — create, commit, reveal, end game lifecycle"
```

---

## Task 12: Market System Contract (Fog of War Queries)

**Files:**
- Create: `src/systems/market_system.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml`

- [ ] **Step 1: Create market system contract**

Create `src/systems/market_system.cairo`:

```cairo
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMarketSystem<T> {
    // Query visible market prices (fog-enforced)
    fn get_visible_prices(
        self: @T, game_id: u32, player_idx: u8, location_id: u8
    ) -> (u128, u128); // (prices, supply) — zeros if not visible

    // Get all visible markets for a player
    fn get_all_visible(
        self: @T, game_id: u32, player_idx: u8
    ) -> Array<(u8, u128, u128)>; // (location_id, prices, supply)
}

#[dojo::contract]
pub mod market_system {
    use super::IMarketSystem;
    use starknet::ContractAddress;
    use dojo::model::ModelStorage;

    use crate::models::market::{Market};
    use crate::systems::helpers::market_helpers::is_visible_to_player;
    use crate::types::location_types::LOCATION_COUNT;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl MarketSystemImpl of super::IMarketSystem<ContractState> {

        fn get_visible_prices(
            self: @ContractState,
            game_id: u32,
            player_idx: u8,
            location_id: u8,
        ) -> (u128, u128) {
            let world = self.world(ns());
            let market: Market = world.read_model((game_id, location_id));

            if is_visible_to_player(market.visible_to, player_idx) {
                (market.drug_prices, market.drug_supply)
            } else {
                (0, 0) // fogged
            }
        }

        fn get_all_visible(
            self: @ContractState,
            game_id: u32,
            player_idx: u8,
        ) -> Array<(u8, u128, u128)> {
            let world = self.world(ns());
            let mut result: Array<(u8, u128, u128)> = array![];
            let mut loc: u8 = 1;
            while loc <= LOCATION_COUNT {
                let market: Market = world.read_model((game_id, loc));
                if is_visible_to_player(market.visible_to, player_idx) {
                    result.append((loc, market.drug_prices, market.drug_supply));
                }
                loc += 1;
            };
            result
        }
    }
}
```

- [ ] **Step 2: Register in lib.cairo**

Add `pub mod market_system;` to systems block.

- [ ] **Step 3: Verify build**

Run: `scarb build`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/systems/market_system.cairo src/lib.cairo
git commit -m "feat: add market system contract with fog of war enforced queries"
```

---

## Task 13: Season & Leaderboard Contract

**Files:**
- Create: `src/systems/season_v2.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml`

- [ ] **Step 1: Create season contract**

Create `src/systems/season_v2.cairo`:

```cairo
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISeasonSystem<T> {
    fn register_score(ref self: T, game_id: u32);
    fn get_leaderboard(self: @T, season_id: u32, count: u8) -> Array<(ContractAddress, u32)>;
}

#[dojo::contract]
pub mod season_v2 {
    use super::ISeasonSystem;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;

    use crate::models::player::Player;
    use crate::models::wallet::WalletState;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[dojo::model]
    #[derive(Copy, Drop, Serde)]
    pub struct LeaderboardEntry {
        #[key]
        pub season_id: u32,
        #[key]
        pub rank: u32,
        pub player_id: ContractAddress,
        pub score: u32,
    }

    #[dojo::model]
    #[derive(Copy, Drop, Serde)]
    pub struct LeaderboardSize {
        #[key]
        pub season_id: u32,
        pub count: u32,
    }

    #[abi(embed_v0)]
    impl SeasonSystemImpl of super::ISeasonSystem<ContractState> {

        fn register_score(ref self: ContractState, game_id: u32) {
            let mut world = self.world(ns());
            let caller = get_caller_address();
            let player: Player = world.read_model((game_id, caller));
            let wallet: WalletState = world.read_model((game_id, caller));

            assert(player.status == 4, 'game not finished'); // 4 = Finished
            let score = wallet.clean_cash;
            let season_id: u32 = 0; // default season for now

            // Get current leaderboard size
            let mut lb_size: LeaderboardSize = world.read_model(season_id);
            let new_rank = lb_size.count;
            lb_size.count = lb_size.count + 1;

            // Insert at end (simple append, sorted read on client side)
            let entry = LeaderboardEntry {
                season_id,
                rank: new_rank,
                player_id: caller,
                score,
            };
            world.write_model(@entry);
            world.write_model(@lb_size);
        }

        fn get_leaderboard(
            self: @ContractState,
            season_id: u32,
            count: u8,
        ) -> Array<(ContractAddress, u32)> {
            let world = self.world(ns());
            let lb_size: LeaderboardSize = world.read_model(season_id);
            let mut result: Array<(ContractAddress, u32)> = array![];
            let max = if lb_size.count < count.into() { lb_size.count } else { count.into() };
            let mut i: u32 = 0;
            while i < max {
                let entry: LeaderboardEntry = world.read_model((season_id, i));
                result.append((entry.player_id, entry.score));
                i += 1;
            };
            result
        }
    }
}
```

- [ ] **Step 2: Register and add writer permissions**

Add to lib.cairo systems block: `pub mod season_v2;`

Add to `dojo_cartel_dev.toml` writers:
```toml
"cartel_v0-LeaderboardEntry" = ["cartel_v0-season_v2"]
"cartel_v0-LeaderboardSize" = ["cartel_v0-season_v2"]
```

- [ ] **Step 3: Verify build**

Run: `scarb build`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/systems/season_v2.cairo src/lib.cairo dojo_cartel_dev.toml
git commit -m "feat: add season and leaderboard system — score registration and ranking"
```

---

## Task 14: Frontend — Dojo Integration Layer

**Files:**
- Create: `web/src/dojo/class/CartelGame.ts`
- Create: `web/src/dojo/class/CartelPlayer.ts`
- Create: `web/src/dojo/class/CartelInventory.ts`
- Create: `web/src/dojo/class/CartelMarket.ts`
- Create: `web/src/dojo/class/CartelHeat.ts`
- Create: `web/src/dojo/class/CartelReputation.ts`

- [ ] **Step 1: Create CartelGame class**

Create `web/src/dojo/class/CartelGame.ts`:

```typescript
export interface GameConfig {
  gameId: number;
  mode: number; // 0=Casual, 1=Ranked
  maxTurns: number;
  apPerTurn: number;
  startingDirtyCash: number;
  startingCleanCash: number;
  heatDecayRate: number;
  maxDealerSlots: number;
  seasonId: number;
}

export class CartelGame {
  config: GameConfig;
  isFinished: boolean;

  constructor(config: GameConfig) {
    this.config = config;
    this.isFinished = false;
  }

  static fromRaw(raw: any): CartelGame {
    return new CartelGame({
      gameId: Number(raw.game_id),
      mode: Number(raw.mode),
      maxTurns: Number(raw.max_turns),
      apPerTurn: Number(raw.ap_per_turn),
      startingDirtyCash: Number(raw.starting_dirty_cash),
      startingCleanCash: Number(raw.starting_clean_cash),
      heatDecayRate: Number(raw.heat_decay_rate),
      maxDealerSlots: Number(raw.max_dealer_slots),
      seasonId: Number(raw.season_id),
    });
  }
}
```

- [ ] **Step 2: Create CartelPlayer class**

Create `web/src/dojo/class/CartelPlayer.ts`:

```typescript
export enum PlayerStatus {
  Normal = 0,
  Jailed = 1,
  Hospitalized = 2,
  Dead = 3,
  Finished = 4,
}

export const LOCATION_NAMES: Record<number, string> = {
  0: "Home",
  1: "Queens",
  2: "Bronx",
  3: "Brooklyn",
  4: "Jersey City",
  5: "Central Park",
  6: "Coney Island",
};

export interface PlayerState {
  gameId: number;
  playerId: string;
  location: number;
  apRemaining: number;
  turn: number;
  maxTurns: number;
  status: PlayerStatus;
  score: number;
}

export class CartelPlayer {
  state: PlayerState;

  constructor(state: PlayerState) {
    this.state = state;
  }

  get locationName(): string {
    return LOCATION_NAMES[this.state.location] || "Unknown";
  }

  get isActive(): boolean {
    return this.state.status === PlayerStatus.Normal;
  }

  get turnsRemaining(): number {
    return Math.max(0, this.state.maxTurns - this.state.turn + 1);
  }

  static fromRaw(raw: any): CartelPlayer {
    return new CartelPlayer({
      gameId: Number(raw.game_id),
      playerId: raw.player_id,
      location: Number(raw.location),
      apRemaining: Number(raw.ap_remaining),
      turn: Number(raw.turn),
      maxTurns: Number(raw.max_turns),
      status: Number(raw.status) as PlayerStatus,
      score: Number(raw.score),
    });
  }
}
```

- [ ] **Step 3: Create CartelInventory class**

Create `web/src/dojo/class/CartelInventory.ts`:

```typescript
export const DRUG_NAMES: Record<number, string> = {
  0: "Empty",
  1: "Weed",
  2: "Shrooms",
  3: "Acid",
  4: "Ecstasy",
  5: "Speed",
  6: "Heroin",
  7: "Meth",
  8: "Cocaine",
};

export const EFFECT_NAMES: Record<number, string> = {
  0: "None",
  1: "Cut",
  2: "Energizing",
  3: "Potent",
  4: "Bulking",
  5: "Healthy",
  6: "Toxic",
  7: "Speedy",
  8: "Electric",
};

export interface DrugSlot {
  drugId: number;
  quantity: number;
  quality: number;
  effects: number[]; // up to 4 effect IDs
}

export class CartelInventory {
  slots: DrugSlot[];

  constructor(slots: DrugSlot[]) {
    this.slots = slots;
  }

  static unpackSlot(packed: bigint): DrugSlot {
    const drugId = Number(packed & 0xFFn);
    const quantity = Number((packed >> 8n) & 0xFFFFn);
    const quality = Number((packed >> 24n) & 0xFFn);
    const effectsPacked = Number((packed >> 32n) & 0xFFFFFFFFn);
    const effects = [
      effectsPacked & 0xFF,
      (effectsPacked >> 8) & 0xFF,
      (effectsPacked >> 16) & 0xFF,
      (effectsPacked >> 24) & 0xFF,
    ].filter(e => e !== 0);
    return { drugId, quantity, quality, effects };
  }

  static fromRaw(raw: any): CartelInventory {
    return new CartelInventory([
      CartelInventory.unpackSlot(BigInt(raw.slot_0)),
      CartelInventory.unpackSlot(BigInt(raw.slot_1)),
      CartelInventory.unpackSlot(BigInt(raw.slot_2)),
      CartelInventory.unpackSlot(BigInt(raw.slot_3)),
    ]);
  }

  get isEmpty(): boolean {
    return this.slots.every(s => s.drugId === 0);
  }

  getSlot(index: number): DrugSlot {
    return this.slots[index];
  }

  get filledSlots(): number {
    return this.slots.filter(s => s.drugId !== 0).length;
  }
}
```

- [ ] **Step 4: Create CartelMarket class**

Create `web/src/dojo/class/CartelMarket.ts`:

```typescript
import { DRUG_NAMES } from "./CartelInventory";

// Drug pricing config mirroring Cairo
const DRUG_CONFIGS: Record<number, { basePrice: number; priceStep: number }> = {
  1: { basePrice: 15, priceStep: 2 },   // Weed
  2: { basePrice: 30, priceStep: 4 },   // Shrooms
  3: { basePrice: 60, priceStep: 6 },   // Acid
  4: { basePrice: 100, priceStep: 10 }, // Ecstasy
  5: { basePrice: 200, priceStep: 15 }, // Speed
  6: { basePrice: 400, priceStep: 25 }, // Heroin
  7: { basePrice: 600, priceStep: 40 }, // Meth
  8: { basePrice: 1000, priceStep: 60 },// Cocaine
};

export interface DrugMarketInfo {
  drugId: number;
  name: string;
  priceTick: number;
  price: number;
  supply: number;
}

export class CartelMarket {
  locationId: number;
  drugs: DrugMarketInfo[];
  isVisible: boolean;

  constructor(locationId: number, drugs: DrugMarketInfo[], isVisible: boolean) {
    this.locationId = locationId;
    this.drugs = drugs;
    this.isVisible = isVisible;
  }

  static unpackPrices(packed: bigint, count: number = 8): number[] {
    const ticks: number[] = [];
    for (let i = 0; i < count; i++) {
      ticks.push(Number((packed >> BigInt(i * 16)) & 0xFFFFn));
    }
    return ticks;
  }

  static tickToPrice(drugId: number, tick: number): number {
    const config = DRUG_CONFIGS[drugId];
    if (!config) return 0;
    return config.basePrice + tick * config.priceStep;
  }

  static fromRaw(raw: any, playerIdx: number): CartelMarket {
    const locationId = Number(raw.location_id);
    const visibleTo = BigInt(raw.visible_to);
    const isVisible = (visibleTo & (1n << BigInt(playerIdx))) !== 0n;

    if (!isVisible) {
      return new CartelMarket(locationId, [], false);
    }

    const priceTicks = CartelMarket.unpackPrices(BigInt(raw.drug_prices));
    const supplies = CartelMarket.unpackPrices(BigInt(raw.drug_supply));

    const drugs: DrugMarketInfo[] = [];
    for (let i = 0; i < 8; i++) {
      const drugId = i + 1;
      drugs.push({
        drugId,
        name: DRUG_NAMES[drugId],
        priceTick: priceTicks[i],
        price: CartelMarket.tickToPrice(drugId, priceTicks[i]),
        supply: supplies[i],
      });
    }

    return new CartelMarket(locationId, drugs, true);
  }
}
```

- [ ] **Step 5: Create CartelHeat class**

Create `web/src/dojo/class/CartelHeat.ts`:

```typescript
export const HEAT_TIER_NAMES: Record<number, string> = {
  0: "None",
  1: "Surveillance",
  2: "Wanted",
  3: "Dead or Alive",
};

export const HEAT_TIER_COLORS: Record<number, string> = {
  0: "green.400",
  1: "yellow.400",
  2: "orange.400",
  3: "red.500",
};

export interface HeatState {
  tier: number;
  notoriety: number;
  locationHeat: number[]; // per location (6 values)
}

export class CartelHeat {
  state: HeatState;

  constructor(state: HeatState) {
    this.state = state;
  }

  get tierName(): string {
    return HEAT_TIER_NAMES[this.state.tier] || "Unknown";
  }

  get tierColor(): string {
    return HEAT_TIER_COLORS[this.state.tier] || "gray.400";
  }

  getLocationHeat(locationIdx: number): number {
    return this.state.locationHeat[locationIdx] || 0;
  }

  static fromRaw(raw: any): CartelHeat {
    const packed = BigInt(raw.location_heat);
    const locationHeat: number[] = [];
    for (let i = 0; i < 6; i++) {
      locationHeat.push(Number((packed >> BigInt(i * 8)) & 0xFFn));
    }
    return new CartelHeat({
      tier: Number(raw.tier),
      notoriety: Number(raw.notoriety),
      locationHeat,
    });
  }
}
```

- [ ] **Step 6: Create CartelReputation class**

Create `web/src/dojo/class/CartelReputation.ts`:

```typescript
export const BRANCH_NAMES = ["Trader", "Enforcer", "Operator"] as const;
export type BranchName = (typeof BRANCH_NAMES)[number];

export const LEVEL_THRESHOLDS = [100, 300, 600, 1000, 1500];

export interface ReputationState {
  traderXp: number;
  enforcerXp: number;
  operatorXp: number;
  traderLvl: number;
  enforcerLvl: number;
  operatorLvl: number;
}

export class CartelReputation {
  state: ReputationState;

  constructor(state: ReputationState) {
    this.state = state;
  }

  getXp(branch: BranchName): number {
    switch (branch) {
      case "Trader": return this.state.traderXp;
      case "Enforcer": return this.state.enforcerXp;
      case "Operator": return this.state.operatorXp;
    }
  }

  getLevel(branch: BranchName): number {
    switch (branch) {
      case "Trader": return this.state.traderLvl;
      case "Enforcer": return this.state.enforcerLvl;
      case "Operator": return this.state.operatorLvl;
    }
  }

  getNextThreshold(branch: BranchName): number {
    const lvl = this.getLevel(branch);
    if (lvl >= 5) return Infinity;
    return LEVEL_THRESHOLDS[lvl];
  }

  getProgress(branch: BranchName): number {
    const xp = this.getXp(branch);
    const next = this.getNextThreshold(branch);
    if (next === Infinity) return 1;
    const prev = this.getLevel(branch) > 0 ? LEVEL_THRESHOLDS[this.getLevel(branch) - 1] : 0;
    return (xp - prev) / (next - prev);
  }

  static fromRaw(raw: any): CartelReputation {
    return new CartelReputation({
      traderXp: Number(raw.trader_xp),
      enforcerXp: Number(raw.enforcer_xp),
      operatorXp: Number(raw.operator_xp),
      traderLvl: Number(raw.trader_lvl),
      enforcerLvl: Number(raw.enforcer_lvl),
      operatorLvl: Number(raw.operator_lvl),
    });
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add web/src/dojo/class/Cartel*.ts
git commit -m "feat: add frontend domain classes — Game, Player, Inventory, Market, Heat, Reputation"
```

---

## Task 15: Frontend — Contract Hook (useCartelSystems)

**Files:**
- Create: `web/src/dojo/hooks/useCartelSystems.ts`
- Create: `web/src/dojo/hooks/useCartelGame.ts`

- [ ] **Step 1: Create useCartelSystems hook**

Create `web/src/dojo/hooks/useCartelSystems.ts`:

```typescript
import { useCallback } from "react";
import { useDojo } from "../context/DojoContext";
import { poseidonHashMany } from "@scure/starknet";

export interface ActionInput {
  actionType: number;
  targetLocation: number;
  drugId: number;
  quantity: number;
  ingredientId: number;
  slotIndex: number;
}

function packAction(action: ActionInput): bigint {
  return (
    BigInt(action.actionType) +
    BigInt(action.targetLocation) * 0x100n +
    BigInt(action.drugId) * 0x10000n +
    BigInt(action.quantity) * 0x1000000n +
    BigInt(action.ingredientId) * 0x10000000000n +
    BigInt(action.slotIndex) * 0x1000000000000n
  );
}

function hashActions(actions: ActionInput[], salt: bigint): bigint {
  const inputs = [salt, ...actions.map(packAction)];
  return poseidonHashMany(inputs);
}

export function useCartelSystems() {
  const { account, setup } = useDojo();

  const createGame = useCallback(
    async (mode: number, playerName: string) => {
      const tx = await account.execute([
        {
          contractAddress: setup.contracts.cartel_game,
          entrypoint: "create_game",
          calldata: [mode, playerName],
        },
      ]);
      return tx;
    },
    [account, setup],
  );

  const commitActions = useCallback(
    async (gameId: number, actions: ActionInput[], salt: bigint) => {
      const actionHash = hashActions(actions, salt);
      const totalAp = actions.reduce((sum, a) => {
        // Simplified AP calc — actual cost depends on adjacency
        const cost = a.actionType === 4 || a.actionType === 8 ? 2 : 1; // Mix=4, Rest=8
        return sum + cost;
      }, 0);

      const tx = await account.execute([
        {
          contractAddress: setup.contracts.cartel_game,
          entrypoint: "commit_actions",
          calldata: [gameId, actionHash.toString(), totalAp],
        },
      ]);
      return { tx, salt, actions };
    },
    [account, setup],
  );

  const revealResolve = useCallback(
    async (gameId: number, actions: ActionInput[], salt: bigint) => {
      // Serialize actions as flat calldata
      const actionsCalldata = actions.flatMap((a) => [
        a.actionType,
        a.targetLocation,
        a.drugId,
        a.quantity,
        a.ingredientId,
        a.slotIndex,
      ]);

      const tx = await account.execute([
        {
          contractAddress: setup.contracts.cartel_game,
          entrypoint: "reveal_resolve",
          calldata: [gameId, actions.length, ...actionsCalldata, salt.toString()],
        },
      ]);
      return tx;
    },
    [account, setup],
  );

  const endGame = useCallback(
    async (gameId: number) => {
      const tx = await account.execute([
        {
          contractAddress: setup.contracts.cartel_game,
          entrypoint: "end_game",
          calldata: [gameId],
        },
      ]);
      return tx;
    },
    [account, setup],
  );

  return { createGame, commitActions, revealResolve, endGame };
}
```

- [ ] **Step 2: Create useCartelGame hook**

Create `web/src/dojo/hooks/useCartelGame.ts`:

```typescript
import { useState, useEffect } from "react";
import { useDojo } from "../context/DojoContext";
import { CartelPlayer } from "../class/CartelPlayer";
import { CartelInventory } from "../class/CartelInventory";
import { CartelHeat } from "../class/CartelHeat";
import { CartelReputation } from "../class/CartelReputation";
import { CartelMarket } from "../class/CartelMarket";

export interface CartelGameState {
  player: CartelPlayer | null;
  inventory: CartelInventory | null;
  wallet: { dirtyCash: number; cleanCash: number } | null;
  heat: CartelHeat | null;
  reputation: CartelReputation | null;
  markets: CartelMarket[];
  loading: boolean;
}

export function useCartelGame(gameId: number | null): CartelGameState {
  const { setup } = useDojo();
  const [state, setState] = useState<CartelGameState>({
    player: null,
    inventory: null,
    wallet: null,
    heat: null,
    reputation: null,
    markets: [],
    loading: true,
  });

  useEffect(() => {
    if (!gameId || !setup.toriiClient) {
      setState((prev) => ({ ...prev, loading: false }));
      return;
    }

    // Subscribe to Torii entity updates for this game
    // This is a simplified version — actual implementation uses
    // setup.toriiClient.onEntityUpdated() with the game_id filter

    const fetchState = async () => {
      try {
        // Query via Torii GraphQL — exact query depends on generated types
        // Placeholder: direct model reads would use setup.toriiClient
        setState((prev) => ({ ...prev, loading: false }));
      } catch (err) {
        console.error("Failed to fetch cartel game state:", err);
        setState((prev) => ({ ...prev, loading: false }));
      }
    };

    fetchState();
  }, [gameId, setup.toriiClient]);

  return state;
}
```

- [ ] **Step 3: Commit**

```bash
git add web/src/dojo/hooks/useCartelSystems.ts web/src/dojo/hooks/useCartelGame.ts
git commit -m "feat: add frontend hooks — useCartelSystems for contract calls, useCartelGame for state"
```

---

## Task 16: Frontend — Game Pages (Lobby, Main Game, Trade, Mix)

**Files:**
- Create: `web/src/pages/cartel/index.tsx`
- Create: `web/src/pages/cartel/[gameId]/index.tsx`
- Create: `web/src/components/cartel/ActionBar.tsx`
- Create: `web/src/components/cartel/LocationMap.tsx`
- Create: `web/src/components/cartel/InventoryPanel.tsx`
- Create: `web/src/components/cartel/MarketTable.tsx`
- Create: `web/src/components/cartel/HeatMeter.tsx`
- Create: `web/src/components/cartel/MixingStation.tsx`

- [ ] **Step 1: Create game lobby page**

Create `web/src/pages/cartel/index.tsx`:

```tsx
import { useState } from "react";
import { Box, Button, Heading, VStack, HStack, Select, Input } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { useCartelSystems } from "../../dojo/hooks/useCartelSystems";

export default function CartelLobby() {
  const router = useRouter();
  const { createGame } = useCartelSystems();
  const [mode, setMode] = useState(0);
  const [playerName, setPlayerName] = useState("");
  const [creating, setCreating] = useState(false);

  const handleCreate = async () => {
    setCreating(true);
    try {
      const tx = await createGame(mode, playerName || "Anonymous");
      // Parse game_id from tx events — simplified
      // For now, redirect to game list or wait for indexer
      router.push("/cartel/0"); // placeholder
    } catch (err) {
      console.error(err);
    }
    setCreating(false);
  };

  return (
    <Box p={8} maxW="600px" mx="auto">
      <Heading mb={6}>Cartel Empire</Heading>
      <VStack spacing={4} align="stretch">
        <Input
          placeholder="Player Name"
          value={playerName}
          onChange={(e) => setPlayerName(e.target.value)}
        />
        <Select value={mode} onChange={(e) => setMode(Number(e.target.value))}>
          <option value={0}>Casual (25 turns, 4 AP)</option>
          <option value={1}>Ranked (60 turns, 3 AP)</option>
        </Select>
        <Button
          colorScheme="red"
          onClick={handleCreate}
          isLoading={creating}
          size="lg"
        >
          Start Game
        </Button>
      </VStack>
    </Box>
  );
}
```

- [ ] **Step 2: Create main game page**

Create `web/src/pages/cartel/[gameId]/index.tsx`:

```tsx
import { useRouter } from "next/router";
import { Box, Grid, GridItem, Heading } from "@chakra-ui/react";
import { useCartelGame } from "../../../dojo/hooks/useCartelGame";
import ActionBar from "../../../components/cartel/ActionBar";
import LocationMap from "../../../components/cartel/LocationMap";
import InventoryPanel from "../../../components/cartel/InventoryPanel";
import MarketTable from "../../../components/cartel/MarketTable";
import HeatMeter from "../../../components/cartel/HeatMeter";

export default function CartelGamePage() {
  const router = useRouter();
  const gameId = router.query.gameId ? Number(router.query.gameId) : null;
  const { player, inventory, wallet, heat, reputation, markets, loading } =
    useCartelGame(gameId);

  if (loading) return <Box p={8}>Loading...</Box>;
  if (!player) return <Box p={8}>Game not found</Box>;

  return (
    <Box p={4}>
      <Grid templateColumns="1fr 300px" gap={4}>
        <GridItem>
          <Heading size="md" mb={2}>
            Turn {player.state.turn} / {player.state.maxTurns} — {player.locationName}
          </Heading>
          <LocationMap
            currentLocation={player.state.location}
            markets={markets}
          />
          <MarketTable
            markets={markets}
            currentLocation={player.state.location}
          />
        </GridItem>
        <GridItem>
          <ActionBar
            apRemaining={player.state.apRemaining}
            dirtyCash={wallet?.dirtyCash ?? 0}
            cleanCash={wallet?.cleanCash ?? 0}
          />
          <InventoryPanel inventory={inventory} />
          <HeatMeter heat={heat} />
        </GridItem>
      </Grid>
    </Box>
  );
}
```

- [ ] **Step 3: Create ActionBar component**

Create `web/src/components/cartel/ActionBar.tsx`:

```tsx
import { Box, HStack, Text, Badge, VStack } from "@chakra-ui/react";

interface ActionBarProps {
  apRemaining: number;
  dirtyCash: number;
  cleanCash: number;
}

export default function ActionBar({ apRemaining, dirtyCash, cleanCash }: ActionBarProps) {
  return (
    <Box bg="gray.800" p={4} borderRadius="md" mb={4}>
      <VStack align="stretch" spacing={2}>
        <HStack justify="space-between">
          <Text fontWeight="bold">AP</Text>
          <HStack>
            {Array.from({ length: 4 }).map((_, i) => (
              <Badge
                key={i}
                colorScheme={i < apRemaining ? "green" : "gray"}
                fontSize="lg"
                px={2}
              >
                {i < apRemaining ? "●" : "○"}
              </Badge>
            ))}
          </HStack>
        </HStack>
        <HStack justify="space-between">
          <Text color="red.300">Dirty $</Text>
          <Text>{dirtyCash.toLocaleString()}</Text>
        </HStack>
        <HStack justify="space-between">
          <Text color="green.300">Clean $</Text>
          <Text>{cleanCash.toLocaleString()}</Text>
        </HStack>
      </VStack>
    </Box>
  );
}
```

- [ ] **Step 4: Create LocationMap component**

Create `web/src/components/cartel/LocationMap.tsx`:

```tsx
import { Box, SimpleGrid, Button, Text, Badge } from "@chakra-ui/react";
import { LOCATION_NAMES } from "../../dojo/class/CartelPlayer";
import { CartelMarket } from "../../dojo/class/CartelMarket";

interface LocationMapProps {
  currentLocation: number;
  markets: CartelMarket[];
}

export default function LocationMap({ currentLocation, markets }: LocationMapProps) {
  const locations = [1, 2, 3, 4, 5, 6];

  return (
    <Box mb={4}>
      <Text fontWeight="bold" mb={2}>Locations</Text>
      <SimpleGrid columns={3} spacing={2}>
        {locations.map((locId) => {
          const market = markets.find((m) => m.locationId === locId);
          const isCurrent = locId === currentLocation;
          return (
            <Button
              key={locId}
              variant={isCurrent ? "solid" : "outline"}
              colorScheme={isCurrent ? "blue" : market?.isVisible ? "gray" : "blackAlpha"}
              size="sm"
              height="60px"
              flexDir="column"
            >
              <Text fontSize="xs">{LOCATION_NAMES[locId]}</Text>
              {!market?.isVisible && <Badge colorScheme="purple" fontSize="xx-small">FOG</Badge>}
              {isCurrent && <Badge colorScheme="blue" fontSize="xx-small">HERE</Badge>}
            </Button>
          );
        })}
      </SimpleGrid>
    </Box>
  );
}
```

- [ ] **Step 5: Create InventoryPanel component**

Create `web/src/components/cartel/InventoryPanel.tsx`:

```tsx
import { Box, VStack, HStack, Text, Badge } from "@chakra-ui/react";
import { CartelInventory, DRUG_NAMES, EFFECT_NAMES } from "../../dojo/class/CartelInventory";

interface InventoryPanelProps {
  inventory: CartelInventory | null;
}

export default function InventoryPanel({ inventory }: InventoryPanelProps) {
  if (!inventory) return null;

  return (
    <Box bg="gray.800" p={4} borderRadius="md" mb={4}>
      <Text fontWeight="bold" mb={2}>Inventory ({inventory.filledSlots}/4)</Text>
      <VStack align="stretch" spacing={2}>
        {inventory.slots.map((slot, i) => (
          <Box key={i} bg="gray.700" p={2} borderRadius="sm">
            {slot.drugId === 0 ? (
              <Text color="gray.500" fontSize="sm">Empty Slot</Text>
            ) : (
              <VStack align="stretch" spacing={1}>
                <HStack justify="space-between">
                  <Text fontSize="sm" fontWeight="bold">{DRUG_NAMES[slot.drugId]}</Text>
                  <Text fontSize="sm">x{slot.quantity}</Text>
                </HStack>
                {slot.effects.length > 0 && (
                  <HStack flexWrap="wrap">
                    {slot.effects.map((eid, j) => (
                      <Badge key={j} colorScheme="purple" fontSize="xx-small">
                        {EFFECT_NAMES[eid]}
                      </Badge>
                    ))}
                  </HStack>
                )}
              </VStack>
            )}
          </Box>
        ))}
      </VStack>
    </Box>
  );
}
```

- [ ] **Step 6: Create MarketTable component**

Create `web/src/components/cartel/MarketTable.tsx`:

```tsx
import { Box, Table, Thead, Tbody, Tr, Th, Td, Text, Badge } from "@chakra-ui/react";
import { CartelMarket } from "../../dojo/class/CartelMarket";
import { LOCATION_NAMES } from "../../dojo/class/CartelPlayer";

interface MarketTableProps {
  markets: CartelMarket[];
  currentLocation: number;
}

export default function MarketTable({ markets, currentLocation }: MarketTableProps) {
  const currentMarket = markets.find((m) => m.locationId === currentLocation);

  if (!currentMarket || !currentMarket.isVisible) {
    return (
      <Box bg="gray.800" p={4} borderRadius="md">
        <Text color="gray.500">Market data unavailable — scout this location first</Text>
      </Box>
    );
  }

  return (
    <Box bg="gray.800" p={4} borderRadius="md">
      <Text fontWeight="bold" mb={2}>
        Market — {LOCATION_NAMES[currentLocation]}
      </Text>
      <Table size="sm" variant="simple">
        <Thead>
          <Tr>
            <Th>Drug</Th>
            <Th isNumeric>Price</Th>
            <Th isNumeric>Supply</Th>
          </Tr>
        </Thead>
        <Tbody>
          {currentMarket.drugs.map((drug) => (
            <Tr key={drug.drugId}>
              <Td>{drug.name}</Td>
              <Td isNumeric>${drug.price}</Td>
              <Td isNumeric>
                <Badge colorScheme={drug.supply > 50 ? "green" : drug.supply > 20 ? "yellow" : "red"}>
                  {drug.supply}
                </Badge>
              </Td>
            </Tr>
          ))}
        </Tbody>
      </Table>
    </Box>
  );
}
```

- [ ] **Step 7: Create HeatMeter component**

Create `web/src/components/cartel/HeatMeter.tsx`:

```tsx
import { Box, HStack, Text, Progress } from "@chakra-ui/react";
import { CartelHeat, HEAT_TIER_NAMES, HEAT_TIER_COLORS } from "../../dojo/class/CartelHeat";

interface HeatMeterProps {
  heat: CartelHeat | null;
}

export default function HeatMeter({ heat }: HeatMeterProps) {
  if (!heat) return null;

  const maxNotoriety = 100; // DOA threshold
  const progress = Math.min((heat.state.notoriety / maxNotoriety) * 100, 100);

  return (
    <Box bg="gray.800" p={4} borderRadius="md" mb={4}>
      <HStack justify="space-between" mb={2}>
        <Text fontWeight="bold">Heat</Text>
        <Text color={heat.tierColor} fontWeight="bold">{heat.tierName}</Text>
      </HStack>
      <Progress
        value={progress}
        colorScheme={heat.state.tier >= 3 ? "red" : heat.state.tier >= 2 ? "orange" : heat.state.tier >= 1 ? "yellow" : "green"}
        size="sm"
        borderRadius="full"
      />
      <Text fontSize="xs" color="gray.500" mt={1}>
        Notoriety: {heat.state.notoriety} / {maxNotoriety}
      </Text>
    </Box>
  );
}
```

- [ ] **Step 8: Create MixingStation component**

Create `web/src/components/cartel/MixingStation.tsx`:

```tsx
import { Box, VStack, HStack, Text, Button, Select } from "@chakra-ui/react";
import { useState } from "react";
import { CartelInventory, DRUG_NAMES, EFFECT_NAMES } from "../../dojo/class/CartelInventory";

const INGREDIENTS = [
  { id: 1, name: "Baking Soda", effect: "Cut", cost: 5 },
  { id: 2, name: "Caffeine Pills", effect: "Energizing", cost: 10 },
  { id: 3, name: "Acetone", effect: "Potent", cost: 20 },
  { id: 4, name: "Laxatives", effect: "Bulking", cost: 8 },
  { id: 5, name: "Vitamin Powder", effect: "Healthy", cost: 12 },
  { id: 6, name: "Methanol", effect: "Toxic", cost: 30 },
  { id: 7, name: "Ephedrine", effect: "Speedy", cost: 40 },
  { id: 8, name: "Lithium", effect: "Electric", cost: 50 },
];

interface MixingStationProps {
  inventory: CartelInventory | null;
  onMix: (slotIndex: number, ingredientId: number) => void;
}

export default function MixingStation({ inventory, onMix }: MixingStationProps) {
  const [selectedSlot, setSelectedSlot] = useState(0);
  const [selectedIngredient, setSelectedIngredient] = useState(1);

  if (!inventory) return null;

  const slot = inventory.getSlot(selectedSlot);
  const canMix = slot.drugId !== 0 && slot.effects.length < 4;

  return (
    <Box bg="gray.800" p={4} borderRadius="md" mb={4}>
      <Text fontWeight="bold" mb={2}>Mixing Station (2 AP)</Text>
      <VStack align="stretch" spacing={3}>
        <Select
          value={selectedSlot}
          onChange={(e) => setSelectedSlot(Number(e.target.value))}
          size="sm"
        >
          {inventory.slots.map((s, i) => (
            <option key={i} value={i}>
              Slot {i + 1}: {s.drugId === 0 ? "Empty" : `${DRUG_NAMES[s.drugId]} x${s.quantity}`}
            </option>
          ))}
        </Select>
        <Select
          value={selectedIngredient}
          onChange={(e) => setSelectedIngredient(Number(e.target.value))}
          size="sm"
        >
          {INGREDIENTS.map((ing) => (
            <option key={ing.id} value={ing.id}>
              {ing.name} (+{ing.effect}) — ${ing.cost}
            </option>
          ))}
        </Select>
        {slot.effects.length > 0 && (
          <HStack flexWrap="wrap">
            <Text fontSize="xs" color="gray.400">Current:</Text>
            {slot.effects.map((eid, j) => (
              <Text key={j} fontSize="xs" color="purple.300">{EFFECT_NAMES[eid]}</Text>
            ))}
          </HStack>
        )}
        <Button
          colorScheme="purple"
          size="sm"
          onClick={() => onMix(selectedSlot, selectedIngredient)}
          isDisabled={!canMix}
        >
          Mix
        </Button>
      </VStack>
    </Box>
  );
}
```

- [ ] **Step 9: Commit**

```bash
git add web/src/pages/cartel/ web/src/components/cartel/
git commit -m "feat: add frontend pages and components — lobby, game view, inventory, market, heat, mixing"
```

---

## Task 17: Local Dev Environment Verification

**Files:**
- No new files — verification task

- [ ] **Step 1: Start Katana local devnet**

Run in a terminal:
```bash
katana --config katana_cartel_dev.toml
```
Expected: Katana starts on port 5050

- [ ] **Step 2: Build and migrate contracts**

Run:
```bash
scarb build
sozo --profile cartel_dev migrate
```
Expected: All contracts and models deployed to local Katana. World address printed.

- [ ] **Step 3: Update world address in configs**

Copy the world address from migration output into `dojo_cartel_dev.toml` and `torii_cartel_dev.toml`.

- [ ] **Step 4: Start Torii indexer**

Run in another terminal:
```bash
torii --config torii_cartel_dev.toml
```
Expected: Torii starts, begins indexing from world address

- [ ] **Step 5: Start frontend**

Run:
```bash
cd web && pnpm dev
```
Expected: Next.js starts on localhost:3000

- [ ] **Step 6: Smoke test**

Open `http://localhost:3000/cartel` in a browser. Verify the lobby page renders.

- [ ] **Step 7: Commit any config fixes**

```bash
git add -A
git commit -m "fix: update configs for local dev environment"
```

---

## Task 18: Integration Test — Full Game Loop

**Files:**
- Create: `src/tests/test_integration.cairo`

- [ ] **Step 1: Write integration test**

Create `src/tests/test_integration.cairo`:

```cairo
// This test exercises the full game loop through helper functions
// (full contract integration tests require Dojo test harness)

use rollyourown::systems::helpers::action_executor::{validate_action_batch};
use rollyourown::systems::helpers::market_helpers::{
    calculate_buy_price, calculate_sell_price,
};
use rollyourown::systems::helpers::encounter_helpers::{
    should_trigger_encounter, resolve_encounter, calculate_crew_power,
    calculate_threat, EncounterOutcome,
};
use rollyourown::systems::helpers::mixing_helpers::{apply_ingredient, count_effects};
use rollyourown::utils::action_hash::{hash_actions, verify_action_hash};
use rollyourown::types::action_types::{Action, ActionType};
use rollyourown::config::heat_config::notoriety_to_tier;
use rollyourown::models::heat::{get_location_heat, set_location_heat};

#[test]
fn test_full_game_loop_simulation() {
    // === Turn 1: Travel to Bronx, Buy Weed ===
    let actions_t1: Array<Action> = array![
        Action { action_type: ActionType::Travel, target_location: 2, drug_id: 0, quantity: 0, ingredient_id: 0, slot_index: 0 },
        Action { action_type: ActionType::Buy, target_location: 0, drug_id: 1, quantity: 20, ingredient_id: 0, slot_index: 0 },
        Action { action_type: ActionType::Scout, target_location: 3, drug_id: 0, quantity: 0, ingredient_id: 0, slot_index: 0 },
    ];
    assert(validate_action_batch(actions_t1.span(), 1, 3), 'T1 valid'); // start Queens, 3 AP

    // Verify buy price: Weed at tick 32 = 15 + 32*2 = 79
    let buy_price = calculate_buy_price(1, 32);
    assert(buy_price == 79, 'weed price at tick 32');

    // === Turn 2: Mix, then Sell ===
    // Mix adds Energizing effect
    let effects_before: u32 = 0;
    let effects_after = apply_ingredient(effects_before, 2); // Energizing
    assert(count_effects(effects_after) == 1, 'has 1 effect');

    // Sell price with effect: 79 * (100 + 22) / 100 = 96
    let sell_price = calculate_sell_price(1, 32, effects_after);
    assert(sell_price == 96, 'weed+energizing sell price');

    // === Heat escalation ===
    let mut notoriety: u16 = 0;
    notoriety = notoriety + 3; // sell
    notoriety = notoriety + 3; // sell again
    notoriety = notoriety + 2; // travel with drugs
    assert(notoriety_to_tier(notoriety) == 0, 'still tier 0 at 8 notoriety');

    notoriety = 25; // past surveillance threshold
    assert(notoriety_to_tier(notoriety) == 1, 'tier 1 at 25');

    // === Encounter at tier 1, low danger ===
    // roll=2 < 5 (surveillance rate) = triggers
    assert(should_trigger_encounter(1, 5, 2), 'encounter triggers');
    // roll=10 > 5 = no trigger
    assert(!should_trigger_encounter(1, 5, 10), 'no encounter high roll');

    // === Location heat packing ===
    let mut loc_heat: u64 = 0;
    loc_heat = set_location_heat(loc_heat, 1, 15); // Bronx = 15
    loc_heat = set_location_heat(loc_heat, 4, 8);  // CentralPark = 8
    assert(get_location_heat(loc_heat, 1) == 15, 'bronx heat');
    assert(get_location_heat(loc_heat, 4) == 8, 'cp heat');
    assert(get_location_heat(loc_heat, 0) == 0, 'queens untouched');

    // === Commit-reveal ===
    let salt: felt252 = 42;
    let hash = hash_actions(actions_t1.span(), salt);
    assert(verify_action_hash(actions_t1.span(), salt, hash), 'commit-reveal works');
}
```

- [ ] **Step 2: Register test module**

Add `test_integration` to tests block in lib.cairo.

- [ ] **Step 3: Run full test suite**

Run: `scarb test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add src/tests/test_integration.cairo src/lib.cairo
git commit -m "test: add integration test — full game loop simulation through helpers"
```

---

## Summary

| Task | Component | Files | Estimated Steps |
|------|-----------|-------|----------------|
| 1 | Dojo World Setup | 5 | 7 |
| 2 | Core Types | 6 | 9 |
| 3 | Player/Inventory/Wallet/Heat/Rep Models | 6 | 8 |
| 4 | Market/Location/Config Models | 8 | 10 |
| 5 | Action Hash (Commit-Reveal) | 2 | 6 |
| 6 | Market Helpers | 2 | 6 |
| 7 | Encounter Helpers | 2 | 6 |
| 8 | Mixing Helpers | 3 | 7 |
| 9 | Heat System Tests | 1 | 6 |
| 10 | Action Executor | 2 | 6 |
| 11 | Main Game Contract | 2 | 8 |
| 12 | Market System Contract | 1 | 4 |
| 13 | Season & Leaderboard | 1 | 4 |
| 14 | Frontend Domain Classes | 6 | 7 |
| 15 | Frontend Hooks | 2 | 3 |
| 16 | Frontend Pages & Components | 8 | 9 |
| 17 | Local Dev Verification | 0 | 7 |
| 18 | Integration Test | 1 | 4 |
| **Total** | | **58 files** | **117 steps** |
