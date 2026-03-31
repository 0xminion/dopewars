# Stage 2 Code Review — Codex (gpt-5.4-mini)

**Date:** 2026-03-31
**Branch:** `feat/cartel-game-stage2`
**Model:** gpt-5.4-mini via OpenAI Codex CLI
**Mode:** Adversarial review with diff embedded in prompt

---

## Findings

### 1. `fire_slot` counter underflow — slot limit bypass
**File:** `src/systems/slot_system.cairo` — `fire_slot`

`fire_slot` can be called repeatedly on the same already-inactive/busted slot because it never checks `slot.status == 1` before decrementing `counter.active_count`. That lets one owner burn the counter down to 0 and then hire more than `max_slots`.

**Severity:** Critical

### 2. `restock_slot` creates items from nothing — infinite money exploit
**File:** `src/systems/slot_system.cairo` — `restock_slot`

`restock_slot` mints product out of thin air. It never deducts inventory or cash from the player, never checks `can_access_drug`, and accepts arbitrary `drug_id` values. `drug_id = 0` is especially bad because later passive processing does `slot.drug_id - 1` and can revert the tick.

**Severity:** Critical

### 3. `process_tick` is permissionless — replay attack
**File:** `src/systems/passive_tick.cairo` — `process_tick`

`process_tick` is permissionless and has no "already processed this turn" guard. Any caller can replay the full passive economy repeatedly and rerun sales, laundering, bust checks, and market drift.

**Severity:** Critical

### 4. Wallet not persisted in inline tick path — laundered cash disappears
**File:** `src/systems/cartel_game.cairo` — `PassiveTickImpl::execute_invest` and `run_passive_tick`

`PassiveTickImpl::execute_invest` deducts `wallet.dirty_cash` only in memory and never persists it with `world.write_model(@wallet)`. In the same module, `PassiveTickImpl::run_passive_tick` also updates `wallet.clean_cash` without writing the wallet back. Net effect: investing is free in that path, and laundered cash disappears in the inline tick path.

**Severity:** Critical

### 5. `earnings_held` overflow — bricks passive tick
**File:** `src/systems/cartel_game.cairo` — `PassiveTickImpl::run_passive_tick`

`run_passive_tick` adds `owner_cut` into `slot.earnings_held` with plain `u32` addition and no saturation/cap. A high-volume slot can eventually overflow `earnings_held` and revert passive processing.

**Severity:** Critical

### 6. `start_laundering` accepts amount=0 — bricks operation
**File:** `src/systems/operation_system.cairo` — `start_laundering`

`start_laundering` accepts `amount = 0`. That creates a batch with `processing_amount = 0` and nonzero `turns_left`, which bricks the operation while still awarding operator XP. The same zero-amount hole exists in `cartel_game.cairo::PassiveTickImpl::execute_invest`.

**Severity:** Important

### 7. `apply_price_drift` / `apply_market_event` bounds assumptions
**File:** `src/systems/helpers/market_drift.cairo`

Hardcode assumptions that are not bounded by the imported `DRUG_COUNT`, and do unchecked `u16` arithmetic before clamping. A future config change or corrupted state can make market processing panic.

**Severity:** Minor

---

## Cross-Model Analysis (Claude vs Codex)

| Finding | Claude | Codex |
|---------|--------|-------|
| `restock_slot` free item duplication | C1 ✓ | #2 ✓ |
| `earnings_held` u32 overflow | C3 ✓ | #5 ✓ |
| `process_tick` permissionless/replayable | I1 ✓ | #3 ✓ |
| `fire_slot` counter underflow → limit bypass | — | #1 (Codex only) |
| Wallet not persisted in inline tick | — | #4 (Codex only) |
| `start_laundering` amount=0 bricks op | — | #6 (Codex only) |
| Shared counters across players | C2 ✓ | — (Claude only) |
| Dead execute_manage/invest stubs | C4 ✓ | — (Claude only) |

**Agreement rate:** 3/10 unique findings overlap (30%)
**Codex-unique findings:** 3 (fire_slot underflow, wallet persistence, zero-amount laundering)
**Claude-unique findings:** 4 (shared counters, dead stubs, max_dealer_slots not enforced, reputation unlocks not enforced in buy)
