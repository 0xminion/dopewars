# Agent 3 Suggestions — Dope Wars Strategic Depth Overhaul

> **Author:** Claude Opus 4.6 (1M context)
> **Date:** 2026-03-31
> **Analysis Scope:** Full codebase audit (Cairo/Dojo/Starknet, all src/ modules), Schedule 1 wiki deep-dive (Mixing, Dealers, Customers, Properties, Employees, Products, Ranks), cross-reference with Agent 1 & Agent 2 suggestions, Codex second-opinion attempt (sandbox-blocked, analysis completed via primary agents)
> **Goal:** Identify game logic changes and new features that make the game harder to solve, more replayable, and equally engaging for AI agents and human players

---

## Executive Summary

The current Dope Wars implementation is a well-engineered on-chain game with efficient bit-packing (~320 bits per game state), clean event emission, and solid VRF randomness. But the decision space is shallow. The optimal strategy is a greedy heuristic: track tick values across 6 symmetric locations, buy the drug with the lowest tick at your current location, travel to the location with the highest tick for that drug, sell, repeat. Single-drug inventory, symmetric locations, two encounter types, and no persistent state between turns make this solvable by any agent in under 100 lines of code.

Agents 1 and 2 correctly identified multi-drug inventory, bank/interest, special events, and deterministic seeds as P0 fixes. This document builds on their work with **novel mechanics not yet proposed**, drawn from Schedule 1's deeper systems and original game design analysis. Every suggestion below is evaluated for its impact on **decision complexity** (does it create non-trivial optimization problems?) and **human engagement** (does it create stories worth telling?).

---

## Part A: Novel Game Logic Changes (Not in Agent 1/2)

### 1. Asymmetric Information & Market Fog of War

**Problem:** All market prices are fully visible to all players at all times. Agents can trivially compute global optima.

**Proposed:** Players can only see prices at their current location and locations they've visited in the last N turns. Unvisited markets show stale prices (last-seen tick) or no data.

**Implementation:**
- Add `last_visited_turn` per location to `GameStorePacked` (3 bits per location = 18 bits)
- Market read functions check `current_turn - last_visited_turn < visibility_window`
- If outside window, return stale tick or `UNKNOWN`
- Gear item "Burner Phone" reveals one remote market per turn
- Gear item "Scanner Radio" shows encounter probability at all locations

**Why this matters:**
- Destroys omniscient greedy strategies — agents must model uncertainty
- Creates an exploration vs. exploitation tradeoff (classic multi-armed bandit)
- Human players get the tension of "is it still cheap in Brooklyn?" instead of checking a spreadsheet
- Forces scouting trips and information-gathering turns, not just profit-maximizing turns

**Agent impact:** Transforms the problem from deterministic optimization to partially-observable MDP. Requires belief-state tracking, exploration policies, and Bayesian price estimation. This alone makes the game 10x harder to solve optimally.

---

### 2. Perishability & Inventory Decay

**Problem:** Drugs held in inventory retain full value indefinitely. There's zero cost to hoarding.

**Proposed:** Each drug type has a `shelf_life` in turns. After `shelf_life` turns in inventory, quantity decays by a percentage per turn. Higher-tier drugs decay faster (cocaine degrades faster than weed).

**Implementation:**
- Track `turns_held` per drug slot (4 bits, max 15 turns)
- Decay rates per drug config: Ludes (no decay), Speed (no decay), Weed (5% after 6 turns), Shrooms (10% after 4 turns), Acid (8% after 5 turns), Ketamine (10% after 4 turns), Heroin (15% after 3 turns), Cocaine (20% after 3 turns)
- Decay applied at turn end in `game_loop.cairo`
- Gear item "Cooler" (vehicle slot upgrade) halves decay rate

**Why this matters:**
- Creates urgency — holding for the perfect price has a cost
- High-value drugs become high-risk (cocaine decays fast, so you can't wait 5 turns for a price spike)
- Agents must model expected value with decay: `EV = P(sell_price) * quantity * (1 - decay)^turns_to_sell`
- Human players feel the pressure of a ticking clock on their product

**Agent impact:** Adds a temporal dimension to the trading optimization. Greedy "hold until max price" fails. Agents need dynamic programming or lookahead search.

---

### 3. Reputation Specialization Trees (Not Linear Progression)

**Problem:** Reputation is a single 0-100 meter that unlocks drug tiers linearly. No meaningful choices in progression.

**Proposed:** Replace linear reputation with 3 specialization branches. Players earn "rep points" and allocate them:

- **Trader Tree:** Unlocks higher drug tiers, better buy/sell prices (5% discount per level), market visibility range, bulk trading
- **Fighter Tree:** Unlocks combat bonuses, encounter rewards, intimidation (auto-win encounters below your level), bounty hunting
- **Operator Tree:** Unlocks production capabilities, mixing stations, dealer networks, passive income

**Implementation:**
- Replace 8-bit `reputation` with 3x 5-bit specialization scores (15 bits total, fits existing packing)
- Each turn carrying drugs earns 1 Trader rep. Each fight won earns 1 Fighter rep. Each production/mix action earns 1 Operator rep
- Drug tier unlocks based on Trader level (not flat reputation)
- Combat scaling based on Fighter level
- New actions (mixing, production) gated by Operator level

**Why this matters:**
- Creates distinct playstyles — "combat hustler" vs "trading mogul" vs "drug chef"
- Agents must choose a specialization strategy early and commit (no optimal universal build)
- Human players get identity and roleplay ("I'm building a fighter this run")
- Replayability: 3 distinct viable strategies per season settings

**Agent impact:** Introduces a meta-strategy layer. Agents must solve "which tree to invest in given this season's settings" before optimizing within that tree. Creates a rock-paper-scissors dynamic in ranked play.

---

### 4. Supply Chain Bottlenecks & Scarcity

**Problem:** Every drug is always available at every location. No supply constraints.

**Proposed:** Each location has a limited stock per drug per turn cycle. When a player buys, stock decreases. Stock replenishes over turns but not instantly.

**Implementation:**
- Add `stock_level` per drug per location (6 locations x 4 drugs = 24 slots, 4 bits each = 96 bits)
- Stock starts at a random level (8-15 units) each turn cycle
- Buying reduces stock. When stock = 0, drug unavailable at that location until next replenishment
- Replenishment rate varies by location and drug (config-driven)
- In shared-market multiplayer: other players' purchases deplete YOUR available stock

**Why this matters:**
- First-mover advantage — get to the cheap location before stock runs out
- Creates supply-side strategy: deplete a location's stock to force competitors to buy elsewhere at worse prices
- Adds a timing dimension to travel decisions
- Prevents the "everyone buys cocaine at the same location" degenerate strategy

**Agent impact:** In multiplayer, creates a game-theoretic problem (Nash equilibrium seeking). In single-player, adds a stochastic constraint that greedy algorithms handle poorly.

---

### 5. Informant & Snitch Mechanic

**Problem:** The only negative consequence of encounters is health/cash loss. No lasting strategic consequences.

**Proposed:** When paying off cops (the "Pay" encounter resolution), there's a chance (10-30% based on wanted level) that the cop becomes an informant who tracks your movements. Informants:

- Increase encounter probability at your next 2-3 destinations by 25%
- Can be "burned" by visiting a specific location (safe house) and spending cash
- Stack — multiple informants compound the encounter rate increase
- Some encounters offer "snitch" option: reduce your wanted level but increase a random opponent's (in ranked/multiplayer)

**Implementation:**
- Add `informant_count` to player state (3 bits, max 7)
- Modify encounter probability calculation in `traveling.cairo` to factor in informant count
- Add `BURN_INFORMANT` action in `decide.cairo` (costs cash, requires specific location)
- In ranked mode: snitch action emits event consumed by other players' games

**Why this matters:**
- "Pay" is no longer the safe option — it has long-term consequences
- Creates a cleanup cost that must be factored into encounter decisions
- Informant accumulation creates a death spiral if not managed (rising encounter rates → more payments → more informants)
- In multiplayer: introduces indirect PvP (sabotage via snitching)

**Agent impact:** Pay/Fight/Run decision becomes much harder. Agents must model the long-term cost of informants, not just the immediate cash loss.

---

### 6. Contract Orders & Deadline Pressure

**Problem:** Players have no external obligations. Every turn is purely opportunistic.

**Proposed:** At game start and periodically during the game, players receive "contract orders" — requests to deliver a specific drug type and quantity to a specific location within N turns.

- Completing a contract pays a premium (2-3x market rate) plus reputation bonus
- Failing a contract (timeout) incurs a cash penalty and reputation loss
- Players can hold up to 2-3 active contracts
- Contracts scale with reputation — higher rep = bigger orders, bigger rewards, tighter deadlines
- Some contracts conflict (deliver cocaine to Brooklyn AND heroin to Queens in 3 turns — pick one)

**Implementation:**
- New `Contract` model: `{drug: u8, quantity: u16, destination: u8, deadline_turn: u8, reward: u32, penalty: u32}`
- `contracts_packed` field in game state (2-3 contracts x ~40 bits each)
- Contract generation at turn start using VRF
- Contract completion checked in `game_loop.cairo` when player sells at the correct location

**Why this matters:**
- Creates goal-directed gameplay instead of pure opportunism
- Forces suboptimal-but-profitable decisions (you might need to travel to a bad-price location because the contract pays more)
- Contracts create narrative ("I have 3 turns to get cocaine to Queens or I lose 5000 cash")
- Multiple conflicting contracts create genuine dilemmas

**Agent impact:** Multi-objective optimization with deadlines and opportunity costs. Agents must balance contract fulfillment against free-market trading. This is significantly harder than single-objective cash maximization.

---

### 7. Fatigue & Action Economy

**Problem:** Players can trade AND travel every turn with no constraints beyond inventory. No cost to action.

**Proposed:** Introduce an "Energy" or "Action Points" system. Players start each turn with 3 AP. Actions cost AP:

- Travel: 1-2 AP (based on distance)
- Buy/Sell: 1 AP
- Upgrade gear: 2 AP
- Mix drugs (new): 2 AP
- Scout market (new, reveals remote prices): 1 AP
- Rest (recover health): 2 AP, skip other actions

**Implementation:**
- Add `action_points` to player state (3 bits, max 7)
- AP resets to base (3) at turn start, modified by gear (sneakers give +1 AP)
- Each action in `game_loop.cairo` checks and deducts AP
- Insufficient AP = action rejected

**Why this matters:**
- Forces prioritization — you can't do everything every turn
- Travel to distant locations costs more, making geography matter
- Creates a meaningful tradeoff between offensive actions (trade, fight) and defensive actions (heal, scout)
- Gear that grants AP becomes strategically valuable

**Agent impact:** Adds a resource allocation dimension to each turn. Agents must plan multi-turn action sequences, not just greedy single-turn decisions.

---

### 8. Weather & Environmental Events (Persistent Map State)

**Problem:** The map is static. Nothing changes about locations beyond market ticks.

**Proposed:** Each turn, a "weather" or environmental state is rolled for each location:

- **Clear:** Normal operations
- **Rain:** Travel takes +1 AP, encounter probability -20%
- **Heat Wave:** Drug decay rate doubles, prices for water-based drugs (Acid) increase
- **Police Sweep:** Encounter probability +50%, but all fines doubled
- **Block Party:** No encounters, but shops closed (can't buy/sell)
- **Blackout:** Market prices hidden (fog of war at that location)

**Implementation:**
- Add `weather` per location to game state (6 locations x 3 bits = 18 bits)
- Weather rolled each turn via VRF in `game_loop.cairo`
- Weather modifiers applied in relevant systems (trading, traveling, encounters)
- Weather visible at current location, predicted (70% accuracy) at adjacent locations

**Why this matters:**
- Makes the map dynamic and unpredictable
- Creates situational decision-making ("it's raining in Brooklyn, so I'll go to Queens instead")
- Weather + contracts + decay creates emergent complexity (your cocaine is decaying, the contract deadline is in 2 turns, but there's a police sweep at the destination)
- Human players get environmental storytelling

**Agent impact:** Adds another stochastic variable to the state space. Agents must adapt strategies to transient conditions rather than following fixed plans.

---

## Part B: Schedule 1-Inspired Features (Novel Adaptations)

### 9. Simplified On-Chain Mixing System

**Inspired by:** Schedule 1's 16 ingredients x 34 effects interaction table.

**Adaptation for on-chain:** Full Schedule 1 mixing is too complex for on-chain state. Simplified version:

- 4 "additives" purchasable at specific locations (cost: 500-2000 cash)
- Each additive + drug type produces a predictable effect:
  - Additive A + Weed = "Premium Weed" (1.5x value)
  - Additive B + Cocaine = "Pure Cocaine" (2x value, but +1 wanted at sale)
  - Additive C + Any = "Laced" variant (1.8x value, but 10% chance of inventory loss from bad batch)
  - Additive D + Any = "Extended Release" (no decay for 5 turns)
- Mixing costs 2 AP and requires Operator tree level 2+
- Mixed products cannot be mixed again (no stacking)

**Implementation:**
- Add `additive` field to drug slot (2 bits for additive type, 0 = none)
- Mixing action in `game.cairo` checks additive availability, drug type, Operator level
- Price modifier applied in `trading.cairo` sell calculation
- Side effects (wanted increase, batch loss) rolled via VRF

**Why this matters:**
- Adds a production layer without the full complexity of Schedule 1
- Creates a risk/reward decision: mix for higher value but risk a bad batch
- Different additives suit different strategies (no-decay for hoarders, pure for fighters who can handle wanted)

---

### 10. NPC Dealer Network (Passive Income Layer)

**Inspired by:** Schedule 1's 6 dealers with 20% commission and customer caps.

**Adaptation:**
- Players can hire 1-2 NPC dealers (unlocked at Operator tree level 3)
- Dealers auto-sell drugs from player's inventory at a 25% discount to market price
- Dealers sell at end-of-turn, after market tick update
- Each dealer handles one drug type and one location
- Dealer can be "busted" (30% chance per turn if wanted > 3 at dealer's location) — lose dealer + inventory
- Hiring cost: 2000 cash + 1 turn setup

**Implementation:**
- New `Dealer` model: `{drug: u8, location: u8, active: bool}` (12 bits per dealer)
- Dealer sell logic in `game_loop.cairo` turn-end phase
- Dealer bust check uses wanted level at dealer's location

**Why this matters:**
- Creates passive income that frees players from manual trading
- Dealer placement is a strategic decision (high-price location vs. low-wanted location)
- Risk of bust adds a management dimension
- Agents can run dealer networks while focusing on contracts or combat

---

### 11. Property Stash (Cross-Turn Inventory)

**Inspired by:** Schedule 1's 7 properties with storage and equipment.

**Adaptation:**
- Players can purchase a "stash" at one location (cost: 5000-20000 depending on location)
- Stash holds drugs across turns (not subject to decay while stashed)
- Stash has limited capacity (50-200 units depending on purchase tier)
- Players can deposit/withdraw when at the stash location (costs 1 AP)
- Stash can be raided if wanted level at that location exceeds 5 (lose 50% of stashed goods)
- Only one stash per game

**Implementation:**
- New `Stash` model: `{location: u8, drug: u8, quantity: u16, capacity: u16}`
- Stash actions (deposit, withdraw) in `game.cairo`
- Raid check at turn end if wanted exceeds threshold

**Why this matters:**
- Enables buy-low-store-sell-high strategies across multiple turns
- Creates a base of operations — one location becomes "home"
- Raid risk ties stash strategy to wanted level management
- Fundamentally changes the temporal dynamics of trading

---

### 12. Crew Members (Disposable Buffs)

**Inspired by:** Schedule 1's employee system (Cleaners, Botanists, Handlers, Chemists).

**Adaptation:**
- Players can hire crew members (1 at a time, max 2 per game) at specific locations
- Crew types:
  - **Lookout** (1000 cash): -30% encounter probability for 5 turns
  - **Muscle** (1500 cash): +30% attack for 5 turns, can sacrifice to auto-win one encounter
  - **Runner** (2000 cash): +1 AP per turn for 5 turns
  - **Chemist** (2500 cash): Can mix drugs without Operator tree requirement for 5 turns
- Crew members are temporary (5 turns) and cannot be renewed (different crew member required)
- Crew members consume 500 cash per turn (wages) — if you can't pay, they leave

**Implementation:**
- Add `crew_type` and `crew_turns_remaining` to player state (4 bits type + 3 bits turns = 7 bits)
- Crew effects applied as modifiers in relevant systems
- Wage deduction at turn start in `game_loop.cairo`

**Why this matters:**
- Creates burst-strategy windows — hire a Runner before a critical 5-turn trading sequence
- Wage cost creates a break-even calculation (is the buff worth 2500 upfront + 2500 in wages?)
- Disposability prevents "always hire the best crew" degenerate strategy
- Different crew types support different specialization trees

---

## Part C: Agent vs. Human Balance Considerations

### 13. Why the Current Game Favors Agents Too Much

The current game is a **fully-observable, single-objective, stationary-distribution optimization problem**. This is exactly what agents excel at:
- Full price visibility → agents compute global optima instantly
- Single drug inventory → no portfolio complexity
- Stationary market distribution → agents learn the distribution and exploit it
- No time pressure → agents plan optimally without cognitive load
- Symmetric locations → no spatial reasoning required

### 14. How These Suggestions Rebalance

| Suggestion | Makes Harder for Agents | Makes Better for Humans |
|-----------|------------------------|------------------------|
| Market Fog of War | Destroys omniscient optimization | Creates exploration excitement |
| Perishability | Requires temporal planning | Creates urgency and tension |
| Specialization Trees | Meta-strategy selection | Identity and roleplay |
| Supply Scarcity | Game-theoretic in multiplayer | First-mover thrill |
| Informant Mechanic | Long-term consequence modeling | Consequences feel meaningful |
| Contract Orders | Multi-objective optimization | Goal-directed narrative |
| Action Points | Resource allocation per turn | Meaningful turn decisions |
| Weather Events | Adaptive strategy required | Environmental storytelling |
| Mixing System | Production optimization | Crafting satisfaction |
| Dealer Network | Passive income management | Empire-building fantasy |
| Property Stash | Temporal inventory strategy | Base-building |
| Crew Members | Burst-timing optimization | Power fantasy moments |

### 15. The Key Insight: Partial Observability + Multi-Objective + Non-Stationarity

The single most impactful change for agent-human balance is **removing full observability** (suggestion #1). When agents can't see all prices, they must explore — and exploration under uncertainty is where human intuition often beats algorithmic optimization. Pair this with **multiple competing objectives** (contracts + cash maximization + wanted management + crew wages) and **non-stationary environments** (weather, events, supply depletion), and you get a game where:

- Agents need sophisticated multi-objective RL with belief-state tracking (hard to train, expensive to run)
- Humans can use intuition, pattern recognition, and risk tolerance (natural strengths)
- Neither player type has a dominant strategy — the game rewards adaptation over optimization

---

## Part D: What's Different from Agent 1 & Agent 2

| This Document | Agent 1 | Agent 2 | Novel? |
|--------------|---------|---------|--------|
| Market Fog of War | Not proposed | Not proposed | Yes — fundamentally changes information structure |
| Perishability/Decay | Briefly mentioned quality decay | Quality degradation mentioned | Expanded with per-drug rates and gear mitigation |
| Specialization Trees | Not proposed (linear rep) | Rank tiers mentioned | Yes — branching progression vs. linear |
| Supply Scarcity | Not proposed | Supply/demand mentioned abstractly | Yes — concrete stock depletion mechanic |
| Informant Mechanic | Not proposed | Not proposed | Yes — persistent consequence of encounter decisions |
| Contract Orders | Not proposed | Not proposed | Yes — external objectives with deadlines |
| Action Points | Not proposed | Not proposed | Yes — per-turn resource allocation |
| Weather Events | Special events proposed | Random events proposed | Different — persistent map-state modifiers vs. one-off events |
| Simplified Mixing | Full quality system | Full mixing system | Different — on-chain feasible 4-additive system vs. 16-ingredient |
| Dealer Network | Dealer automation proposed | Not detailed | Similar but with bust risk and location strategy |
| Property Stash | Not proposed | Not proposed | Yes — cross-turn inventory storage |
| Crew Members | Not proposed | Consumable effects mentioned | Yes — temporary hired NPCs with wages |

---

## Part E: Implementation Priority

### Tier 1 — Maximum Impact, Minimum State Changes

These require the least additional bit-packing and create the most strategic depth:

| Feature | New Bits Needed | Impact on Decision Complexity |
|---------|----------------|-------------------------------|
| Market Fog of War | ~18 bits (last_visited per location) | 10x — transforms to POMDP |
| Action Points | ~3 bits | 5x — resource allocation per turn |
| Contract Orders | ~120 bits (3 contracts) | 5x — multi-objective optimization |
| Perishability | ~16 bits (turns_held per drug) | 3x — temporal planning |

### Tier 2 — High Impact, Moderate Complexity

| Feature | New Bits Needed | Impact |
|---------|----------------|--------|
| Specialization Trees | ~15 bits (replaces reputation) | 3x — meta-strategy |
| Informant Mechanic | ~3 bits | 2x — long-term consequences |
| Weather Events | ~18 bits | 2x — adaptive strategy |
| Crew Members | ~7 bits | 2x — burst timing |

### Tier 3 — Deep Features, Higher Implementation Cost

| Feature | New Bits Needed | Impact |
|---------|----------------|--------|
| Supply Scarcity | ~96 bits | 3x in multiplayer |
| Simplified Mixing | ~8 bits per drug slot | 2x — production layer |
| Dealer Network | ~24 bits | 2x — passive income |
| Property Stash | ~40 bits | 2x — temporal trading |

### Total Additional State

Tier 1 alone: ~157 bits. Current packed state is ~320 bits. Total would be ~477 bits — still fits in 2 felt252 values (504 bits). This is feasible without restructuring the storage model.

---

## Part F: Comparison Table

| Feature | Classic Dope Wars | Current Implementation | Schedule 1 | This Proposal |
|---------|-------------------|----------------------|------------|---------------|
| Market visibility | Full | Full | Full (local area) | Fog of War (visited only) |
| Drug decay | No | No | No (but quality matters) | Yes, per-drug rates |
| Progression | Linear | Linear reputation | 11 ranks x 5 tiers | 3 specialization trees |
| Supply limits | No | No | Supplier stock limits | Per-location stock depletion |
| NPC consequences | No | Wanted level only | Police heat + informants | Informant accumulation |
| External objectives | No | No | Customer orders | Contract orders with deadlines |
| Action economy | 1 action/turn | 1 action + travel | Real-time | 3 AP per turn |
| Map dynamics | Static | Static | Day/night cycle | Weather system |
| Production | No | No | Full chains | 4-additive mixing |
| Automation | No | No | Dealers + employees | Dealer network + crew |
| Storage | Inventory only | Single drug slot | Properties + storage | Stash at one location |
| Temporary buffs | No | No | Consumables | Crew members (5-turn) |

---

## Conclusion

The current game is a solved problem for agents and a repetitive one for humans. The root cause isn't missing features — it's missing **uncertainty, competing objectives, and temporal pressure**. Schedule 1 solves this with complexity (34 effects, 16 ingredients, 70+ customers). An on-chain game can't match that state size, but it can match that **decision depth** through information asymmetry (fog of war), resource scarcity (AP, supply limits), temporal dynamics (decay, contracts, weather), and specialization (trees, crew, stash).

The single highest-impact change: **Market Fog of War**. It transforms every downstream decision. Implement that first, then layer contracts and action points. The game becomes a fundamentally different optimization problem — one where human intuition and agent computation are genuinely complementary rather than one dominating the other.

---

*Generated by Claude Opus 4.6 (1M context) — multi-agent analysis with codebase explorer, Schedule 1 wiki researcher, and cross-reference with Agent 1 & Agent 2 suggestions. Codex second-opinion attempted but sandbox-restricted; analysis completed via primary agents.*
