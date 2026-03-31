# Stage 1 Code Review -- Claude

**Date:** 2026-03-31
**Branch:** `feat/cartel-game-stage1`
**Scope:** 66 files changed, 3,447 lines added (Cairo contracts + TypeScript frontend)
**Tests:** 48 passing, 0 failing

## Summary

**Ship with fixes.** The implementation is solid overall -- clean architecture, good separation of concerns, well-structured commit-reveal pattern, and comprehensive unit tests for helpers. However, there are several critical and important issues that must be addressed before merging, primarily around authorization gaps, a broken frontend hash function, missing travel validation in the execution path, and potential integer overflow in wallet arithmetic.

---

## Critical Issues

### C1. Frontend `hashActions` does NOT match Cairo's Poseidon hash -- commit-reveal is broken on-chain

**File:** `web/src/dojo/hooks/useCartelSystems.ts:30-39`

The TypeScript `hashActions()` function uses a homebrew LCG-style hash:
```ts
h = (h ^ v) * 6364136223846793005n + 1442695040888963407n;
h = BigInt.asUintN(64, h);
```

The Cairo contract uses Poseidon hashing (`PoseidonTrait::new().update(salt).update(action_felt)...finalize()`). These will **never** produce the same output. Every `reveal_resolve` call will fail with `'hash mismatch'` because the commitment computed client-side will not match the on-chain verification.

**Fix:** Replace `hashActions` in TypeScript with actual Poseidon hashing. Use `@scure/starknet` or `starknet.js`'s `hash.computePoseidonHashOnElements()` with the same serialization scheme used in `action_to_felt`.

### C2. No adjacency check during travel execution -- player can teleport anywhere

**File:** `src/systems/cartel_game.cairo:362-377` (execute_action Travel branch)

The `execute_travel` function at line 420 updates the player location to `destination` without verifying that the destination is adjacent (or that 2 AP is paid for distant travel). The `validate_action_batch` function (line 243) checks AP budget, and `validate_action` checks AP cost based on adjacency, but the actual `execute_action` at line 359 hardcodes `is_distant = false` and always uses cost 1:

```cairo
let is_distant = false; // simplified: use action_ap_cost default
let cost = action_ap_cost(action.action_type, is_distant);
```

This means `validate_action_batch` may approve 2 AP for distant travel but `execute_action` only charges 1. More critically, there is no check that `destination` is a valid location (1-6) or that it's actually reachable. A player could travel to location 0 or 255.

**Fix:** Add adjacency validation in `execute_travel`. Validate `destination >= 1 && destination <= LOCATION_COUNT`. If not adjacent, charge 2 AP.

### C3. `wallet.dirty_cash` overflow on sell -- u32 addition can panic

**File:** `src/systems/cartel_game.cairo:572`

```cairo
wallet.dirty_cash += earnings;
```

`dirty_cash` is `u32` (max 4,294,967,295). With high-value drugs at high ticks, `earnings` could be large. For example, drug 8 (Cocaine) at tick 32 = base 1000 + 60*32 = 2920 per unit. Selling 65535 units (max u16) = 191,239,200 which fits, but with effects multiplier up to 200% (4 effects at 50 bps each), the price becomes 2920 * (100+200)/100 = 8760 per unit * 65535 = ~574M which overflows u32. This would panic and brick the player's game state.

Similarly, `total_cost` in `execute_buy` (line 515) is `u32` which could overflow for large quantities of expensive drugs.

**Fix:** Either cap quantity per action (e.g., max 999), use u64 for cash fields, or add overflow-safe arithmetic with explicit caps.

### C4. No check that `commit.turn == player.turn` guards against replay of old commits

**File:** `src/systems/cartel_game.cairo:238`

This check exists (`assert(commit.turn == player.turn, 'wrong turn')`), which is good. However, the commit is **not cleared** if a player calls `commit_actions` again on the same turn -- it simply overwrites. This means a player could:
1. Commit hash H1 for a set of actions
2. See the mempool / wait for market conditions to change
3. Commit hash H2 with different actions
4. Reveal H2

This undermines the commit-reveal pattern. While this may be by design (allowing re-commits before reveal), it should be documented. In a multiplayer context, this is a griefing vector because a player can wait to see others' reveals before submitting their own.

**Severity:** Critical if multiplayer turns are planned; acceptable for single-player Stage 1 if documented.

---

## Important Issues

### I1. `ap_spent` parameter in `commit_actions` is never enforced against actual action costs

**File:** `src/systems/cartel_game.cairo:202-219`

The `ap_spent` parameter is validated against `player.ap_remaining` but then stored without being used. During `reveal_resolve`, the actual AP cost is recalculated from the action batch. The stored `ap_spent` is never compared to the actual cost. This parameter serves no purpose and could confuse integrators.

**Fix:** Either remove `ap_spent` from the interface and compute it from the revealed actions, or verify that `commit.ap_spent == calculated_ap_cost` during reveal.

### I2. `ap_used` is accumulated in `execute_action` but never checked or used

**File:** `src/systems/cartel_game.cairo:255-274`

The `ap_used` variable is incremented in each `execute_action` call but is never read after the loop. Combined with the hardcoded `is_distant = false`, the per-action AP accounting is broken. The only AP check is the batch-level `validate_action_batch` at line 243.

**Fix:** Either track AP properly per-action (deducting from `player.ap_remaining` as actions execute) or remove the `ap_used` variable if batch validation is sufficient.

### I3. Player status mismatch between Cairo and TypeScript

**File (Cairo):** `src/systems/cartel_game.cairo:76-78`
```cairo
const STATUS_ACTIVE: u8 = 1;
const STATUS_DEAD: u8 = 2;
const STATUS_FINISHED: u8 = 3;
```

**File (TS):** `web/src/dojo/class/CartelPlayer.ts:1-7`
```ts
export enum PlayerStatus {
  Normal = 0,    // Cairo has no status 0
  Jailed = 1,    // Cairo: ACTIVE
  Hospitalized = 2, // Cairo: DEAD
  Dead = 3,      // Cairo: FINISHED
  Finished = 4,  // Cairo has no status 4
}
```

The frontend enum does not match the contract constants at all. `isActive` checks `status === PlayerStatus.Normal` (0), but Cairo sets status to 1 (STATUS_ACTIVE). The player will never appear active in the UI.

**Fix:** Align the TypeScript enum with Cairo constants.

### I4. No validation on `drug_id`, `slot_index`, `ingredient_id`, or `target_location` ranges

**File:** `src/systems/cartel_game.cairo` (execute_buy, execute_sell, execute_mix, execute_travel)

- `drug_id` is used as `drug_id - 1` for indexing without checking `drug_id >= 1 && drug_id <= DRUG_COUNT`. Passing `drug_id = 0` causes underflow (`0 - 1` wraps).
- `slot_index` is used to index inventory slots 0-3 but `get_slot` returns `slot_3` for any index >= 3 -- no bounds check.
- `ingredient_id = 0` returns a config with effect_id = 0 and cost = 0 (free no-op mixing).
- `target_location` can be any u8 value; `get_location_config` returns zeroed config for invalid IDs.

**Fix:** Add `assert` checks for all input ranges at the start of each execution function.

### I5. Market prices never change -- static tick of 32

**File:** `src/systems/cartel_game.cairo:160-169`

All drug prices are initialized at tick 32 and never updated. There is no price movement based on supply/demand. The `drain_supply` and `replenish_supply` functions modify supply but the price tick is never adjusted.

**Fix:** Implement dynamic pricing (e.g., tick = f(current_supply, initial_supply)) or add a market event system.

### I6. Score only counts `clean_cash` but there is no laundering mechanism

**File:** `src/systems/cartel_game.cairo:306-307`

The score is set to `wallet.clean_cash`, but there is no action or mechanism in Stage 1 to convert dirty cash to clean cash. Players start with `starting_clean_cash` and can only ever have that amount as their score. All trade earnings go to `dirty_cash`.

**Fix:** Either add a launder action, change the score to include dirty_cash, or document this as a known Stage 1 limitation.

### I7. `player_name` parameter is accepted but never stored

**File:** `src/systems/cartel_game.cairo:81`

The `create_game` function accepts `player_name: felt252` but never writes it to any model.

**Fix:** Either add a name field to CartelPlayer or remove the parameter.

### I8. Leaderboard `register_score` has no replay protection

**File:** `src/systems/season_v2.cairo:49-113`

A player can call `register_score` multiple times for the same finished game, inserting duplicate entries into the leaderboard. There is no check for whether this game has already been registered.

**Fix:** Add a boolean field to CartelPlayer (e.g., `score_registered`) and check it before insertion.

### I9. `sell_price` can exceed `buy_price` with effects, creating infinite money loop

**File:** `src/systems/helpers/market_helpers.cairo:12-16`

The sell price is `buy_price * (100 + effect_multiplier) / 100`. With 4 maximum effects, the multiplier can reach up to 5+22+30+10+15+35+40+50 = up to 145 bps (picking the top 4: 50+40+35+30 = 155). This means sell price = buy_price * 255/100 = 2.55x the buy price. A player can buy, mix 4 effects (paying ingredient costs), and sell at the same location for a guaranteed profit -- without any market price movement.

**Fix:** Sell price should be discounted relative to buy price (e.g., 80% of base), with effects adding value on top of the discounted base. Or implement price impact from buy/sell.

---

## Minor Issues

### M1. ActionBar hardcodes `maxAp = 6` instead of reading from game config

**File:** `web/src/components/cartel/ActionBar.tsx:12`

The config provides `ap_per_turn` (4 for casual, 3 for ranked) but the UI shows 6.

### M2. MixingStation only shows 6 of 8 ingredients

**File:** `web/src/components/cartel/MixingStation.tsx:5-12`

`INGREDIENT_NAMES` only has entries 1-6, but config supports ingredients 1-8.

### M3. LocationMap fog-of-war logic uses `locationHeat` instead of market `visible_to`

**File:** `web/src/components/cartel/LocationMap.tsx:25-26`

The fog-of-war should be based on whether the market is visible (the `visible_to` bitmask), not whether `locationHeat` is 0.

### M4. `commit_actions` does not validate `action_hash != 0`

**File:** `src/systems/cartel_game.cairo:202-219`

A zero hash could be committed accidentally. The cleared commit also has hash 0, so a reveal with no actions and salt 0 could match.

### M5. Unused `calculate_threat` import in test files

**Files:** `src/tests/test_encounters.cairo:3`, `src/tests/test_integration.cairo:8`

Compiler warnings about unused imports.

### M6. Dead code: `ActionType::Manage` and `ActionType::Invest` are defined but do nothing

**File:** `src/systems/cartel_game.cairo:413-414`

These action types are matched but execute as no-ops. They still consume AP (1 each via `action_ap_cost`).

### M7. `revealResolve` in TypeScript sends salt and actions in wrong order

**File:** `web/src/dojo/hooks/useCartelSystems.ts:101-111`

The calldata sends salt before the actions array, but the Cairo interface expects `(game_id, actions, salt)`. The `execute("reveal_resolve", [gameId, salt, ...actions])` order does not match the function signature `fn reveal_resolve(game_id: u32, actions: Array<Action>, salt: felt252)`.

**Note:** This may be handled by Dojo's calldata serialization, but it should be verified.

### M8. No events emitted for any state changes

The contract does not emit any events (e.g., GameCreated, ActionResolved, EncounterTriggered). This makes it difficult for the frontend to reactively update via Torii subscriptions and makes debugging harder.

---

## Security Assessment

### Contract Entry Points

**`create_game`**: Low risk. Any caller can create a game for themselves. The `GameCounter` singleton could theoretically overflow u32 (4B games) but this is not practically exploitable. No funds at risk.

**`commit_actions`**: Medium risk. Validates player status and AP. However:
- No validation that `action_hash` is non-zero.
- `ap_spent` is stored but never enforced.
- Allows overwriting previous commits on the same turn (re-commit before reveal).

**`reveal_resolve`**: High risk -- this is the main attack surface:
- Hash verification is correct (Poseidon-based, salt-protected).
- **Missing:** No validation on action field ranges (drug_id, slot_index, ingredient_id can be out of bounds).
- **Missing:** No adjacency enforcement during travel execution.
- **Potential panic:** Integer overflow on wallet arithmetic with large quantities.
- All state is written atomically at the end, which is good for consistency.

**`end_game`**: Low risk. Can only transition to FINISHED if already past max turns or dead. However, a dead player calling `end_game` sets score to current clean_cash which could be 0 -- this is fine.

### Commit-Reveal Pattern

The commit-reveal scheme is correctly implemented in Cairo:
- Salt provides pre-image resistance (cannot derive actions from hash alone).
- Poseidon hash is collision-resistant.
- Turn-based commit prevents cross-turn replay.

However, for Stage 1 (single-player), the commit-reveal adds gas overhead without security benefit since there is no adversary to front-run. The randomness (encounter rolls) is derived from the player-chosen salt, meaning the player can grind salts to avoid encounters. This is acceptable for single-player but should be replaced with VRF for multiplayer.

### Front-running / Salt Grinding

Since encounter randomness uses `Poseidon(salt, action_idx, 'encounter')`, a player can pre-compute encounter outcomes for different salts and choose one that avoids encounters. This is by design for single-player but is a critical issue for any multiplayer mode.

---

## Test Coverage Analysis

### What is tested (good coverage)
- Action hash determinism, different salts, verification (3 tests)
- Action validation: AP costs, adjacency-based travel costs, batch validation (5 tests)
- Market: buy price calculation, sell price with effects, supply drain, visibility bitmask (4 tests)
- Encounters: trigger rates at different tiers, crew power, resolve win/lose, loss severity (6 tests)
- Mixing: first ingredient, multiple, max cap, no duplicates (4 tests)
- Heat: location heat packing/unpacking, notoriety-to-tier thresholds (2 tests)
- Integration: full game loop simulation through helpers (1 test)

### What is NOT tested (gaps)
- **No contract-level integration tests:** No tests spin up Dojo world and call `create_game` / `commit_actions` / `reveal_resolve`. All tests are unit tests on helper functions.
- **No test for `end_game`.**
- **No test for leaderboard `register_score`.**
- **No test for inventory pack/unpack round-trip at edge cases** (max values: drug_id=255, quantity=65535, quality=255, effects=0xFFFFFFFF).
- **No test for market price tick packing at boundaries** (max tick value, all 8 drugs packed).
- **No test for travel to invalid locations** (0, 7, 255).
- **No test for selling more than you have** (the assert is there but untested).
- **No test for buying with insufficient cash.**
- **No test for mixing with insufficient cash.**
- **No negative/adversarial tests** (e.g., wrong player revealing, replaying commits).

---

## Positive Notes

1. **Clean architecture:** Good separation between models, configs, helpers, and the main contract. Each concern has its own file.

2. **Bit-packing is well-implemented:** The drug slot packing, location heat packing, and market price/supply packing are correct and use consistent patterns. The TypeScript unpacking mirrors Cairo correctly (for inventory and market).

3. **Test quality:** The tests that exist are well-written and cover the core mathematical properties. The integration test exercises the full helper pipeline.

4. **Commit-reveal correctness:** The Poseidon-based hash scheme in Cairo is properly implemented with salt protection and turn-based scoping.

5. **Gas efficiency:** The bit-packing approach for inventory (4 slots in 4 u64s) and market data (8 drugs in u128) is gas-efficient compared to individual storage slots.

6. **Defensive coding in encounters:** The cash loss uses safe subtraction pattern (`if wallet > loss then subtract else zero`).

7. **Frontend components are well-structured:** Clean React components with proper null handling and loading states.

8. **Config-driven design:** Game modes, drug configs, location configs, and ingredient configs are all data-driven, making it easy to add new content.
