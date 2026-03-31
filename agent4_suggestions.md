# Agent² Suggestions: Making Dopewars More Complex for Agent + Human Play

**Author:** nanobot (AI agent analysis)
**Date:** 2026-03-31
**Sources:** `0xminion/dopewars` codebase (Starknet/Dojo Cairo), Schedule I wiki (TVGS), senior codex review

---

## Executive Summary

Dopewars is a well-architected on-chain game — the Uniswap V2 market model, packed state management, encounter resolution, and season/achievement systems are all production-quality. However, the game has a **strategic ceiling problem**: the only meaningful decision is *which drug, where, when*. Everything else is noise around that single axis.

This document maps the gap, incorporates four-agent analysis (codex review, game-design-analyst, codex-analyzer, second-opinion-critique), and proposes additions ordered by **actual impact vs. implementation cost**. Three recommendations from earlier drafts have been cut or revised based on code-grounded critique.

---

## Part I: Architecture & What Dopewars Has

### Stack
- **Starknet** (Cairo 2.12.2) + **Dojo Engine** v1.7.1 ECS
- **State:** Packed bit-field storage (`felt252` across `GameStore`)
- **Randomness:** On-chain VRF via Cartridge VRF
- **Market model:** Uniswap V2 constant product AMM (x·y=k), tick-based pricing (0–63)
- **Frontend:** Next.js/React via GraphQL

### Game Systems Present
| System | Files | Status |
|--------|-------|--------|
| Drug trading (8 types, tick-based) | `trading.cairo`, `markets_packed.cairo` | Core loop ✅ |
| Tier progression via reputation | `drugs.cairo`, `player.cairo` | Unlocked by rep ✅ |
| 6 locations | `locations.cairo` | Static map ✅ |
| Equipment (4 slots) | `shopping.cairo` | Weapon/Clothes/Feet/Transport ✅ |
| Encounters (Cops/Gangs) | `encounters.cairo`, `traveling.cairo` | Run/Pay/Fight ✅ |
| Wanted level | `wanted_packed.cairo` | Per-location risk ✅ |
| Season/Leaderboard | `season.cairo`, `laundromat.cairo` | High score ✅ |
| Achievements | `achievements_v1.cairo` | 26 types ✅ |
| Events emission | `events.cairo` | Full emit ✅ |
| Hidden inventory — **planned but unimplemented** | README | ❌ TODO |
| PVP mugging — **planned but unimplemented** | README | ❌ TODO |

---

## Part II: Critical Gaps Identified by Four-Agent Analysis

### Gap Group A — Fundamental Mechanical Exploits

**G1. Volume-insensitive markets.** The `market_variations()` function in `markets_packed.cairo:74-135` is the *only* source of price movement. It is pure tick arithmetic with a seeded `Random` — it has **zero awareness of trade volume**. The `TradeDrug` event fires on every buy/sell but the market model never consumes it. Buying 1 unit and buying 500 units at tick 30 costs the same. On a real Uniswap V2 AMM, the second trade would have catastrophic price impact. This makes the "AMM model" decorative, not mechanical.

**G2. Encounter penalties are inventory-blind.** In `traveling.cairo:234-286` (`on_pay`), penalties scale on *quantity* not *value*. A bust losing 5 units of Ludes ($120) is identical to losing 5 units of Heroin ($80,000). The inventory model has no `value` field per slot. The optimal strategy is trivially: always carry maximum affordable quantity of the highest-tier drug. No tension between "play it safe" and "gamble."

### Gap Group B — Missing from Schedule I Comparison

**G3. No crafting or mixing** — Schedule I has a full mixing system with 35 named effects, ingredient chains, and product tiers. Dopewars has zero crafting.

**G4. No NPCs** — Cops and Gangs are procedural. Schedule I has 7+ named suppliers, 8 dealers, and 72 customers with individual preferences.

**G5. Single-drug inventory** — One drug at a time. Cannot hold multiple types simultaneously.

**G6. No player-to-player interaction** — Ranked mode is simultaneous competition via shared market state only. No direct PvP, no P2P trading.

**G7. No property/territory system.**

**G8. No fog of war / hidden state** — All market prices and player balances fully transparent. README explicitly plans hidden inventories; not yet implemented.

### Gap Group C — Existing Infrastructure Not Used

**G9. `HighVolatility` event exists but no consumer.** In `markets_packed.cairo:114-126`, when `variation == 12` (most extreme price move), the contract emits `HighVolatility { game_id, player_id, location_id, drug_id, increase }`. This is already production code — it's a real-time supply shock signal. No interface, agent tool, or event consumer currently acts on it. This is a free signal being wasted.

---

## Part III: Recommended Additions

Ordered by impact and feasibility.

---

### 🔴 Most Impactful — The Single Change That Fixes Everything

#### R0. **Stash / Split Inventory System** *(codex review, highest priority)*

**What it is:** Add a 2-slot inventory model:

```
inventory = [ carried_drugs,     stash_drugs ]
                        ↕ MOVE (costs a turn)
```

- Stashed drugs are stored at a fixed location (Home, or purchasable caches)
- Stashed drugs are **invisible to encounters** — you cannot be robbed of what you're not carrying
- Accessing stash requires being at that location
- Stash access takes the place of a travel action

**Why this is the highest-impact change:**
It creates the core tension the game currently lacks. Without it, there's no meaningful decision between safety and mobility — you carry everything or nothing. With it, every turn becomes a tradeoff:

- *Agent view:* "If I stash 80% of my Cocaine, expected encounter cost drops from $X to $Y, but I lose Z turns of arbitrage opportunity accessing it."
- *Human view:* "Do I leave the stash in Queens and hope the Benzies don't hit it, or drag it all to Jersey and risk the trip?"

This is the mechanic Schedule I gets right. It's the mechanic that makes RTS games interesting. It's the one change that makes both AI agents and humans genuinely think about their next move.

**Implementation is minimal:** Add `stash_drugs: DrugsPacked` and `stash_location: Locations` to `player.cairo`, two new system calls (`stash_drugs`, `retrieve_stash`), gate stash access to the stash location. ~2 new `felt252` fields. The game loop and trading system don't need structural changes.

**Files:** `player.cairo`, new system in `game.cairo` or standalone `stash.cairo`.

---

### 🟢 Foundation — Quick Wins

#### F1. **Volume-Aware Market Pricing**

Fix the volume exploit in `market_variations()`. Add a volume sensitivity factor:

```cairo
// Inside market_variations() or TradeDrug handler
effective_tick += trade_volume * volume_sensitivity_factor(drug_tier);
```

- Higher-tier drugs (Cocaine, Heroin) have higher volume sensitivity
- Large trades move your own tick up — the market punishes you for being greedy
- Small frequent trades avoid price impact but incur more travel/encounter risk
- Creates meaningful decisions about *how much* to move, not just *what* to move

**Files:** `markets_packed.cairo` — add volume tracking to `TradeDrug` handler, apply in `market_variations()`.

#### F2. **Value-Scaled Encounter Penalties**

Modify penalty calculation in `traveling.cairo` (`on_pay`, `encounter_race_win`) to factor in drug value:

```cairo
// Instead of: quantity * demand_pct
// Use: quantity * demand_pct * value_multiplier
let value_multiplier = drug_config.step * current_tick / base_price;
```

- Getting busted with $80K of Heroin is more devastating than $400 of Weed
- High-reward routes are now genuinely riskier
- Creates real strategic tension between "play it safe" and "go big"

**File:** `traveling.cairo` — modify `on_pay` and `encounter_race_win` penalty calculations.

#### F3. **Consume the `HighVolatility` Event**

The signal already exists in production code. The addition is a consumer, not a new system:

- Add a CLI flag `--watch-high-volatility` that subscribes to `HighVolatility` events
- When detected, surface it as a ranked arbitrage opportunity: "Queens Weed spiked +50% — go there"
- Agents can react in real time; humans get a "news feed" of market moves

**Files:** New `agent-cli/` subscriber or WebSocket listener. Minimal effort.

#### F4. **Named Encounter Characters**

Replace generic `Cops` / `Gang` enums with named NPCs (e.g., "Officer Reyes", "The Benzies Crew", "Vice Detective Kim"). Add personality fields:

- `aggression_modifier`: how likely to fight vs. take bribes
- `preferred_demand`: cash vs. drugs vs. respect
- `intel_value`: knowing their name gives a hint about what they want
- `rarity_weight`: common cops vs. rare special encounters

**File:** `encounters.cairo` — extend `EncounterConfig` struct.

#### F5. **Location-Specific Drug Preferences**

Not all locations are equal markets. Add a persistent demand bias matrix:

| Location | Prefers | Price Floor Modifier |
|----------|---------|---------------------|
| Queens | Weed | +10% |
| Bronx | Cocaine | +12% |
| Brooklyn | Shrooms | +8% |
| Jersey | Bulk (any) | -5% floor, +20% ceiling |
| Coney | Acid | +15% |

Players who learn preferences develop better routes. Agents can build preference maps across seasons.

**File:** `markets_packed.cairo` — add location-drug affinity weights to `MarketConfig`.

---

### 🟡 Core — Meaningful Depth

#### C1. **Crafting / Mixing System**

Allow players to combine ingredients + base drugs into enhanced products with higher prices.

**Data model:**
```cairo
struct CraftedProduct {
    base_drug: Drugs,
    ingredient_id: u16,      // e.g., Chili, Soda, Paracetamol
    effect_tag: EffectTag,   // e.g., "extended_release", "higher_purity"
    market_multiplier: u16,  // 120 = +20% price
}
```

**Effect system (from Schedule I):** 35 named effects ranging x1.00–x1.60 multiplier. Key categories:
- *Ability:* Sneaky (50% slower police detection), Athletic (+30% speed), Anti-Gravity (jump higher)
- *Cosmetic:* Zombifying (x1.58), Cyclopean (x1.56), Jennerising (gender swap, x1.42)
- *Dangerous:* Explosive (player explodes), Lethal (kills NPCs), Seizure-Inducing

Some effects are **mutually exclusive** (Athletic vs. Sedating), creating recipe tradeoffs.

**Ingredient sourcing:** From encounter loot drops (F6 in original draft), specialty shops, or NPC suppliers.

**Recipe discovery:** Community-built external calculators (Schedule I has `schedule-1-calculator.com`) extend engagement and create a knowledge economy.

**Files:** New `crafting.cairo`, `effects.cairo`; extend `player.cairo` with `ingredients`.

#### C2. **NPC Supplier System**

Named suppliers who sell ingredients and rare drugs at relationship-dependent rates:

| Supplier | Sells | Region | Relationship Mechanic |
|----------|-------|--------|----------------------|
| Mrs. Ming | Bulk Weed, cheap | Queens | Buy from her consistently → better prices |
| Shirley Watts | Meth precursors | Westville (Docks) | Unlock via reputation chain |
| Salvador Moreno | Coca seeds | Docks | Requires Benzies introduction |

Each NPC has a relationship score (0–100). Higher reputation = better prices + earlier access to high-tier items. Some suppliers only unlock after reaching max rep with connected NPCs — a relationship chain.

**Agent relevance:** Agents can model NPC relationship ROI. A $500 investment in the right supplier might save $2000 over 20 turns.

**Files:** New `npcs.cairo`, `relationships.cairo`.

#### C3. **Ingredient Drops from Encounters**

When you win a fight, add a chance to loot ingredients (not drugs). Ingredients enable the crafting system.

```cairo
// traveling.cairo — on fight win
let has_loot = randomizer.occurs(game_store.game_config().loot_drop_chance);
if has_loot {
    // Add ingredient to ingredient inventory
}
```

Ingredient types: Chili, Soda, Paracetamol, Viagra, Red Phosphorus, Gasoline (Schedule I reference).

**File:** `traveling.cairo` — add to `encounter_race_win` victory rewards.

#### C4. **Fog of War: Hidden Stash + Private Prices**

Implement the README's planned hidden inventory system:

- Stash location is **invisible** to other players until game end
- `HighVolatility` events are player-specific signals (not public until resolved)
- Optional: prices at non-adjacent locations show *direction* (↑↓) but not magnitude

Implementation note: Cairo/Dojo state is public by default. Hiding requires either:
- (A) Commitment scheme: commit hash of stash at turn start, reveal at game end
- (B) Off-chain state via a game-state API that filters sensitive fields

Option B is faster to implement and is what most agent interfaces will want anyway.

**Files:** `player.cairo` (add `stash_drugs`, `stash_location`), new `fog.cairo` for commitment logic.

#### C5. **Property / Safehouse Ownership**

Purchase properties at locations that provide persistent bonuses:

| Property | Cost | Bonus |
|----------|------|-------|
| Stash House | $25K | +3 drug slots (stash capacity) |
| Safe House | $50K | -20% encounter chance when at location |
| Clinic | $75K | Heal 1 HP/turn when there |
| Distribution Hub | $100K | +5% sell price at owned location |

Properties purchased at Pawnshop or via NPC. One purchase per season.

**Agent relevance:** ROI modeling — is the property cost justified by the bonus over the season length?

**Files:** New `properties.cairo`; extend `player.cairo` with `property_id`.

---

### 🔴 Aspirational — Game-Changing (but Hard)

#### A1. **Courier Missions** *(revision of original dealer network)*

**Original proposal (cut):** Autonomous dealer network — hire NPCs who sell autonomously.

**Why it was wrong:** In a ranked competitive mode, passive income via autonomous NPCs creates a dominant optimal strategy that removes player decisions. Any non-trivial dealer AI requires significant on-chain state.

**Revised proposal:** One-time courier missions. Spend cash to hire a courier who:
- Delivers a specified drug quantity to a target location
- Takes encounter risk off your hands for that specific run
- Succeeds with configurable probability (better couriers = higher cost)
- Fails and you lose the cargo

You still decide *what* and *where*, just not *when to be present yourself*. Player agency preserved; meaningful strategic option added.

**File:** New `courier.cairo`.

#### A2. **ZK Hunt Integration — Honest PVP Mugging**

From the README: *"Mugging is currently PVE. Eventually, it would be cool to do it PVP — the mugger should not know the loadout of their target until the mugging is performed."*

This is the most architecturally interesting TODO. Using ZK proofs to hide opponent state until encounter resolution enables honest PvP without trusted intermediaries.

**Reference:** `https://github.com/FlynnSC/zk-hunt`

#### A3. **Co-Op Mode**

Allow 2–4 players to form a crew:
- Shared stash
- Distributed roles: trader, lookout (reduces encounter chance), courier
- Crew-vs-crew PvP: raid enemy crew stashes
- Shared wanted level

Agent-human crew: human handles NPC relationships; agent handles market analysis.

#### A4. **Seasonal Narrative Arcs**

Extend seasons beyond leaderboard resets:
- Thematic events: "Summer Heatwave" (heat-sensitive drugs surge), "Cartel Crackdown" (encounter risk doubles)
- Special items only available that season
- NPCs that appear for limited seasons

---

## Part IV: What Makes This Game Compelling for Both AI Agent AND Human Simultaneously

The answer: **the shared transport constraint.**

Both agent and human face the same core problem — limited carrying capacity forces a tradeoff between safety and mobility. The agent reasons about it as a resource allocation problem (knapsack with stochastic encounter cost, value-scaled penalties, stash strategy). The human reasons about it as "how much can I carry and how stupid am I feeling right now?"

Both converge on the same fundamental question: *what do I bring, where do I go, and how much am I willing to lose?*

The transport constraint is already in the game. The missing piece is a **second place to put things** — the stash system (R0). Everything else (crafting, NPCs, properties, events) layers on top of that foundation.

---

## Part V: What Was Cut and Why

| Original Proposal | Reason Cut / Revision |
|---|---|
| **Autonomous dealer network** | Wrong-headed in ranked mode. Passive optimal strategy dominates. Revised to courier missions. |
| **Market cornering** (buy >80% supply → set prices) | Broken on tick-based model — no real "supply" concept. Buying more just moves your own tick. |
| **Autopilot full-agent control** | Economically infeasible. Starknet gas costs would dwarf the $2K bankroll. Agent should advise, not control. |
| **Cooldown/ability system** | Good idea, but scope creep. Courier missions (C-A1) cover the same agency need more cleanly. |

---

## Part VI: Revised Implementation Priority

| # | Feature | Impact | Effort | Blocks |
|---|---------|--------|--------|--------|
| **R0** | Stash / split inventory | **Very High** | **Low** | Everything below |
| F1 | Volume-aware market pricing | High | Low | — |
| F2 | Value-scaled encounter penalties | High | Low | — |
| F3 | Consume HighVolatility event | Medium | Very Low | Agent CLI |
| F4 | Named encounter characters | Medium | Medium | — |
| F5 | Location drug preferences | Medium | Low | — |
| C1 | Crafting / mixing system | High | High | Ingredient drops (C3) |
| C2 | NPC suppliers | Medium | Medium | — |
| C3 | Ingredient drops | Medium | Low | Crafting (C1) |
| C4 | Fog of war (hidden stash) | Medium | Medium | Co-op (A3) |
| C5 | Property ownership | Medium | Medium | — |
| A1 | Courier missions | Medium | Medium | — |
| A2 | ZK PVP mugging | Very High | Very High | — |
| A3 | Co-op mode | Very High | Very High | — |
| A4 | Seasonal narrative | Low | High | — |

---

## References

- **Dopewars repo:** `https://github.com/0xminion/dopewars`
- **Schedule I wiki:** `https://schedule-1.fandom.com/wiki/Schedule_1_Wiki`
- **Schedule I mixing:** `https://schedule-1.fandom.com/wiki/Mixing`
- **Schedule I effects:** `https://schedule-1.fandom.com/wiki/Effects`
- **ZK Hunt (PVP reference):** `https://github.com/FlynnSC/zk-hunt`
- **Core game loop:** `src/systems/helpers/game_loop.cairo`
- **Trading system:** `src/systems/helpers/trading.cairo`
- **Market model:** `src/packing/markets_packed.cairo`
- **Encounter resolution:** `src/systems/helpers/traveling.cairo`
- **Drug config:** `src/config/drugs.cairo`

---

*Generated by nanobot — AI agent analysis with four-agent synthesis, 2026-03-31*
