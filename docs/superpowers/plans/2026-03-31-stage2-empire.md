# Stage 2: Empire — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cartel empire mechanics — agent slots (dealer network), operations (money laundering), passive tick engine, reputation unlocks, cartel entity with stash, market dynamics, and dealer management UI.

**Architecture:** New Dojo models and systems added alongside Stage 1 contracts. Passive tick engine as a Dojo system callable by the game contract at turn end. All new systems use `cartel_v0` namespace. Frontend extends existing cartel pages.

**Tech Stack:** Cairo 2.12.2, Dojo 1.7.1, Starknet, Next.js 16, React 19, Chakra UI v2, TypeScript.

**Spec:** `docs/superpowers/specs/2026-03-31-cartel-game-revamp-design.md` (Sections 6.3-6.5, 8 Stage 2)

**Build/Test commands:**
```bash
export PATH="$HOME/.asdf/bin:$HOME/.asdf/shims:$HOME/.cargo/bin:$PATH" && cd ~/dopewars
scarb build 2>&1 | tail -5
scarb test 2>&1 | tail -10
```

---

## File Structure

### New Cairo Files

```
src/
├── models/
│   ├── agent_slot.cairo           # CREATE — AgentSlot model (dealer/crew entity)
│   ├── cartel.cairo               # CREATE — Cartel model (empire entity + stash)
│   ├── operation.cairo            # CREATE — Operation model (laundering business)
│
├── config/
│   ├── slot_config.cairo          # CREATE — Slot type configs, hire costs
│   ├── operation_config.cairo     # CREATE — Operation types, costs, capacities
│   ├── reputation_config.cairo    # CREATE — Level thresholds, unlock definitions
│
├── systems/
│   ├── slot_system.cairo          # CREATE — Agent slot management contract
│   ├── operation_system.cairo     # CREATE — Operations/laundering contract
│   ├── passive_tick.cairo         # CREATE — Between-turn processing system
│   ├── cartel_game.cairo          # MODIFY — Add Manage/Invest actions, reputation unlocks
│
├── systems/helpers/
│   ├── slot_helpers.cairo         # CREATE — Dealer sell logic, bust risk calc
│   ├── operation_helpers.cairo    # CREATE — Laundering processing logic
│   ├── reputation_helpers.cairo   # CREATE — XP award, level-up check, unlock gate
│   ├── market_drift.cairo         # CREATE — Price tick drift, market events
│
├── tests/
│   ├── test_agent_slot.cairo      # CREATE
│   ├── test_operations.cairo      # CREATE
│   ├── test_passive_tick.cairo    # CREATE
│   ├── test_reputation.cairo      # CREATE
│   ├── test_market_drift.cairo    # CREATE
```

### New Frontend Files

```
web/src/
├── dojo/class/
│   ├── CartelSlot.ts              # CREATE — AgentSlot domain class
│   ├── CartelOperation.ts         # CREATE — Operation domain class
│   ├── CartelCartel.ts            # CREATE — Cartel entity class
│
├── dojo/hooks/
│   ├── useCartelSlots.ts          # CREATE — Slot management hook
│   ├── useCartelOperations.ts     # CREATE — Operations hook
│
├── components/cartel/
│   ├── DealerPanel.tsx            # CREATE — Dealer list + management
│   ├── DealerCard.tsx             # CREATE — Single dealer slot card
│   ├── OperationPanel.tsx         # CREATE — Laundering business panel
│   ├── CartelOverview.tsx         # CREATE — Empire summary (stash, treasury, slots)
│   ├── ReputationTree.tsx         # CREATE — 3-branch XP/level display
│
├── pages/cartel/[gameId]/
│   ├── dealers.tsx                # CREATE — Dealer management page
│   ├── operations.tsx             # CREATE — Operations/laundering page
│   ├── empire.tsx                 # CREATE — Cartel overview page
```

---

## Task 1: Agent Slot Model + Config

**Files:**
- Create: `src/models/agent_slot.cairo`
- Create: `src/config/slot_config.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create AgentSlot model**

Create `src/models/agent_slot.cairo`:

```cairo
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum SlotType {
    #[default]
    None,
    Dealer,
    Cook,
    Runner,
    Muscle,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum ControllerType {
    #[default]
    NPC,
    Agent,
    Human,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum SlotStatus {
    #[default]
    Inactive,
    Active,
    Busted,
    LayingLow,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct AgentSlot {
    #[key]
    pub game_id: u32,
    #[key]
    pub slot_id: u8,
    pub owner: ContractAddress,
    pub slot_type: u8,           // SlotType as u8 (1=Dealer)
    pub controller_type: u8,     // ControllerType as u8 (0=NPC, 1=Agent)
    pub controller_addr: ContractAddress,
    pub strategy: u8,            // 0=cautious, 1=aggressive, 2=balanced
    pub reliability: u8,         // 1-100
    pub stealth: u8,             // 1-100
    pub salesmanship: u8,        // 1-100
    pub combat: u8,              // 1-100
    pub location: u8,            // assigned location (1-6)
    pub drug_id: u8,             // drug they're selling
    pub drug_quantity: u16,      // inventory they hold
    pub drug_effects: u32,       // effects on their product
    pub status: u8,              // SlotStatus as u8
    pub earnings_held: u32,      // uncollected dirty cash
    pub busted_until_turn: u16,  // turn when bust ends
}

// Slot counter per game
#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct SlotCounter {
    #[key]
    pub game_id: u32,
    pub next_slot_id: u8,
    pub active_count: u8,
}
```

- [ ] **Step 2: Create slot config**

Create `src/config/slot_config.cairo`:

```cairo
pub struct SlotTypeConfig {
    pub hire_cost: u32,          // dirty cash to hire
    pub base_reliability: u8,
    pub base_stealth: u8,
    pub base_salesmanship: u8,
    pub base_combat: u8,
    pub commission_pct: u8,      // % of sales kept by slot
}

pub fn get_slot_type_config(slot_type: u8) -> SlotTypeConfig {
    if slot_type == 1 { // Dealer
        SlotTypeConfig {
            hire_cost: 500,
            base_reliability: 60,
            base_stealth: 40,
            base_salesmanship: 70,
            base_combat: 20,
            commission_pct: 20,
        }
    } else if slot_type == 4 { // Muscle
        SlotTypeConfig {
            hire_cost: 800,
            base_reliability: 70,
            base_stealth: 30,
            base_salesmanship: 10,
            base_combat: 80,
            commission_pct: 0,
        }
    } else {
        SlotTypeConfig {
            hire_cost: 0,
            base_reliability: 0,
            base_stealth: 0,
            base_salesmanship: 0,
            base_combat: 0,
            commission_pct: 0,
        }
    }
}

pub const BUST_DURATION_TURNS: u16 = 3;
pub const MAX_SLOTS_PER_GAME: u8 = 6;
```

- [ ] **Step 3: Register modules in lib.cairo**

Add to models block: `pub mod agent_slot;`
Add to config block: `pub mod slot_config;`

- [ ] **Step 4: Verify build**

Run: `scarb build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/models/agent_slot.cairo src/config/slot_config.cairo src/lib.cairo
git commit -m "feat: add AgentSlot model and slot type config"
```

---

## Task 2: Cartel Model + Stash

**Files:**
- Create: `src/models/cartel.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create Cartel model**

Create `src/models/cartel.cairo`:

```cairo
use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Cartel {
    #[key]
    pub game_id: u32,
    #[key]
    pub owner: ContractAddress,
    pub name: felt252,
    pub slot_count: u8,
    pub stash_slot_0: u64,       // packed DrugSlot (same format as Inventory)
    pub stash_slot_1: u64,
    pub stash_slot_2: u64,
    pub stash_slot_3: u64,
    pub stash_slot_4: u64,       // extra stash capacity vs inventory
    pub stash_slot_5: u64,
    pub treasury: u32,           // cartel clean cash reserve
}
```

- [ ] **Step 2: Register in lib.cairo**

Add to models block: `pub mod cartel;`

- [ ] **Step 3: Verify build and commit**

```bash
scarb build 2>&1 | tail -5
git add src/models/cartel.cairo src/lib.cairo
git commit -m "feat: add Cartel model with stash storage"
```

---

## Task 3: Operation Model + Config

**Files:**
- Create: `src/models/operation.cairo`
- Create: `src/config/operation_config.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create Operation model**

Create `src/models/operation.cairo`:

```cairo
use starknet::ContractAddress;

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct Operation {
    #[key]
    pub game_id: u32,
    #[key]
    pub op_id: u8,
    pub owner: ContractAddress,
    pub op_type: u8,             // 1=Laundromat, 2=CarWash, 3=TacoShop, 4=PostOffice
    pub level: u8,               // upgrade tier
    pub capacity_per_turn: u16,  // max dirty cash processed per turn
    pub processing_amount: u32,  // dirty cash currently in pipeline
    pub processing_turns_left: u8, // turns until current batch completes
    pub total_laundered: u32,    // lifetime total
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct OperationCounter {
    #[key]
    pub game_id: u32,
    pub next_op_id: u8,
    pub active_count: u8,
}
```

- [ ] **Step 2: Create operation config**

Create `src/config/operation_config.cairo`:

```cairo
pub struct OpTypeConfig {
    pub purchase_cost: u32,      // dirty cash to buy
    pub capacity_per_turn: u16,  // dirty cash laundered per turn
    pub processing_turns: u8,    // turns to process a batch
    pub unlock_operator_lvl: u8, // minimum Operator reputation level
}

pub fn get_op_config(op_type: u8) -> OpTypeConfig {
    if op_type == 1 { // Laundromat
        OpTypeConfig { purchase_cost: 2000, capacity_per_turn: 500, processing_turns: 2, unlock_operator_lvl: 1 }
    } else if op_type == 2 { // Car Wash
        OpTypeConfig { purchase_cost: 5000, capacity_per_turn: 1200, processing_turns: 2, unlock_operator_lvl: 2 }
    } else if op_type == 3 { // Taco Shop
        OpTypeConfig { purchase_cost: 12000, capacity_per_turn: 2500, processing_turns: 2, unlock_operator_lvl: 3 }
    } else if op_type == 4 { // Post Office
        OpTypeConfig { purchase_cost: 25000, capacity_per_turn: 5000, processing_turns: 2, unlock_operator_lvl: 4 }
    } else {
        OpTypeConfig { purchase_cost: 0, capacity_per_turn: 0, processing_turns: 0, unlock_operator_lvl: 0 }
    }
}

pub const MAX_OPERATIONS: u8 = 4;
```

- [ ] **Step 3: Register and commit**

```bash
scarb build 2>&1 | tail -5
git add src/models/operation.cairo src/config/operation_config.cairo src/lib.cairo
git commit -m "feat: add Operation model and laundering config"
```

---

## Task 4: Reputation Config + Helpers

**Files:**
- Create: `src/config/reputation_config.cairo`
- Create: `src/systems/helpers/reputation_helpers.cairo`
- Create: `src/tests/test_reputation.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create reputation config**

Create `src/config/reputation_config.cairo`:

```cairo
// XP thresholds per level (already defined in models/reputation.cairo)
// This file defines what each level unlocks

pub struct ReputationUnlocks {
    pub max_drug_tier: u8,       // Trader: highest drug_id accessible
    pub price_discount_pct: u8,  // Trader: % discount on buys
    pub crew_power_bonus: u32,   // Enforcer: added to crew_power
    pub max_slots: u8,           // Operator: max agent slots
    pub max_operations: u8,      // Operator: max laundering ops
}

pub fn get_trader_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 5, price_discount_pct: 5, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 6, price_discount_pct: 10, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 7, price_discount_pct: 15, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 8, price_discount_pct: 18, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else {
        ReputationUnlocks { max_drug_tier: 8, price_discount_pct: 20, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    }
}

pub fn get_enforcer_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 5, max_slots: 2, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 12, max_slots: 2, max_operations: 1 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 20, max_slots: 2, max_operations: 1 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 30, max_slots: 2, max_operations: 1 }
    } else {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 40, max_slots: 2, max_operations: 1 }
    }
}

pub fn get_operator_unlocks(level: u8) -> ReputationUnlocks {
    if level == 0 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 2, max_operations: 1 }
    } else if level == 1 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 3, max_operations: 1 }
    } else if level == 2 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 4, max_operations: 2 }
    } else if level == 3 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 5, max_operations: 3 }
    } else if level == 4 {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 6, max_operations: 4 }
    } else {
        ReputationUnlocks { max_drug_tier: 4, price_discount_pct: 0, crew_power_bonus: 0, max_slots: 6, max_operations: 4 }
    }
}
```

- [ ] **Step 2: Create reputation helpers**

Create `src/systems/helpers/reputation_helpers.cairo`:

```cairo
use crate::models::reputation::{Reputation, xp_to_level};
use crate::config::reputation_config::{get_trader_unlocks, get_enforcer_unlocks, get_operator_unlocks};

pub fn award_xp(ref reputation: Reputation, branch: u8, amount: u16) {
    // branch: 0=trader, 1=enforcer, 2=operator
    if branch == 0 {
        reputation.trader_xp = reputation.trader_xp + amount;
        reputation.trader_lvl = xp_to_level(reputation.trader_xp);
    } else if branch == 1 {
        reputation.enforcer_xp = reputation.enforcer_xp + amount;
        reputation.enforcer_lvl = xp_to_level(reputation.enforcer_xp);
    } else if branch == 2 {
        reputation.operator_xp = reputation.operator_xp + amount;
        reputation.operator_lvl = xp_to_level(reputation.operator_xp);
    }
}

pub fn can_access_drug(trader_lvl: u8, drug_id: u8) -> bool {
    let unlocks = get_trader_unlocks(trader_lvl);
    drug_id <= unlocks.max_drug_tier
}

pub fn get_max_slots(operator_lvl: u8) -> u8 {
    let unlocks = get_operator_unlocks(operator_lvl);
    unlocks.max_slots
}

pub fn get_max_operations(operator_lvl: u8) -> u8 {
    let unlocks = get_operator_unlocks(operator_lvl);
    unlocks.max_operations
}

pub fn get_crew_power_bonus(enforcer_lvl: u8) -> u32 {
    let unlocks = get_enforcer_unlocks(enforcer_lvl);
    unlocks.crew_power_bonus
}

pub fn get_price_discount(trader_lvl: u8) -> u8 {
    let unlocks = get_trader_unlocks(trader_lvl);
    unlocks.price_discount_pct
}

// XP branch constants
pub const BRANCH_TRADER: u8 = 0;
pub const BRANCH_ENFORCER: u8 = 1;
pub const BRANCH_OPERATOR: u8 = 2;
```

- [ ] **Step 3: Create reputation tests**

Create `src/tests/test_reputation.cairo`:

```cairo
use rollyourown::systems::helpers::reputation_helpers::{
    award_xp, can_access_drug, get_max_slots, get_max_operations,
    get_crew_power_bonus, get_price_discount,
    BRANCH_TRADER, BRANCH_ENFORCER, BRANCH_OPERATOR,
};
use rollyourown::models::reputation::Reputation;
use starknet::contract_address_const;

#[test]
fn test_award_xp_trader() {
    let mut rep = Reputation {
        game_id: 1, player_id: contract_address_const::<0x1>(),
        trader_xp: 0, enforcer_xp: 0, operator_xp: 0,
        trader_lvl: 0, enforcer_lvl: 0, operator_lvl: 0,
    };
    award_xp(ref rep, BRANCH_TRADER, 100);
    assert(rep.trader_xp == 100, 'trader xp 100');
    assert(rep.trader_lvl == 1, 'trader lvl 1 at 100');
}

#[test]
fn test_award_xp_levels_up() {
    let mut rep = Reputation {
        game_id: 1, player_id: contract_address_const::<0x1>(),
        trader_xp: 0, enforcer_xp: 0, operator_xp: 0,
        trader_lvl: 0, enforcer_lvl: 0, operator_lvl: 0,
    };
    award_xp(ref rep, BRANCH_OPERATOR, 600);
    assert(rep.operator_lvl == 3, 'operator lvl 3 at 600');
}

#[test]
fn test_can_access_drug_by_level() {
    assert(can_access_drug(0, 4), 'lvl 0 can access drug 4');
    assert(!can_access_drug(0, 5), 'lvl 0 cannot access drug 5');
    assert(can_access_drug(1, 5), 'lvl 1 can access drug 5');
    assert(can_access_drug(5, 8), 'lvl 5 can access drug 8');
}

#[test]
fn test_max_slots_by_operator_level() {
    assert(get_max_slots(0) == 2, 'lvl 0 = 2 slots');
    assert(get_max_slots(2) == 4, 'lvl 2 = 4 slots');
    assert(get_max_slots(4) == 6, 'lvl 4 = 6 slots');
}

#[test]
fn test_crew_power_bonus() {
    assert(get_crew_power_bonus(0) == 0, 'lvl 0 no bonus');
    assert(get_crew_power_bonus(3) == 20, 'lvl 3 = 20');
}

#[test]
fn test_price_discount() {
    assert(get_price_discount(0) == 0, 'lvl 0 no discount');
    assert(get_price_discount(5) == 20, 'lvl 5 = 20%');
}
```

- [ ] **Step 4: Register modules, verify build and tests**

Register in lib.cairo: `reputation_config` in config, `reputation_helpers` in systems/helpers, `test_reputation` in tests.

```bash
scarb build 2>&1 | tail -5
scarb test -f test_reputation 2>&1 | tail -10
git add src/config/reputation_config.cairo src/systems/helpers/reputation_helpers.cairo src/tests/test_reputation.cairo src/lib.cairo
git commit -m "feat: add reputation config, helpers with XP/level/unlock system"
```

---

## Task 5: Slot Helpers (Dealer Sell Logic, Bust Risk)

**Files:**
- Create: `src/systems/helpers/slot_helpers.cairo`
- Create: `src/tests/test_agent_slot.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create slot helpers**

Create `src/systems/helpers/slot_helpers.cairo`:

```cairo
use crate::config::slot_config::{get_slot_type_config, BUST_DURATION_TURNS};
use crate::config::drugs_v2::get_drug_config;
use crate::models::heat::get_location_heat;

// Calculate how much a dealer sells per tick
pub fn calculate_dealer_sales(
    drug_id: u8,
    quantity: u16,
    salesmanship: u8,
    strategy: u8,       // 0=cautious, 1=aggressive, 2=balanced
    price_tick: u16,
) -> (u16, u32) { // (quantity_sold, revenue)
    let drug_config = get_drug_config(drug_id);
    let price: u32 = drug_config.base_price.into() + (price_tick.into() * drug_config.price_step.into());

    // Sales volume based on strategy and salesmanship
    // cautious: sell 10% of stock, aggressive: 30%, balanced: 20%
    let base_pct: u16 = if strategy == 0 { 10 } else if strategy == 1 { 30 } else { 20 };
    let skill_bonus: u16 = salesmanship.into() / 20; // 0-5 extra %
    let sell_pct: u16 = base_pct + skill_bonus;

    let mut qty_sold: u16 = quantity * sell_pct / 100;
    if qty_sold == 0 && quantity > 0 {
        qty_sold = 1; // sell at least 1
    }
    if qty_sold > quantity {
        qty_sold = quantity;
    }

    let revenue: u32 = price * qty_sold.into();
    (qty_sold, revenue)
}

// Calculate bust risk per tick (returns true if busted)
// risk = location_heat * (100 - stealth) / 10000
// aggressive strategy doubles risk
pub fn calculate_bust_risk(
    location_heat: u8,
    stealth: u8,
    strategy: u8,
    roll: u8,            // VRF random 0-99
) -> bool {
    let base_risk: u16 = location_heat.into() * (100 - stealth.into()) / 100;
    let effective_risk: u16 = if strategy == 1 { base_risk * 2 } else { base_risk };
    // risk is a percentage (0-100)
    roll.into() < effective_risk
}

// Apply commission: dealer keeps commission_pct, owner gets the rest
pub fn apply_commission(revenue: u32, commission_pct: u8) -> (u32, u32) {
    let dealer_cut: u32 = revenue * commission_pct.into() / 100;
    let owner_cut: u32 = revenue - dealer_cut;
    (owner_cut, dealer_cut)
}
```

- [ ] **Step 2: Create tests**

Create `src/tests/test_agent_slot.cairo`:

```cairo
use rollyourown::systems::helpers::slot_helpers::{
    calculate_dealer_sales, calculate_bust_risk, apply_commission,
};

#[test]
fn test_dealer_sales_cautious() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 100, 50, 0, 32);
    // cautious(10%) + skill_bonus(50/20=2) = 12% of 100 = 12
    assert(qty_sold == 12, 'cautious sells 12');
}

#[test]
fn test_dealer_sales_aggressive() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 100, 50, 1, 32);
    // aggressive(30%) + 2 = 32% of 100 = 32
    assert(qty_sold == 32, 'aggressive sells 32');
}

#[test]
fn test_dealer_sales_minimum_one() {
    let (qty_sold, _revenue) = calculate_dealer_sales(1, 1, 10, 0, 32);
    // 10% of 1 = 0, but min 1
    assert(qty_sold == 1, 'min sell 1');
}

#[test]
fn test_dealer_sales_revenue() {
    // Weed at tick 32: price = 15 + 32*2 = 79
    let (qty_sold, revenue) = calculate_dealer_sales(1, 100, 0, 0, 32);
    // cautious(10%) + skill(0) = 10% of 100 = 10
    assert(qty_sold == 10, 'sells 10');
    assert(revenue == 790, 'revenue 10*79=790');
}

#[test]
fn test_bust_risk_low_heat() {
    // heat=5, stealth=80, balanced, roll=50
    // risk = 5 * (100-80) / 100 = 1
    // 50 < 1 = false
    let busted = calculate_bust_risk(5, 80, 2, 50);
    assert(!busted, 'low heat no bust');
}

#[test]
fn test_bust_risk_high_heat_aggressive() {
    // heat=50, stealth=20, aggressive, roll=10
    // base = 50 * 80 / 100 = 40, doubled = 80
    // 10 < 80 = true
    let busted = calculate_bust_risk(50, 20, 1, 10);
    assert(busted, 'high heat aggressive busts');
}

#[test]
fn test_commission_split() {
    let (owner, dealer) = apply_commission(1000, 20);
    assert(owner == 800, 'owner gets 800');
    assert(dealer == 200, 'dealer gets 200');
}
```

- [ ] **Step 3: Register, build, test, commit**

```bash
scarb build && scarb test -f test_agent_slot 2>&1 | tail -10
git add src/systems/helpers/slot_helpers.cairo src/tests/test_agent_slot.cairo src/lib.cairo
git commit -m "feat: add slot helpers — dealer sales, bust risk, commission"
```

---

## Task 6: Operation Helpers (Laundering Logic)

**Files:**
- Create: `src/systems/helpers/operation_helpers.cairo`
- Create: `src/tests/test_operations.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create operation helpers**

Create `src/systems/helpers/operation_helpers.cairo`:

```cairo
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
// Returns (amount_queued, remaining_dirty_cash)
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
```

- [ ] **Step 2: Create tests**

Create `src/tests/test_operations.cairo`:

```cairo
use rollyourown::systems::helpers::operation_helpers::{
    process_operation_tick, start_laundering, total_laundering_capacity,
};

#[test]
fn test_process_tick_completes() {
    // Laundromat, 500 processing, 1 turn left -> produces 500 clean
    let (clean, remaining, turns) = process_operation_tick(1, 500, 1);
    assert(clean == 500, 'produces 500 clean');
    assert(remaining == 0, 'nothing remaining');
    assert(turns == 0, 'no turns left');
}

#[test]
fn test_process_tick_still_processing() {
    // 2 turns left -> nothing produced yet
    let (clean, remaining, turns) = process_operation_tick(1, 500, 2);
    assert(clean == 0, 'nothing yet');
    assert(remaining == 500, 'still processing 500');
    assert(turns == 1, '1 turn left');
}

#[test]
fn test_process_tick_empty() {
    let (clean, _, _) = process_operation_tick(1, 0, 0);
    assert(clean == 0, 'nothing to process');
}

#[test]
fn test_start_laundering_within_capacity() {
    // Laundromat capacity = 500, have 300 dirty
    let (amount, turns) = start_laundering(1, 300, 0);
    assert(amount == 300, 'queue all 300');
    assert(turns == 2, '2 turns to process');
}

#[test]
fn test_start_laundering_exceeds_capacity() {
    // Laundromat capacity = 500, have 1000 dirty
    let (amount, turns) = start_laundering(1, 1000, 0);
    assert(amount == 500, 'capped at 500');
    assert(turns == 2, '2 turns');
}

#[test]
fn test_start_laundering_already_processing() {
    let (amount, _) = start_laundering(1, 1000, 500);
    assert(amount == 0, 'cannot start while processing');
}

#[test]
fn test_total_capacity() {
    let ops: Array<u8> = array![1, 2]; // Laundromat(500) + CarWash(1200)
    let total = total_laundering_capacity(ops.span());
    assert(total == 1700, 'total 1700');
}
```

- [ ] **Step 3: Register, build, test, commit**

```bash
scarb build && scarb test -f test_operations 2>&1 | tail -10
git add src/systems/helpers/operation_helpers.cairo src/tests/test_operations.cairo src/lib.cairo
git commit -m "feat: add operation helpers — laundering processing, capacity calc"
```

---

## Task 7: Market Drift Helpers

**Files:**
- Create: `src/systems/helpers/market_drift.cairo`
- Create: `src/tests/test_market_drift.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Create market drift helpers**

Create `src/systems/helpers/market_drift.cairo`:

```cairo
use crate::models::cartel_market::{get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply};
use crate::config::drugs_v2::get_drug_config;
use crate::types::drug_types::DRUG_COUNT;

pub const MAX_TICK: u16 = 63;
pub const MIN_TICK: u16 = 0;

// Apply random drift to all drug prices at a location
// drift_seed is a random value used to derive per-drug drift
pub fn apply_price_drift(drug_prices: u128, drift_seed: felt252) -> u128 {
    let mut prices = drug_prices;
    let seed_u256: u256 = drift_seed.into();
    let mut i: u8 = 0;
    while i < DRUG_COUNT {
        let current_tick = get_drug_price_tick(prices, i);
        // Extract 4 bits per drug from seed for drift direction and magnitude
        let shift: u256 = 1;
        let mut s: u256 = shift;
        let mut j: u8 = 0;
        while j < i * 4 {
            s = s * 2;
            j += 1;
        };
        let bits: u8 = ((seed_u256 / s) & 0xF).try_into().unwrap();
        // bits 0-5: drift down 1-3, bits 6-9: no change, bits 10-15: drift up 1-3
        let new_tick = if bits < 2 {
            if current_tick >= 3 { current_tick - 3 } else { MIN_TICK }
        } else if bits < 4 {
            if current_tick >= 2 { current_tick - 2 } else { MIN_TICK }
        } else if bits < 6 {
            if current_tick >= 1 { current_tick - 1 } else { MIN_TICK }
        } else if bits < 10 {
            current_tick // no change
        } else if bits < 12 {
            if current_tick + 1 <= MAX_TICK { current_tick + 1 } else { MAX_TICK }
        } else if bits < 14 {
            if current_tick + 2 <= MAX_TICK { current_tick + 2 } else { MAX_TICK }
        } else {
            if current_tick + 3 <= MAX_TICK { current_tick + 3 } else { MAX_TICK }
        };
        prices = set_drug_price_tick(prices, i, new_tick);
        i += 1;
    };
    prices
}

// Replenish supply toward initial levels
pub fn replenish_supply(drug_supply: u128) -> u128 {
    let mut supply = drug_supply;
    let mut i: u8 = 0;
    while i < DRUG_COUNT {
        let current = get_drug_supply(supply, i);
        let config = get_drug_config(i + 1); // drug_id is 1-indexed
        let initial = config.initial_supply;
        // Replenish 10% of deficit per tick
        if current < initial {
            let deficit = initial - current;
            let replenish = deficit / 10;
            let new_supply = if replenish > 0 { current + replenish } else { current + 1 };
            let capped = if new_supply > initial { initial } else { new_supply };
            supply = set_drug_supply(supply, i, capped);
        }
        i += 1;
    };
    supply
}

// Market events
pub const EVENT_NONE: u8 = 0;
pub const EVENT_BUST: u8 = 1;       // -50% supply of random drug
pub const EVENT_BOOM: u8 = 2;       // +30% price tick of random drug
pub const EVENT_SHORTAGE: u8 = 3;   // supply halved for all drugs
pub const EVENT_SURPLUS: u8 = 4;    // supply doubled for all drugs

pub fn apply_market_event(
    drug_prices: u128,
    drug_supply: u128,
    event: u8,
    target_drug_idx: u8,
) -> (u128, u128) {
    let mut prices = drug_prices;
    let mut supply = drug_supply;

    if event == EVENT_BUST {
        let current = get_drug_supply(supply, target_drug_idx);
        supply = set_drug_supply(supply, target_drug_idx, current / 2);
    } else if event == EVENT_BOOM {
        let current = get_drug_price_tick(prices, target_drug_idx);
        let boosted = current + current * 30 / 100;
        let capped = if boosted > MAX_TICK { MAX_TICK } else { boosted };
        prices = set_drug_price_tick(prices, target_drug_idx, capped);
    } else if event == EVENT_SHORTAGE {
        let mut i: u8 = 0;
        while i < DRUG_COUNT {
            let current = get_drug_supply(supply, i);
            supply = set_drug_supply(supply, i, current / 2);
            i += 1;
        };
    } else if event == EVENT_SURPLUS {
        let mut i: u8 = 0;
        while i < DRUG_COUNT {
            let current = get_drug_supply(supply, i);
            let doubled = current * 2;
            let max_supply: u16 = 500;
            let capped = if doubled > max_supply { max_supply } else { doubled };
            supply = set_drug_supply(supply, i, capped);
            i += 1;
        };
    }

    (prices, supply)
}
```

- [ ] **Step 2: Create tests**

Create `src/tests/test_market_drift.cairo`:

```cairo
use rollyourown::systems::helpers::market_drift::{
    apply_price_drift, replenish_supply, apply_market_event,
    EVENT_BUST, EVENT_BOOM, EVENT_SHORTAGE, EVENT_SURPLUS,
};
use rollyourown::models::cartel_market::{get_drug_price_tick, set_drug_price_tick, get_drug_supply, set_drug_supply};

#[test]
fn test_price_drift_changes_ticks() {
    // Start all drugs at tick 32
    let mut prices: u128 = 0;
    let mut i: u8 = 0;
    while i < 8 {
        prices = set_drug_price_tick(prices, i, 32);
        i += 1;
    };

    let drifted = apply_price_drift(prices, 0x123456789ABCDEF);
    // At least one tick should have changed
    let mut any_changed = false;
    i = 0;
    while i < 8 {
        if get_drug_price_tick(drifted, i) != 32 {
            any_changed = true;
        }
        i += 1;
    };
    assert(any_changed, 'drift should change some ticks');
}

#[test]
fn test_replenish_supply() {
    let mut supply: u128 = 0;
    // Weed (drug 1, idx 0) initial=200, set to 100
    supply = set_drug_supply(supply, 0, 100);
    let replenished = replenish_supply(supply);
    let new_val = get_drug_supply(replenished, 0);
    // deficit=100, replenish=10, new=110
    assert(new_val == 110, 'replenished to 110');
}

#[test]
fn test_event_bust() {
    let mut supply: u128 = 0;
    supply = set_drug_supply(supply, 2, 100);
    let (_, new_supply) = apply_market_event(0, supply, EVENT_BUST, 2);
    assert(get_drug_supply(new_supply, 2) == 50, 'bust halves supply');
}

#[test]
fn test_event_boom() {
    let mut prices: u128 = 0;
    prices = set_drug_price_tick(prices, 1, 20);
    let (new_prices, _) = apply_market_event(prices, 0, EVENT_BOOM, 1);
    // 20 + 20*30/100 = 26
    assert(get_drug_price_tick(new_prices, 1) == 26, 'boom +30%');
}
```

- [ ] **Step 3: Register, build, test, commit**

```bash
scarb build && scarb test -f test_market_drift 2>&1 | tail -10
git add src/systems/helpers/market_drift.cairo src/tests/test_market_drift.cairo src/lib.cairo
git commit -m "feat: add market drift — price jitter, supply replenish, market events"
```

---

## Task 8: Slot System Contract

**Files:**
- Create: `src/systems/slot_system.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml`

- [ ] **Step 1: Create slot system contract**

Create `src/systems/slot_system.cairo`:

```cairo
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
    use super::ISlotSystem;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;

    use crate::models::agent_slot::{AgentSlot, SlotCounter};
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::models::inventory::{Inventory, pack_drug_slot, unpack_drug_slot};
    use crate::config::slot_config::{get_slot_type_config, MAX_SLOTS_PER_GAME};
    use crate::systems::helpers::reputation_helpers::get_max_slots;

    fn ns() -> @ByteArray {
        @"cartel_v0"
    }

    #[abi(embed_v0)]
    impl SlotSystemImpl of super::ISlotSystem<ContractState> {

        fn hire_slot(ref self: ContractState, game_id: u32, slot_type: u8, location: u8) -> u8 {
            let mut world = self.world(ns());
            let caller = get_caller_address();

            // Check slot limit
            let mut counter: SlotCounter = world.read_model(game_id);
            let reputation: Reputation = world.read_model((game_id, caller));
            let max_slots = get_max_slots(reputation.operator_lvl);
            assert(counter.active_count < max_slots, 'slot limit reached');

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

            // Transfer from player inventory to slot
            // For simplicity, we just set the slot's product directly
            // (in full implementation, deduct from player inventory)
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

            slot.status = 0; // Inactive
            slot.drug_quantity = 0;
            world.write_model(@slot);

            let mut counter: SlotCounter = world.read_model(game_id);
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
```

- [ ] **Step 2: Register and add writer permissions**

Add to lib.cairo systems block: `pub mod slot_system;`

Add to `dojo_cartel_dev.toml` writers:
```toml
"cartel_v0-AgentSlot" = ["cartel_v0-slot_system", "cartel_v0-passive_tick"]
"cartel_v0-SlotCounter" = ["cartel_v0-slot_system"]
```

- [ ] **Step 3: Build and commit**

```bash
scarb build 2>&1 | tail -5
git add src/systems/slot_system.cairo src/lib.cairo dojo_cartel_dev.toml
git commit -m "feat: add slot system contract — hire, restock, collect, fire dealer slots"
```

---

## Task 9: Operation System Contract

**Files:**
- Create: `src/systems/operation_system.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml`

- [ ] **Step 1: Create operation system contract**

Create `src/systems/operation_system.cairo`:

```cairo
#[starknet::interface]
pub trait IOperationSystem<T> {
    fn buy_operation(ref self: T, game_id: u32, op_type: u8) -> u8;
    fn start_laundering(ref self: T, game_id: u32, op_id: u8, amount: u32);
    fn get_operation_status(self: @T, game_id: u32, op_id: u8) -> (u8, u32, u8); // (op_type, processing, turns_left)
}

#[dojo::contract]
pub mod operation_system {
    use super::IOperationSystem;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;

    use crate::models::operation::{Operation, OperationCounter};
    use crate::models::wallet::WalletState;
    use crate::models::reputation::Reputation;
    use crate::config::operation_config::{get_op_config, MAX_OPERATIONS};
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
            let mut counter: OperationCounter = world.read_model(game_id);
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
```

- [ ] **Step 2: Register and add writers**

Add to lib.cairo: `pub mod operation_system;`

Add to `dojo_cartel_dev.toml`:
```toml
"cartel_v0-Operation" = ["cartel_v0-operation_system", "cartel_v0-passive_tick"]
"cartel_v0-OperationCounter" = ["cartel_v0-operation_system"]
```

- [ ] **Step 3: Build and commit**

```bash
scarb build 2>&1 | tail -5
git add src/systems/operation_system.cairo src/lib.cairo dojo_cartel_dev.toml
git commit -m "feat: add operation system — buy laundering businesses, start laundering"
```

---

## Task 10: Passive Tick System

**Files:**
- Create: `src/systems/passive_tick.cairo`
- Create: `src/tests/test_passive_tick.cairo`
- Modify: `src/lib.cairo`
- Modify: `dojo_cartel_dev.toml`

- [ ] **Step 1: Create passive tick system**

Create `src/systems/passive_tick.cairo`:

```cairo
#[starknet::interface]
pub trait IPassiveTick<T> {
    fn process_tick(ref self: T, game_id: u32, tick_seed: felt252);
}

#[dojo::contract]
pub mod passive_tick {
    use super::IPassiveTick;
    use starknet::{ContractAddress, get_caller_address};
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
                    let heat = world.read_model::<_, HeatProfile>((game_id, slot.owner));
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
```

- [ ] **Step 2: Add writer permissions**

Add to `dojo_cartel_dev.toml`:
```toml
"cartel_v0-CartelMarket" = ["cartel_v0-cartel_game", "cartel_v0-passive_tick"]
"cartel_v0-WalletState" = ["cartel_v0-cartel_game", "cartel_v0-slot_system", "cartel_v0-operation_system", "cartel_v0-passive_tick"]
"cartel_v0-Reputation" = ["cartel_v0-cartel_game", "cartel_v0-slot_system", "cartel_v0-operation_system"]
```

- [ ] **Step 3: Register, build, commit**

```bash
scarb build 2>&1 | tail -5
git add src/systems/passive_tick.cairo src/lib.cairo dojo_cartel_dev.toml
git commit -m "feat: add passive tick system — dealer sales, laundering, market drift, events"
```

---

## Task 11: Wire Passive Tick into Game Contract

**Files:**
- Modify: `src/systems/cartel_game.cairo`

- [ ] **Step 1: Add passive tick call at end of reveal_resolve**

In `cartel_game.cairo`'s `reveal_resolve` function, after the turn advance and heat decay logic, add a call to process the passive tick. Since contracts can't directly call each other easily in Dojo, integrate the tick logic directly:

Add an internal `_process_passive_tick` method that calls the same helper functions used by `passive_tick.cairo`. This keeps the tick processing atomic with the turn resolution.

The key additions:
- After turn advance, call dealer processing (slot_helpers)
- Process operations (operation_helpers)  
- Apply market drift (market_drift)
- Award reputation XP for the Manage and Invest actions

Also wire up the Manage action (1 AP) to call slot restock/strategy, and Invest action (1 AP) to trigger laundering.

- [ ] **Step 2: Verify build and all tests pass**

```bash
scarb build 2>&1 | tail -5
scarb test 2>&1 | tail -5
git add src/systems/cartel_game.cairo
git commit -m "feat: wire passive tick into reveal_resolve — dealers, laundering, market drift per turn"
```

---

## Task 12: Frontend — Domain Classes + Hooks

**Files:**
- Create: `web/src/dojo/class/CartelSlot.ts`
- Create: `web/src/dojo/class/CartelOperation.ts`
- Create: `web/src/dojo/class/CartelCartel.ts`
- Create: `web/src/dojo/hooks/useCartelSlots.ts`
- Create: `web/src/dojo/hooks/useCartelOperations.ts`

- [ ] **Step 1: Create CartelSlot class**

Create `web/src/dojo/class/CartelSlot.ts`:

```typescript
import { DRUG_NAMES } from "./CartelInventory";
import { LOCATION_NAMES } from "./CartelPlayer";

export enum SlotType { None = 0, Dealer = 1, Cook = 2, Runner = 3, Muscle = 4 }
export enum SlotStatus { Inactive = 0, Active = 1, Busted = 2, LayingLow = 3 }
export const STRATEGY_NAMES: Record<number, string> = { 0: "Cautious", 1: "Aggressive", 2: "Balanced" };

export interface SlotState {
  gameId: number; slotId: number; slotType: SlotType; status: SlotStatus;
  strategy: number; location: number; drugId: number; drugQuantity: number;
  earnings: number; reliability: number; stealth: number; salesmanship: number;
}

export class CartelSlot {
  state: SlotState;
  constructor(state: SlotState) { this.state = state; }
  get locationName(): string { return LOCATION_NAMES[this.state.location] || "Unknown"; }
  get drugName(): string { return DRUG_NAMES[this.state.drugId] || "None"; }
  get strategyName(): string { return STRATEGY_NAMES[this.state.strategy] || "Unknown"; }
  get isActive(): boolean { return this.state.status === SlotStatus.Active; }
  get isBusted(): boolean { return this.state.status === SlotStatus.Busted; }

  static fromRaw(raw: any): CartelSlot {
    return new CartelSlot({
      gameId: Number(raw.game_id), slotId: Number(raw.slot_id),
      slotType: Number(raw.slot_type), status: Number(raw.status),
      strategy: Number(raw.strategy), location: Number(raw.location),
      drugId: Number(raw.drug_id), drugQuantity: Number(raw.drug_quantity),
      earnings: Number(raw.earnings_held),
      reliability: Number(raw.reliability), stealth: Number(raw.stealth),
      salesmanship: Number(raw.salesmanship),
    });
  }
}
```

- [ ] **Step 2: Create CartelOperation and CartelCartel classes**

Create `web/src/dojo/class/CartelOperation.ts`:

```typescript
export const OP_TYPE_NAMES: Record<number, string> = {
  1: "Laundromat", 2: "Car Wash", 3: "Taco Shop", 4: "Post Office",
};

export interface OperationState {
  gameId: number; opId: number; opType: number; level: number;
  capacityPerTurn: number; processingAmount: number; processingTurnsLeft: number;
  totalLaundered: number;
}

export class CartelOperation {
  state: OperationState;
  constructor(state: OperationState) { this.state = state; }
  get typeName(): string { return OP_TYPE_NAMES[this.state.opType] || "Unknown"; }
  get isProcessing(): boolean { return this.state.processingAmount > 0; }

  static fromRaw(raw: any): CartelOperation {
    return new CartelOperation({
      gameId: Number(raw.game_id), opId: Number(raw.op_id),
      opType: Number(raw.op_type), level: Number(raw.level),
      capacityPerTurn: Number(raw.capacity_per_turn),
      processingAmount: Number(raw.processing_amount),
      processingTurnsLeft: Number(raw.processing_turns_left),
      totalLaundered: Number(raw.total_laundered),
    });
  }
}
```

Create `web/src/dojo/class/CartelCartel.ts`:

```typescript
import { CartelInventory } from "./CartelInventory";

export interface CartelState {
  gameId: number; name: string; slotCount: number; treasury: number;
  stashSlots: bigint[];
}

export class CartelCartel {
  state: CartelState;
  constructor(state: CartelState) { this.state = state; }

  get stash(): CartelInventory {
    return new CartelInventory(
      this.state.stashSlots.map(s => CartelInventory.unpackSlot(s))
    );
  }

  static fromRaw(raw: any): CartelCartel {
    return new CartelCartel({
      gameId: Number(raw.game_id), name: raw.name,
      slotCount: Number(raw.slot_count), treasury: Number(raw.treasury),
      stashSlots: [
        BigInt(raw.stash_slot_0), BigInt(raw.stash_slot_1),
        BigInt(raw.stash_slot_2), BigInt(raw.stash_slot_3),
        BigInt(raw.stash_slot_4), BigInt(raw.stash_slot_5),
      ],
    });
  }
}
```

- [ ] **Step 3: Create hooks (placeholder subscriptions)**

Create `web/src/dojo/hooks/useCartelSlots.ts` and `web/src/dojo/hooks/useCartelOperations.ts` with placeholder state similar to `useCartelGame.ts`.

- [ ] **Step 4: Commit**

```bash
git add web/src/dojo/class/CartelSlot.ts web/src/dojo/class/CartelOperation.ts web/src/dojo/class/CartelCartel.ts web/src/dojo/hooks/useCartelSlots.ts web/src/dojo/hooks/useCartelOperations.ts
git commit -m "feat: add frontend domain classes and hooks for slots, operations, cartel"
```

---

## Task 13: Frontend — Dealer Management + Operations UI

**Files:**
- Create: `web/src/components/cartel/DealerPanel.tsx`
- Create: `web/src/components/cartel/DealerCard.tsx`
- Create: `web/src/components/cartel/OperationPanel.tsx`
- Create: `web/src/components/cartel/CartelOverview.tsx`
- Create: `web/src/components/cartel/ReputationTree.tsx`
- Create: `web/src/pages/cartel/[gameId]/dealers.tsx`
- Create: `web/src/pages/cartel/[gameId]/operations.tsx`
- Create: `web/src/pages/cartel/[gameId]/empire.tsx`

- [ ] **Step 1: Create DealerCard component**

```tsx
// Shows single dealer: location, drug, quantity, earnings, status, strategy dropdown
// Buttons: Restock, Collect, Fire
```

- [ ] **Step 2: Create DealerPanel**

```tsx
// Lists all dealer slots as DealerCards
// "Hire Dealer" button at top with location picker
```

- [ ] **Step 3: Create OperationPanel**

```tsx
// Lists owned operations with type, capacity, processing status
// "Buy Operation" button with type selector
// "Start Laundering" button with amount input
```

- [ ] **Step 4: Create CartelOverview**

```tsx
// Summary: total dealers, total operations, treasury, stash contents
// Links to dealers and operations pages
```

- [ ] **Step 5: Create ReputationTree**

```tsx
// 3-column display: Trader | Enforcer | Operator
// Each shows: level, XP bar to next level, current unlocks
```

- [ ] **Step 6: Create pages**

Create `dealers.tsx`, `operations.tsx`, `empire.tsx` pages that compose the above components.

- [ ] **Step 7: Commit**

```bash
git add web/src/components/cartel/ web/src/pages/cartel/
git commit -m "feat: add dealer management, operations, and empire UI pages"
```

---

## Task 14: Integration Test — Stage 2 Game Loop

**Files:**
- Create: `src/tests/test_stage2_integration.cairo`
- Modify: `src/lib.cairo`

- [ ] **Step 1: Write integration test**

Test the full Stage 2 flow through helpers:
1. Reputation XP award → level up → unlock check
2. Dealer sales calculation → commission split
3. Bust risk at various heat levels
4. Operation laundering: start → process 2 ticks → clean cash produced
5. Market drift changes prices
6. Market events modify supply

- [ ] **Step 2: Register, run tests, commit**

```bash
scarb test 2>&1 | tail -10
git add src/tests/test_stage2_integration.cairo src/lib.cairo
git commit -m "test: add Stage 2 integration test — reputation, dealers, laundering, market drift"
```

---

## Summary

| Task | Component | Files | Key Feature |
|------|-----------|-------|-------------|
| 1 | AgentSlot model + config | 2 new | Dealer/crew entity with stats |
| 2 | Cartel model | 1 new | Empire entity with stash |
| 3 | Operation model + config | 2 new | Laundering business entity |
| 4 | Reputation config + helpers | 3 new + tests | XP/level/unlock system |
| 5 | Slot helpers | 1 new + tests | Dealer sales, bust risk |
| 6 | Operation helpers | 1 new + tests | Laundering processing |
| 7 | Market drift helpers | 1 new + tests | Price jitter, events |
| 8 | Slot system contract | 1 new | Hire/restock/collect/fire |
| 9 | Operation system contract | 1 new | Buy ops, start laundering |
| 10 | Passive tick system | 1 new | Between-turn processing |
| 11 | Wire tick into game contract | 1 modify | Atomic tick per turn |
| 12 | Frontend domain classes + hooks | 5 new | TS models for slots/ops |
| 13 | Frontend UI pages | 8 new | Dealer mgmt, ops, empire |
| 14 | Integration test | 1 new | Full Stage 2 flow test |
| **Total** | | **~30 files** | |
