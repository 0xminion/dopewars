# Stage 2 Code Review -- Claude

**Date:** 2026-03-31
**Branch:** `feat/cartel-game-stage2`
**Scope:** 36 files changed, 2,487 lines added (Cairo contracts + TypeScript frontend)
**Tests:** 73 passing, 0 failing (25 new tests for Stage 2)

## Summary

**Ship with fixes for C1-C4.** Stage 2 delivers the Empire layer: agent slots (dealers), laundering operations, passive tick processing, market drift, and reputation unlocks. The architecture is clean and the passive tick integration into `reveal_resolve` is well-designed. However, there are four critical issues: the `Manage` and `Invest` action implementations inside `cartel_game.cairo` are duplicated with a dead inner version, the `restock_slot` endpoint does not deduct from player inventory (free item duplication), the `OperationCounter` and `SlotCounter` are keyed only on `game_id` making them shared across all players in the same game, and `earnings_held` on `AgentSlot` (u32) has no saturating add protection in the passive tick hot path.

---

## Critical Issues

### C1. `restock_slot` does not deduct drugs from player inventory -- free item duplication

**File:** `src/systems/slot_system.cairo:98-119`

```cairo
// Transfer from player inventory to slot
// For simplicity, we just set the slot's product directly
// (in full implementation, deduct from player inventory)
slot.drug_id = drug_id;
slot.drug_quantity = slot.drug_quantity + quantity;
```

The comment explicitly acknowledges this is incomplete. A player can call `restock_slot` with arbitrary `drug_id` and `quantity` values, manufacturing drugs from nothing. The slot then sells these drugs via the passive tick, generating real dirty_cash earnings. This is an infinite money exploit.

**Fix:** Read the player's `Inventory`, find the slot containing the specified `drug_id`, assert sufficient quantity, deduct from inventory, and add to the dealer slot. Alternatively, require that `restock_slot` only be callable via the `Manage` action within `reveal_resolve` (so the inventory is already in-memory).

### C2. `SlotCounter` and `OperationCounter` are keyed only on `game_id` -- shared across all players

**File:** `src/models/agent_slot.cairo:56-63`, `src/models/operation.cairo:19-26`

```cairo
pub struct SlotCounter {
    #[key]
    pub game_id: u32,
    pub next_slot_id: u8,
    pub active_count: u8,
}
```

Both counters have only `game_id` as their key. In a multiplayer game, all players share the same `SlotCounter` and `OperationCounter`. This means:
1. Player A hiring a slot increments `active_count` for everyone, consuming Player B's slot budget.
2. `slot_id` values are globally sequential -- Player A gets slot 0, Player B gets slot 1, etc. This is fine for addressing, but the `active_count` limit check (`counter.active_count < max_slots`) applies the limit globally, not per-player.
3. If the game supports 6 max slots total across all players, one player can exhaust the pool.

Currently Stage 2 is single-player, so this works. But the model is broken for the multiplayer expansion.

**Fix:** Add `owner: ContractAddress` as a second key field on both counters, or track per-player slot counts on the `Cartel` model.

### C3. `earnings_held` overflow in passive tick -- no saturating add

**File:** `src/systems/cartel_game.cairo:845`

```cairo
slot.earnings_held = slot.earnings_held + owner_cut;
```

`earnings_held` is `u32`. Each tick, a dealer with 100+ units of an expensive drug at a high tick can generate revenue in the thousands. Over many turns without collecting, `earnings_held` will overflow and panic, bricking the passive tick (and therefore all `reveal_resolve` calls for that player).

For example: Drug 8 at tick 63 = base 1000 + 60*63 = 4780 per unit. Selling 30% of 500 units = 150 units. Revenue = 717,000. Owner cut (80%) = 573,600. After just 7 turns without collecting: 4,015,200. After 8: 4,588,800. The u32 max is 4,294,967,295, so it takes ~7.5 turns to overflow with aggressive settings on a loaded dealer.

The `collect_earnings` function (slot_system.cairo:132-138) correctly uses saturating add when crediting the wallet, but the passive tick accumulation does not.

**Fix:** Apply the same saturating add pattern used in `collect_earnings`:
```cairo
let max_cash: u32 = 0xFFFFFFFF;
if slot.earnings_held > max_cash - owner_cut {
    slot.earnings_held = max_cash;
} else {
    slot.earnings_held = slot.earnings_held + owner_cut;
}
```

### C4. `InternalImpl::execute_manage` and `execute_invest` are dead stubs -- real logic is on `PassiveTickImpl`

**File:** `src/systems/cartel_game.cairo:743-765` vs `src/systems/cartel_game.cairo:770-809`

The `InternalImpl` contains two stub functions:
```cairo
fn execute_manage(...) {
    // TODO: full implementation once Dojo model cross-import issue resolved
}
fn execute_invest(...) {
    // TODO: full implementation once Dojo model cross-import issue resolved
}
```

The actual implementations are on `PassiveTickImpl`. The `execute_action` dispatcher at line 440-452 correctly calls the `PassiveTickImpl` versions. However:
1. The dead stubs waste code space and are confusing.
2. If someone later calls `InternalImpl::execute_manage` thinking it's the real one, it silently no-ops.
3. The `Manage` action at line 440 calls `PassiveTickImpl::execute_manage` but also awards 3 operator XP at line 443 -- this XP award happens outside the manage function, meaning it's awarded even though the stub would do nothing (if the wrong impl were called).

**Fix:** Remove the dead `InternalImpl::execute_manage` and `InternalImpl::execute_invest` stubs entirely. Consider moving the XP awards into the `PassiveTickImpl` versions for encapsulation.

---

## Important Issues

### I1. No passive tick guard -- can be called multiple times per turn via standalone `passive_tick` contract

**File:** `src/systems/passive_tick.cairo:29-31`

The standalone `passive_tick` contract exposes `process_tick(game_id, tick_seed)` with no authorization check. Anyone can call it with any `game_id`. There is also no turn-based guard preventing multiple calls per turn.

The inline version in `cartel_game.cairo:run_passive_tick` (called from `reveal_resolve`) is safe because it runs exactly once per `reveal_resolve` call. But the standalone `passive_tick.cairo` contract processes ALL slots and operations for a game_id regardless of owner, and can be called repeatedly.

**Fix:** Either remove the standalone `passive_tick` contract (it appears to be a development scaffold duplicating the inline version), or add a `last_processed_turn` field to a game-level model and assert it hasn't been processed this turn.

### I2. `max_dealer_slots` in `GameConfig` / `ModeConfig` is never enforced -- only reputation-based `max_slots` is used

**File:** `src/config/game_modes.cairo:8` vs `src/systems/slot_system.cairo:38`

The `ModeConfig` defines `max_dealer_slots: u8` (2 for casual, 4 for ranked), and it's stored in `GameConfig`. However, `slot_system::hire_slot` only checks the reputation-based `get_max_slots(reputation.operator_lvl)`. The mode-level cap is ignored. A level 4 operator in casual mode can hire 6 slots despite `max_dealer_slots: 2`.

**Fix:** Enforce `min(get_max_slots(operator_lvl), game_config.max_dealer_slots)` or remove `max_dealer_slots` from the config if reputation is the sole gate.

### I3. `Invest` action uses `quantity * 10` as laundering amount -- undocumented multiplier

**File:** `src/systems/cartel_game.cairo:798`

```cairo
let amount: u32 = amount_u16.into() * 10;
```

The `Action.quantity` field is `u16`. The `execute_invest` function multiplies it by 10 to get the actual dirty cash amount. This is presumably to work around the u16 range (max 65535, so max launder = 655,350). However:
1. This multiplier is undocumented -- the frontend would need to know to divide by 10 when populating `quantity`.
2. With `quantity = 65535` and multiplier 10, `amount = 655,350`. This fits in u32 but is an odd API.
3. The standalone `operation_system::start_laundering` takes `amount: u32` directly without the multiplier. The two paths have inconsistent interfaces.

**Fix:** Document the multiplier. Ensure the frontend sends `desired_amount / 10` in the `quantity` field of the `Invest` action. Add a comment explaining why.

### I4. Reputation XP thresholds: `trader_xp` and `operator_xp` are `u16` (max 65535) -- XP can overflow silently

**File:** `src/systems/helpers/reputation_helpers.cairo:7-8`

```cairo
reputation.trader_xp = reputation.trader_xp + amount;
```

`trader_xp` is `u16` with max 65535. XP is awarded in small increments (3-20 per action), so this is unlikely to overflow in a normal game. But in a long-running game with many turns, or if XP awards are increased, this could wrap around, causing a level-5 player to suddenly drop to level 0.

**Fix:** Use saturating add: `if reputation.trader_xp > 65535 - amount { 65535 } else { reputation.trader_xp + amount }`.

### I5. `fire_slot` does not check slot status -- can fire an already-inactive slot, decrementing `active_count` below actual

**File:** `src/systems/slot_system.cairo:144-159`

A player can call `fire_slot` on a slot with `status == 0` (Inactive). The function sets `status = 0` (no-op) and decrements `active_count`. If called repeatedly on the same inactive slot, `active_count` would underflow (the `if > 0` guard prevents panic but allows it to reach 0 prematurely).

**Fix:** Add `assert(slot.status != 0, 'already inactive')`.

### I6. `slot.drug_quantity` subtraction in passive tick can panic if sales > quantity

**File:** `src/systems/cartel_game.cairo:844`

```cairo
slot.drug_quantity = slot.drug_quantity - qty_sold;
```

The `calculate_dealer_sales` function caps `qty_sold` at `quantity`, so this should not underflow. However, the guarantee is implicit via the helper. If someone later modifies the helper without updating the caller, this becomes a panic. Consider adding a defensive check.

### I7. `operation_system::buy_operation` checks `counter.active_count < max_ops` but counter is global (see C2)

Same issue as C2 but for operations. The `OperationCounter` is per-game, not per-player. In a multiplayer game, one player buying operations reduces the limit for all players.

### I8. Trader reputation discount (`get_price_discount`) is defined but never applied to buy prices

**File:** `src/config/reputation_config.cairo:8` and `src/systems/helpers/reputation_helpers.cairo:38-41`

The `get_price_discount(trader_lvl)` function returns discounts of 5-20%, but `execute_buy` in `cartel_game.cairo:534-587` never calls it. Trader reputation grants access to higher drug tiers but provides no price benefit despite the config defining one.

**Fix:** Apply the discount in `execute_buy`: `total_cost = total_cost * (100 - discount) / 100`.

### I9. Drug tier access (`can_access_drug`) is defined but never enforced in buy actions

**File:** `src/systems/helpers/reputation_helpers.cairo:18-21`

The `can_access_drug(trader_lvl, drug_id)` helper exists but is never called from `execute_buy`. A level-0 player can buy any drug tier. The reputation config defines progressive unlocks (drug tiers 4/5/6/7/8 by level) but they're not enforced.

**Fix:** Add to `execute_buy`: `assert(can_access_drug(rep.trader_lvl, drug_id), 'drug tier locked')`.

---

## Minor Issues

### M1. Duplicate passive tick logic -- standalone contract vs inline in `cartel_game`

**Files:** `src/systems/passive_tick.cairo` vs `src/systems/cartel_game.cairo:811-946`

The passive tick logic is implemented twice: once as a standalone `passive_tick` contract and once inline in `cartel_game.cairo` as `PassiveTickImpl::run_passive_tick`. They are nearly identical but maintained separately. Any bug fix or feature addition must be applied to both.

**Fix:** Remove the standalone `passive_tick.cairo` or refactor both to call a shared pure-function helper.

### M2. `Cartel` model is defined but never read or written

**File:** `src/models/cartel.cairo`

The `Cartel` model with stash slots and treasury is defined and registered in `lib.cairo` but no system ever creates or uses it. The `CartelCartel.ts` frontend class maps to this model, but no data will ever be available.

### M3. Commission rate is hardcoded to 20% in passive tick instead of using config

**Files:** `src/systems/cartel_game.cairo:842`, `src/config/slot_config.cairo:19`

The passive tick calls `apply_commission(revenue, 20)` with a hardcoded 20%. The `SlotTypeConfig` defines `commission_pct: 20` for dealers, but this config value is never read during the passive tick. If the config changes, the passive tick won't reflect it.

**Fix:** Read the config: `let config = get_slot_type_config(slot.slot_type); apply_commission(revenue, config.commission_pct)`.

### M4. `SlotType`, `ControllerType`, `SlotStatus` enums defined but never used

**File:** `src/models/agent_slot.cairo:3-28`

The model stores types as `u8` fields. The enums are defined for documentation but never used in match statements or conversions. The enum values must be kept in sync with the magic numbers manually.

### M5. Market event type 0 is possible but maps to `EVENT_NONE`

**File:** `src/systems/cartel_game.cairo:926`

```cairo
let event_type: u8 = (Into::<felt252, u256>::into(rng) % 4).try_into().unwrap();
```

This produces values 0-3, then `event_type + 1` maps to 1-4 (BUST through SURPLUS). This is correct. However, the same `rng` value is used for both the event roll (line 919) and the event type selection (line 926), which means the event type is not independent of the trigger roll. This could create subtle distribution biases.

### M6. Frontend hooks are placeholder stubs

**Files:** `web/src/dojo/hooks/useCartelSlots.ts`, `web/src/dojo/hooks/useCartelOperations.ts`

Both hooks return empty arrays immediately. The Torii subscription is not wired. This is expected for Stage 2 scaffolding but should be tracked.

### M7. `OperationPanel` progress calculation assumes max 5 turns

**File:** `web/src/components/cartel/OperationPanel.tsx:31`

```ts
const progressPct = operation.isProcessing ? Math.max(0, Math.min(100, (1 - processingTurnsLeft / 5) * 100)) : 0;
```

The hardcoded divisor of 5 does not match the config (all operation types use 2 turns). Progress will show 80% after queuing (2/5 = 40%, 1 - 0.4 = 60%... actually (1 - 2/5)*100 = 60%) and 80% after one tick (1/5 = 20%, 1 - 0.2 = 80%). It should use the operation's configured `processing_turns`.

### M8. `CartelOverview` references `CartelReputation` class that's not in the diff

**File:** `web/src/components/cartel/CartelOverview.tsx:4`, `web/src/components/cartel/ReputationTree.tsx:2`

Both components import `CartelReputation` from `../../dojo/class/CartelReputation`, but this class is not among the new files added in Stage 2. It either pre-exists from Stage 1 or is missing.

### M9. `EmpirePage` imports `useCartelGame` hook not included in Stage 2

**File:** `web/src/pages/cartel/[gameId]/empire.tsx:6`

The `useCartelGame` hook is imported but not in the Stage 2 diff. Same pattern as M8.

### M10. `next_slot_id` is `u8` -- max 255 slots lifetime per game

**File:** `src/models/agent_slot.cairo:61`

Since `next_slot_id` only increments (never recycles), a game can create at most 255 slots total (across all hires, including fired slots). This is sufficient for normal play but could be hit in edge cases with heavy hire/fire cycling.

---

## Security Assessment

### Authorization Checks

| Endpoint | Auth Check | Verdict |
|---|---|---|
| `slot_system::hire_slot` | Uses `get_caller_address()` as owner | OK -- caller becomes owner |
| `slot_system::set_strategy` | `assert(slot.owner == caller)` | OK |
| `slot_system::restock_slot` | `assert(slot.owner == caller)` | **Partial** -- checks ownership but doesn't deduct from inventory (C1) |
| `slot_system::collect_earnings` | `assert(slot.owner == caller)` | OK |
| `slot_system::fire_slot` | `assert(slot.owner == caller)` | OK (but see I5) |
| `operation_system::buy_operation` | Uses `get_caller_address()` as owner | OK |
| `operation_system::start_laundering` | `assert(operation.owner == caller)` | OK |
| `passive_tick::process_tick` | **No auth check** | **Vulnerable** (I1) |
| `cartel_game::Manage` (inline) | `assert(slot.owner == player_id)` | OK |
| `cartel_game::Invest` (inline) | `assert(operation.owner == player_id)` | OK |

### State Consistency

The passive tick in `reveal_resolve` runs atomically within the same transaction as action execution. All state (wallet, player, inventory, rep, heat) is written together at the end of `reveal_resolve`. The passive tick modifies `AgentSlot` and `Operation` models via `world.write_model` inside the loop, but these are separate models from the player state written at the end, so there's no conflict.

**Risk:** If the passive tick panics (e.g., from C3 overflow), the entire `reveal_resolve` transaction reverts, leaving the player stuck with an unresolvable commit. They would need to create a new game.

### Wallet Arithmetic

| Location | Operation | Overflow Protection |
|---|---|---|
| `slot_system::collect_earnings` | `dirty_cash += earnings` | Saturating add | OK |
| `passive_tick (inline)::clean_cash` | `clean_cash += clean_produced` | Saturating add | OK |
| `passive_tick (inline)::earnings_held` | `earnings_held += owner_cut` | **No protection** | C3 |
| `slot_system::hire_slot` | `dirty_cash -= hire_cost` | Assert >= | OK |
| `operation_system::buy_operation` | `dirty_cash -= purchase_cost` | Assert >= | OK |
| `operation_system::start_laundering` | `dirty_cash -= queue_amount` | Assert >= | OK |
| `Invest (inline)` | `dirty_cash -= queue_amount` | Assert >= | OK |

---

## Test Coverage Analysis

### What is tested (good coverage -- 25 new tests)
- Dealer sales: cautious, aggressive, minimum-one, revenue calculation (4 tests)
- Bust risk: low heat/high stealth, high heat/aggressive (2 tests)
- Commission split (1 test)
- Laundering: start within/exceeding capacity, already processing, tick completes, tick still processing, empty, total capacity (7 tests)
- Reputation: award XP, level up, drug access by level, max slots, crew power bonus, price discount (6 tests)
- Market drift: price changes, supply replenish, event bust, event boom (4 tests)
- Full integration: reputation + dealers + laundering + market drift end-to-end (1 test)

### What is NOT tested (gaps)
- **No contract-level tests:** No tests call `hire_slot`, `fire_slot`, `collect_earnings`, `buy_operation`, or `start_laundering` through the Dojo world. All tests are unit tests on pure helper functions.
- **No passive tick integration test via `reveal_resolve`.** The inline passive tick is untested at the contract level.
- **No test for `Manage` or `Invest` actions** through the action dispatch path.
- **No test for `restock_slot`** (which would reveal the C1 bug).
- **No test for `fire_slot` on an inactive slot** (I5).
- **No test for slot limit enforcement** (hiring up to max_slots and asserting the next hire fails).
- **No test for operation unlock level enforcement** (buying a Taco Shop at operator level 1 should fail).
- **No overflow test for `earnings_held`** (C3).
- **No test for the standalone `passive_tick` contract** (I1).
- **No adversarial tests** (calling endpoints as non-owner, manipulating shared counters in multiplayer scenario).
- **No market drift boundary tests** (prices at 0 or 63 drifting further).

---

## Positive Notes

1. **Clean passive tick integration.** Embedding the tick inside `reveal_resolve` ensures exactly-once processing per turn without needing a separate guard. The inline approach with `PassiveTickImpl` is well-structured.

2. **Correct laundering flow.** Dirty cash is properly deducted when queued (both in `operation_system::start_laundering` and `Invest` action). Clean cash is credited only when processing completes after the configured delay. The 2-turn delay is correctly enforced.

3. **Market drift is well-designed.** Using Poseidon-derived randomness per drug per location, with bounded tick changes (-3 to +3) and proper clamping at MIN_TICK/MAX_TICK. Supply replenishment at 10% of deficit per tick creates natural mean-reversion. Market events add volatility at a reasonable 10% rate.

4. **Reputation system is flexible.** Three independent branches (Trader, Enforcer, Operator) with 5 levels each. The config-driven unlock tables make it easy to tune. XP is awarded incrementally across different actions.

5. **Frontend components are production-quality.** The DealerCard, OperationPanel, and ReputationTree components have proper loading states, null handling, and clean styling. The TypeScript domain classes correctly map Cairo model fields.

6. **Comprehensive helper test coverage.** The pure-function helpers (sales, bust risk, laundering, market drift) all have focused unit tests with documented expected values. The integration test exercises the full Stage 2 pipeline.

7. **Saturating arithmetic where it matters most.** Wallet operations in `collect_earnings` and the clean cash credit path both use explicit overflow guards.

8. **Config-driven operation tiers.** The four operation types (Laundromat through Post Office) have progressively better capacity and higher costs, gated by operator level. This creates a natural progression curve.
