# DopeWars → Cartel Empire: Game Revamp Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Approach:** Clean Room (Approach B) — New contracts, reuse Dojo/VRF/Torii infrastructure

---

## Table of Contents

1. [Vision](#1-vision)
2. [Architecture Overview](#2-architecture-overview)
3. [Design Decisions](#3-design-decisions)
4. [ECS Data Models](#4-ecs-data-models)
5. [Core Game Loop](#5-core-game-loop)
6. [Game Systems](#6-game-systems)
7. [Agent API](#7-agent-api)
8. [Three-Stage Development Plan](#8-three-stage-development-plan)
9. [Workstream Parallelization](#9-workstream-parallelization)
10. [Future Extensibility](#10-future-extensibility)

---

## 1. Vision

Revamp the existing DopeWars on-chain game into a **drug cartel empire game** where both humans and AI agents participate. Inspired by Schedule 1's empire-building mechanics, adapted for on-chain play with a hybrid turn-based/real-time model.

**Core thesis:** Agent slots are a universal interface — NPC, AI agent, or human player all implement the same contract. This makes multiplayer an extension, not a rewrite.

**Key differentiators from current DopeWars:**
- Multi-drug inventory (4 slots vs 1)
- Drug mixing with modifier stacking
- Dealer networks via agent slots
- Fog of war (no full market observability)
- Dirty/clean cash economy with laundering operations
- Branching reputation trees (Trader/Enforcer/Operator)
- Escalating law enforcement tiers
- Simultaneous human + AI agent play

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Next.js)                     │
│  Human UI  ←──────→  Game State Store  ←──────→  Agent API│
│  (React)              (MobX/Zustand)            (REST/WS) │
└──────────┬──────────────────┬──────────────┬─────────────┘
           │                  │              │
           ▼                  ▼              ▼
┌─────────────────────────────────────────────────────────┐
│                   TORII INDEXER (GraphQL + WS)            │
│  Real-time subscriptions │ Query API │ Event streaming    │
└──────────────────────────┬───────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                STARKNET (Dojo World)                      │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ GAME SYSTEM  │  │ MARKET SYSTEM│  │ RESOLVE SYSTEM │  │
│  │ create_game  │  │ price_engine │  │ commit_actions │  │
│  │ end_game     │  │ fog_query    │  │ reveal_resolve │  │
│  │ join_slot    │  │ supply_drain │  │ vrf_callback   │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ CARTEL SYS  │  │ ENCOUNTER SYS│  │ SEASON SYSTEM  │  │
│  │ hire_slot   │  │ heat_update  │  │ leaderboard    │  │
│  │ set_strategy│  │ auto_resolve │  │ rewards        │  │
│  │ collect     │  │ escalate_tier│  │ config_modes   │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐                       │
│  │ MIXING SYS  │  │ LAUNDER SYS  │   + Cartridge VRF    │
│  │ mix_product │  │ invest_op    │   + Cartridge Wallet  │
│  │ effects_calc│  │ clean_cash   │                       │
│  └─────────────┘  └──────────────┘                       │
│                                                           │
│  ┌───────────────────────────────────────────────────┐   │
│  │              ECS DATA MODELS                       │   │
│  │  Player │ Inventory │ Market │ Dealer │ Location   │   │
│  │  Heat   │ Reputation│ Cartel │ Season │ Contract   │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Key architectural principles:**
- Every system is a separate Dojo contract — swap or upgrade individually
- Agent slots are a first-class ECS entity, not a bolted-on feature
- Fog of war enforced at the contract level (can't query prices you haven't scouted)
- Commit-reveal flow: `commit_actions(game_id, encrypted_actions)` → VRF callback → `reveal_resolve(game_id, actions, vrf_seed)` posts outcomes
- All systems designed for future customization — replace any system without rewriting others

---

## 3. Design Decisions

| Decision | Choice | Future Extension |
|----------|--------|------------------|
| Core model | Hybrid (turn-based on-chain, real-time off-chain) | — |
| Empire scope | Cartel Network (abstracted operations) | — |
| On-chain split | Commit-reveal | — |
| Human/Agent model | Fog of war competitive + agent-as-teammate coop | — |
| Mixing | Modifier stacking (B) | Full combinatorial (C) in Stage 3 |
| Economy | Dual currency (dirty/clean) virtual token | Real token + multi-asset in future |
| Multiplayer | Shared market, separate empires | Cartel alliances in Stage 3 |
| Map | 6 NYC locations | Fictional city + international in Stage 3 |
| Turns | Action points (3-4 AP) | Phase-based turns (C) in future |
| Progression | Branching reputation trees | — |
| Dealers/Crew | Agent slots (universal interface) | — |
| Heat | Escalating enforcement tiers (4 levels) | — |
| Game length | Configurable (Casual/Ranked/Endless) | — |
| Combat | Auto-resolve based on crew investment | — |
| Fog of war | Full fog | Tiered visibility in Stage 3 |
| Launch target | Simultaneous human + agent | — |
| Dev approach | AI-agent built (weeks not months) | — |
| Architecture | Clean Room (new contracts, reuse infra) | Dojo world portable to other chains |

---

## 4. ECS Data Models

### Entity Relationships

```
Player ──────┐
  │          │
  ├── Inventory (multi-drug, up to 4 slots)
  ├── Reputation (3 branches: Trader/Enforcer/Operator)
  ├── WalletState (dirty_cash, clean_cash)
  ├── HeatProfile (global_notoriety + per-location heat)
  │
  ├──owns──→ Cartel ──────┐
  │                       ├── AgentSlot[] (up to 6 slots)
  │                       ├── Operations[] (laundering biz)
  │                       └── Stash (cross-turn storage)
  │
  └──plays──→ Game ───────┐
                          ├── Season (settings, mode, rewards)
                          ├── Market[] (per-location pricing)
                          └── LocationState[] (supply, events)

AgentSlot ────┐
  ├── slot_type (Dealer/Cook/Runner/Muscle)
  ├── controller (NPC | agent_address | player_address)
  ├── strategy (aggressive/cautious/custom)
  ├── stats (reliability, stealth, salesmanship)
  ├── assigned_location
  ├── inventory (product they're holding)
  └── status (active/busted/laying_low/betrayed)
```

### Core Components (Cairo structs)

#### Player
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| game_id | u32 | 32 | Game instance ID |
| player_id | felt252 | 252 | Player wallet address |
| location | u8 | 8 | Current location (0-6) |
| ap_remaining | u8 | 8 | Action points left this turn |
| turn | u16 | 16 | Current turn number |
| status | u8 | 8 | Active/Jailed/Hospitalized/Dead |
| **Total** | | **~80** | |

#### Inventory (4 drug slots)
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| drug_id | u8 | 8 | Drug type identifier |
| quantity | u16 | 16 | Amount held |
| quality | u8 | 8 | Quality tier |
| effects | u32 | 32 | Packed 4 effects × 8-bit IDs |
| **Per slot** | | **64** | |
| **Total (4 slots)** | | **256** | |

Inventory uses 256 bits total (4 × 64). Fits in 2 felt252 values alongside Player fields (Player 80 + Inventory 256 + Wallet 64 + Reputation 72 + Heat 72 = 544 bits = 3 felt252).

#### WalletState
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| dirty_cash | u32 | 32 | Unprocessed earnings |
| clean_cash | u32 | 32 | Laundered cash (score) |
| **Total** | | **64** | |

#### Reputation
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| trader_xp | u16 | 16 | XP in Trader branch |
| enforcer_xp | u16 | 16 | XP in Enforcer branch |
| operator_xp | u16 | 16 | XP in Operator branch |
| trader_lvl | u8 | 8 | Current Trader level |
| enforcer_lvl | u8 | 8 | Current Enforcer level |
| operator_lvl | u8 | 8 | Current Operator level |
| **Total** | | **72** | |

#### HeatProfile
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| tier | u8 | 8 | Enforcement tier (0-3) |
| notoriety | u16 | 16 | Global notoriety score |
| location_heat | u48 | 48 | Packed 6 locations × 8-bit heat |
| **Total** | | **72** | |

#### Market (per location)
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| location_id | u8 | 8 | Location identifier |
| drug_prices | u128 | 128 | Packed 8 drugs × 16-bit ticks |
| drug_supply | u128 | 128 | Packed 8 drugs × 16-bit quantity |
| last_event | u8 | 8 | Current market event |
| visible_to | felt252 | 252 | Bitmask: who has scouted |
| **Total** | | **~280** | 1 felt252 per location |

#### AgentSlot
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| slot_id | u8 | 8 | Slot identifier |
| cartel_id | u32 | 32 | Owning cartel |
| slot_type | u8 | 8 | Dealer/Cook/Runner/Muscle |
| controller_type | u8 | 8 | NPC/Agent/Human |
| controller_addr | felt252 | 252 | Controller wallet/contract |
| strategy | u8 | 8 | Behavioral preset |
| stats | u32 | 32 | Packed (reliability, stealth, salesmanship, combat) |
| location | u8 | 8 | Assigned location |
| inventory | u64 | 64 | Product they're holding |
| status | u8 | 8 | Active/Busted/LayingLow/Betrayed |
| earnings_held | u32 | 32 | Uncollected dirty cash |
| **Total** | | **~360** | 2 felt252 per slot |

#### Cartel
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| cartel_id | u32 | 32 | Cartel identifier |
| owner | felt252 | 252 | Owner wallet |
| name | felt252 | 252 | Cartel name |
| slots_count | u8 | 8 | Active agent slots |
| stash_capacity | u16 | 16 | Max stash storage |
| treasury | u32 | 32 | Cartel bank (clean cash) |
| **Total** | | **~320** | 2 felt252 |

#### Operation
| Field | Type | Bits | Description |
|-------|------|------|-------------|
| op_type | u8 | 8 | Laundromat/CarWash/TacoShop/PostOffice |
| cartel_id | u32 | 32 | Owning cartel |
| capacity_per_turn | u16 | 16 | Dirty cash processed per turn |
| processing | u16 | 16 | Currently in pipeline |
| level | u8 | 8 | Upgrade tier |
| **Total** | | **~64** | |

### State Budget Summary

```
Player total:           ~544 bits = 3 felt252 (756 bits)  ✓
AgentSlot:              ~360 bits = 2 felt252 per slot
Market:                 ~280 bits = 1 felt252 per location
Cartel:                 ~320 bits = 2 felt252
Operation:              ~64 bits  = 1 felt252
```

All components fit within Dojo's storage model. Each is a separate Dojo model — independently queryable via Torii, independently upgradable.

---

## 5. Core Game Loop

### Turn Structure (3 AP)

#### Commit Phase
Player batches up to 3 actions, each costing AP:

| Action | AP Cost | Description |
|--------|---------|-------------|
| Travel | 1-2 | Move to location (2 if distant) |
| Buy | 1 | Buy drug at current location |
| Sell | 1 | Sell drug at current location |
| Mix | 2 | Combine ingredient + product |
| Scout | 1 | Reveal prices at adjacent location |
| Manage | 1 | Restock dealer / set strategy |
| Invest | 1 | Fund operation / launder cash |
| Rest | 2 | Reduce heat by 1 tier |

Actions encrypted and submitted on-chain: `commit_actions(game_id, action_hash, ap_spent)`

#### Resolve Phase
1. VRF callback provides random seed
2. Player reveals plaintext actions
3. Contract verifies hash matches commit
4. Actions execute sequentially:
   - Validate (enough AP? valid location? inventory space?)
   - Execute (update state)
   - Check encounter trigger (`heat × location_danger`)
5. Encounters auto-resolve:
   ```
   crew_power = Σ(slot.stats) + gear + enforcer_bonus
   threat = heat_tier × location_danger × vrf_roll
   outcome = crew_power > threat ? SURVIVE : LOSS
   LOSS → lose product/cash/dealer based on heat tier
   ```

#### Between-Turn Passive Tick
Off-chain engine (hosted server or Torii plugin) processes, results committed on-chain:
- Dealers sell product → earn dirty cash
- Operations process → dirty cash → clean cash
- Markets drift (supply replenish, price jitter)
- Heat decays (-1 per location per tick)
- Drug quality degrades (perishability)
- Random events roll (raid, supply shortage, boom)
- Agent slot NPCs execute their strategy

The passive tick engine runs as a server-side process (can be a Torii indexer plugin or standalone service) that listens for turn-end events and submits tick results on-chain. In Stage 1, a simple cron job or event listener suffices. Results batched and posted: `passive_tick(game_id, tick_results_hash, proof)`

### Encounter Escalation (Heat Tiers)

| Tier | Name | Encounter Rate | Consequences | De-escalation |
|------|------|---------------|--------------|---------------|
| 0 | None | 0% | Free to operate | — |
| 1 | Surveillance | 5% per action | Cops watch, warn | 2 turns clean |
| 2 | Wanted | 20% per action | Seize product + cash | Bribe (clean cash) OR rest 3 turns |
| 3 | Dead or Alive | 40% per action | Lethal force, lose crew | Sacrifice dealer OR rest 5 turns OR massive bribe |

Heat increases from: selling drugs (+activity heat), fighting cops (+notoriety), traveling with product (+location heat). Heat decays passively between turns.

### Game Mode Settings

| Setting | Casual | Ranked | Endless |
|---------|--------|--------|---------|
| AP per turn | 4 | 3 | 3 |
| Turns | 20-30 | 50-75 | ∞ (seasonal snapshots) |
| Starting cash | High | Medium | Low |
| Heat decay | Fast | Normal | Slow |
| Dealer slots | 2 | 4 | 6 |

---

## 6. Game Systems

### 6.1 Market System

Each location has 6-8 drugs with independent price ticks and supply levels. Prices follow a modified AMM model:

```
price = base_price + (tick × step)
tick ∈ [0, 63]  (6-bit)
```

- **Supply drain:** Buying reduces supply, increases price. Selling increases supply, decreases price.
- **Market drift:** Between turns, ticks shift randomly (±1-3 per drug per location).
- **Market events:** Random events per location: Bust (-50% supply of random drug), Boom (+30% price of random drug), Shortage (supply halved globally), Surplus (supply doubled at one location).
- **Fog of war:** `visible_to` bitmask on each Market model. Contract refuses price queries from players who haven't scouted or visited.

### 6.2 Mixing System (Stage 1: Modifier Stacking)

8-10 ingredients, each adds a named effect with a price multiplier. Up to 4 effects per product.

```
sell_price = base_drug_price × quantity × (1 + Σ effect_multipliers)
```

| Ingredient | Effect | Multiplier | Unlock |
|------------|--------|-----------|--------|
| Baking Soda | Cut | +0.05 | Start |
| Caffeine Pills | Energizing | +0.22 | Start |
| Acetone | Potent | +0.30 | Rank 2 |
| Laxatives | Bulking | +0.10 | Start |
| Vitamin Powder | Healthy | +0.15 | Rank 1 |
| Methanol | Toxic | +0.35 | Rank 3 |
| Ephedrine | Speedy | +0.40 | Rank 4 |
| Lithium | Electric | +0.50 | Rank 5 |

Effects are packed as 4 × 8-bit IDs in the inventory's `effects` field. Mixing costs 2 AP and consumes the ingredient.

**Stage 3 extension:** Full combinatorial mixing (order-dependent, 16 ingredients, up to 8 effects, advanced effect transformations).

### 6.3 Reputation System

Three specialization branches. XP earned from relevant actions:

| Branch | XP Sources | Level Unlocks |
|--------|-----------|---------------|
| **Trader** | Buying, selling, scouting | Better prices, market intel, more drug tiers |
| **Enforcer** | Surviving encounters, high heat operation | Combat power, crew stats, intimidation |
| **Operator** | Managing dealers, laundering, investing | More slots, operation capacity, passive income |

5 levels per branch. Level formula: `level = floor(xp / threshold[level])` with increasing thresholds.

Players allocate XP naturally through play style — no explicit point spending. A trading-focused player becomes a Trader specialist organically.

### 6.4 Agent Slot System

Agent slots are the core multiplayer primitive. Every slot has a type, a controller, and a standard interface.

**Slot Types:**

| Type | Function | Stage |
|------|----------|-------|
| Dealer | Sells product at assigned location | Stage 2 |
| Cook | Processes raw materials (future) | Stage 2 P2 |
| Runner | Transports between locations (future) | Stage 2 P2 |
| Muscle | Boosts crew_power for encounters | Stage 2 P2 |

**Controller Types:**

| Type | Description | Stage |
|------|-------------|-------|
| NPC | Default AI behavior | Stage 2 |
| Agent | External AI agent via contract calls | Stage 2 |
| Human | Another player via multiplayer | Stage 3 |

**Universal Interface:**
```
receive_product(slot_id, drug_slot)    — restock the slot
set_strategy(slot_id, strategy)        — aggressive/cautious/custom
collect_earnings(slot_id) → u32        — withdraw dirty cash earned
get_status(slot_id) → SlotStatus       — active/busted/laying_low/betrayed
```

**Dealer behavior (NPC default):**
- Sells assigned product each passive tick
- Earn rate: `quantity × price × efficiency / commission_rate`
- Commission: 20% of sales to the dealer
- Bust risk: `location_heat × (1 - stealth) × 0.1` per tick
- If busted: loses inventory, status → Busted, unavailable for 3 turns

### 6.5 Operations (Laundering)

Abstracted businesses that convert dirty cash → clean cash over time.

| Operation | Cost | Capacity/Turn | Unlock |
|-----------|------|--------------|--------|
| Laundromat | 2,000 | 500/turn | Operator Lvl 1 |
| Car Wash | 5,000 | 1,200/turn | Operator Lvl 2 |
| Taco Shop | 12,000 | 2,500/turn | Operator Lvl 3 |
| Post Office | 25,000 | 5,000/turn | Operator Lvl 4 |

Processing takes 2 turns. Invest action queues dirty cash; it converts after 2 passive ticks.

### 6.6 Encounter System (Auto-Resolve)

No player input during encounters. Outcome determined by preparation:

```
crew_power = base_defense
           + Σ(active_muscle_slots × stats.combat)
           + enforcer_bonus[enforcer_lvl]
           + gear_bonus

threat = heat_tier_multiplier[tier]
       × location_danger[location]
       × vrf_roll(1.0 - 2.0)

heat_tier_multiplier = [0, 1, 3, 6]
```

**Outcomes by tier:**

| Tier | Win | Lose |
|------|-----|------|
| Surveillance | Warning only | Lose 10% cash |
| Wanted | Seize 1 drug slot | Lose 25% cash + 1 drug slot + 1 turn jailed |
| Dead or Alive | Seize 2 drug slots + dealer busted | Lose 50% cash + all drugs + dealer killed |

---

## 7. Agent API

Same interface for AI agents, human frontend, and future multiplayer clients.

### Query Endpoints (fog-of-war enforced)

```
get_game_state(game_id, player_id) → {
  player, inventory, wallet, heat, reputation,
  current_location_market,    // always visible
  scouted_markets[],          // only previously scouted
  cartel, slots[], operations[]
}

get_visible_markets(game_id, player_id) → Market[]
get_my_slots(game_id, player_id) → AgentSlot[]
get_heat_profile(game_id, player_id) → HeatProfile
get_reputation(game_id, player_id) → Reputation
get_leaderboard(season_id) → Score[]
```

### Action Endpoints

```
commit_actions(game_id, action_hash, ap_spent)
reveal_resolve(game_id, actions[])
```

### Slot Management Endpoints

```
hire_slot(game_id, slot_type, location) → slot_id
set_strategy(slot_id, strategy)
restock_slot(slot_id, drug_slot)
collect_earnings(slot_id) → u32
fire_slot(slot_id)
```

### Game Lifecycle

```
create_game(mode, player_name) → game_id
join_game(game_id, slot_id)          // Stage 3 multiplayer
end_game(game_id)
register_score(game_id)
```

All endpoints accessible via:
1. Direct Starknet contract calls (for on-chain agents)
2. Torii GraphQL subscriptions (for off-chain agents and frontend)
3. REST wrapper (convenience layer, Stage 2)

---

## 8. Three-Stage Development Plan

### Stage 1: Foundation (Weeks 1-3) — "Playable cartel game"

#### P0 — Must Ship
- [ ] New Dojo world setup + ECS models (Player, Inventory, WalletState, HeatProfile, Market, LocationState)
- [ ] Commit-reveal action system (commit_actions → VRF callback → reveal_resolve)
- [ ] Action point system (3-4 AP per turn)  — Travel, Buy, Sell, Scout, Rest
- [ ] Multi-drug inventory (4 slots)
- [ ] Market engine with fog of war (per-location prices, visible_to bitmask, supply drain on buy)
- [ ] Dirty/clean cash dual currency (virtual)
- [ ] 6 NYC locations with base properties
- [ ] Basic encounter system (auto-resolve with heat tier 0-3, crew_power vs threat)
- [ ] Game lifecycle: create → play turns → end → score
- [ ] Casual mode (20-30 turns, generous settings)
- [ ] Basic frontend (Next.js — travel, trade, inventory UI)
- [ ] Torii indexer + GraphQL queries

#### P1 — Should Ship
- [ ] Agent API endpoints (same GraphQL, documented)
- [ ] Modifier stacking mixing system (8-10 ingredients, up to 4 effects)
- [ ] Mixing UI
- [ ] Heat escalation with de-escalation actions (bribe, rest)
- [ ] Basic leaderboard + season system
- [ ] Ranked mode (50-75 turns)

#### P2 — Nice to Have
- [ ] Sound/music
- [ ] Animations for encounters, mixing, travel
- [ ] Tutorial / onboarding flow
- [ ] Mobile-responsive layout

### Stage 2: Empire (Weeks 4-6) — "Build your cartel"

#### P0 — Must Ship
- [ ] Agent slot system (AgentSlot ECS model — Dealer/Cook/Runner/Muscle, NPC/Agent/Human controller)
- [ ] Universal agent slot interface (receive_product, set_strategy, collect_earnings, get_status)
- [ ] NPC dealer AI (default agent slot implementation — sells product, earns cash, can get busted)
- [ ] Passive tick engine (between-turn: dealer earnings, market drift, heat decay, quality degradation)
- [ ] Reputation tree (Trader/Enforcer/Operator — XP from actions, level-up unlocks)
- [ ] Cartel entity + stash (cross-turn storage)

#### P1 — Should Ship
- [ ] Operations system (abstracted laundering — 4 types with capacity tiers)
- [ ] Endless mode (persistent empire, seasonal snapshots)
- [ ] Drug quality degradation over turns
- [ ] Market events (raids, booms, shortages — random per-turn)
- [ ] Agent training tools (deterministic seed mode, replay export)
- [ ] Dealer management UI (assign, restock, collect, view status)

#### P2 — Nice to Have
- [ ] Crew member hiring beyond dealers (Cook, Runner, Muscle)
- [ ] Contract orders (deliver X drug to Y location in N turns for bonus)
- [ ] Informant/snitch mechanic
- [ ] Achievement system

#### P3 — Defer
- [ ] NFT gear/hustler integration (port from existing DopeWars)
- [ ] Real token integration (replace virtual currency)

### Stage 3: Multiplayer + Expansion (Weeks 7-10) — "Cartel wars"

#### P0 — Must Ship
- [ ] Shared market (all players trade in same economy — prices react to aggregate activity)
- [ ] Multiplayer agent slots (human/agent fills another player's slot via join_game)
- [ ] cartel_id on all entities (foundation for alliances)
- [ ] Tiered fog of war (tied to Trader reputation: Level 0 current only → Level 3 full intel)

#### P1 — Should Ship
- [ ] Full combinatorial mixing (order-dependent, 16 ingredients, 8 stacks)
- [ ] Fictional city expansion (new map alongside NYC)
- [ ] Territorial control (locations have owner_cartel_id)
- [ ] Inter-cartel conflict resolution
- [ ] Spectator/replay mode

#### P2 — Nice to Have
- [ ] Cartel alliances (shared territory, supply chains, treasury)
- [ ] Role specialization within cartels (enforced by slot types)
- [ ] Multi-city / international expansion
- [ ] Weather/environmental events per location
- [ ] Real token launch + staking rewards

#### P3 — Defer (future stages beyond scope)
- [ ] Cross-chain deployment
- [ ] Mobile native app
- [ ] Tournament system with prize pools
- [ ] DAO governance for season parameters

---

## 9. Workstream Parallelization

Designed for AI-agent development with 3 parallel workstreams per stage.

### Stage 1

| Workstream A (Contracts) | Workstream B (Frontend) | Workstream C (Infrastructure) |
|--------------------------|------------------------|-------------------------------|
| ECS models | Next.js shell | Dojo world setup |
| Action system | Travel/map UI | Torii config |
| Market engine | Trade UI | VRF integration |
| Encounter system | Inventory UI | Deploy scripts |
| Game lifecycle | Fog of war display | Agent API docs |
| Mixing system | Mixing UI | CI/CD pipeline |
| | Leaderboard UI | |

### Stage 2

| Workstream A (Contracts) | Workstream B (Frontend) | Workstream C (Agent/Engine) |
|--------------------------|------------------------|----------------------------|
| Agent slot system | Dealer management UI | Passive tick engine |
| Reputation tree | Reputation tree UI | NPC dealer AI |
| Cartel + stash | Operations UI | Market event engine |
| Operations system | Endless mode UI | Replay/seed system |
| Quality degradation | | Agent SDK + docs |

### Stage 3

| Workstream A (Contracts) | Workstream B (Frontend) | Workstream C (Multiplayer) |
|--------------------------|------------------------|---------------------------|
| Shared market | New map/locations | Slot matchmaking |
| Combinatorial mixing | Spectator UI | Alliance system |
| Territory control | Alliance UI | Conflict resolution |
| Tiered fog of war | Multiplayer lobby | Token integration |

---

## 10. Future Extensibility

The architecture is designed with explicit extension points for features beyond the 3-stage scope:

| Extension Point | Current | Future |
|----------------|---------|--------|
| Mixing system | Modifier stacking (set-based) | Combinatorial (order-dependent) |
| Economy | Virtual dirty/clean cash | Real token + NFT products |
| Map | 6 NYC locations | Fictional cities + international |
| Turn structure | Action points | Phase-based turns |
| Fog of war | Full fog (binary) | Tiered visibility via reputation |
| Multiplayer | Shared market | Cartel alliances + PvP |
| Agent slots | NPC + AI agent | Human players |
| Operations | 4 fixed types | Player-created custom operations |
| Chain | Starknet L2 | Cross-chain / L3 appchain |

**Dojo's ECS architecture enables these extensions** because:
1. New components attach to existing entities without migration
2. New systems interact with existing models via the same World interface
3. Torii automatically indexes new models — no indexer rewrites
4. Proxy pattern allows system upgrades while preserving state

---

## Appendix: Agent Suggestions Cross-Reference

This design incorporates proposals from all three agents:

| Feature | Agent 1 | Agent 2 | Agent 3 | Stage |
|---------|---------|---------|---------|-------|
| Multi-drug inventory | ✓ (#1) | ✓ | | 1 |
| Drug mixing | ✓ (#8) | ✓ | ✓ (#9) | 1 (B) → 3 (C) |
| Dealer network | ✓ (#10) | | ✓ (#10) | 2 |
| Money laundering | ✓ (#11) | | | 2 |
| Market fog of war | | | ✓ (#1) | 1 |
| Reputation trees | | | ✓ (#3) | 2 |
| Escalating heat | ✓ (#6) | | | 1 |
| Agent API | ✓ (#14) | ✓ | | 1 |
| Multi-agent modes | ✓ (#16) | | | 3 |
| Deterministic seeds | ✓ (#13) | ✓ | | 2 |
| Supply/demand sim | | ✓ | ✓ (#4) | 1 |
| Market events | ✓ (#4) | ✓ | | 2 |
| Quality degradation | | ✓ | ✓ (#2) | 2 |
| Customer preferences | ✓ (#9) | ✓ | | 3 |
| Contract orders | | | ✓ (#6) | 2 P2 |
| Informant mechanic | | | ✓ (#5) | 2 P2 |
| Crew members | | | ✓ (#12) | 2 P2 |
| Action points | | | ✓ (#7) | 1 |
| Property stash | | | ✓ (#11) | 2 |
| Shared market | ✓ (#16) | | | 3 |
| Territorial control | ✓ (#16) | | | 3 |

**Not included (with rationale):**
- Bank with interest (#1-2): Adds complexity without strategic depth for cartel theme
- Starting debt/loan shark (#1-3): Can be added as a game mode modifier later
- Ammo system (#1-19): Over-detailed for auto-resolve combat
- Addiction mechanic (Agent 2): Punishes players, doesn't add fun
- P2P trading with escrow (Agent 2): Premature for pre-multiplayer stages
- Fatigue system (#3-7): AP system already gates actions, fatigue is redundant
- Weather events (#3-8): Deferred to Stage 3 P2
