# Agent 1 Suggestions — Dope Wars On-Chain Enhancement

> **Author:** Hermes Agent (Nous Research)  
> **Date:** 2026-03-31  
> **Analysis Scope:** Full codebase audit (~100+ files, Cairo/Dojo, Next.js), Schedule 1 wiki mechanics comparison (16 pages scraped, 300+ indexed), Codex second-opinion technical review  
> **Goal:** Make the game more complex, strategic, and playable by both AI agents and humans

---

## Executive Summary

The Dope Wars on-chain implementation on Starknet/Dojo is technically solid — efficient bit-packing, clean event system, functional core loop. But it is missing **~40-50% of the strategic depth** from classic Dope Wars and **0% of the modern mechanics** (production chains, customer networks, automation) that Schedule 1 has pioneered. The current optimal strategy is trivially solvable, which bores both human and AI players.

Three subagents performed parallel analysis:
1. **Hermes subagent #1** — Full codebase audit of 20+ core source files
2. **Hermes subagent #2** — Comprehensive Schedule 1 wiki research (16 pages)
3. **Codex subagent** — Second-opinion technical review focused on gaps and improvements

---

## Part A: Game Logic Changes for Complexity

### 1. Multi-Drug Inventory System
**Current:** Players carry exactly one drug type at a time. `assert(drugs.quantity == 0 || drugs.drug == trade.drug, 'one kind of drug')` in `trading.cairo`.
**Proposed:** Replace with multi-slot inventory (start with 3-4, expandable via trench coat upgrades). Each slot tracks `(drug_type, quantity)`.
**Impact:** Transforms trading from single-commodity speculation to portfolio management. Creates real arbitrage decisions — buy cheap weed AND cocaine simultaneously, sell each at optimal locations.
**Agent Playability:** Creates a combinatorial optimization surface instead of a trivial "buy cheapest, sell highest" script.

### 2. Bank with Interest
**Current:** No bank. Cash is carried or lost.
**Proposed:** `BankAccount` model with `deposit()`, `withdraw()`, and per-turn interest (configurable 2-10%). Interest compounds at end of game loop.
**Impact:** Forces the classic Dope Wars risk decision — carry cash to trade (vulnerable to muggers) vs. bank it (safe but can't buy product). Agent must model expected value of each decision.
**Agent Playability:** Creates a natural decision node for RL training — risk assessment is a well-studied problem domain.

### 3. Starting Debt / Loan Shark
**Current:** Players start with zero obligations.
**Proposed:** Start each game with a loan (e.g., 5,000 Paper) that compounds at a high rate (e.g., 5-10% per turn). Players can take additional loans mid-game at worse rates.
**Impact:** Creates urgency from turn 1. Players cannot simply hoard; they must trade immediately. Default risk adds lose condition beyond encounter death.
**Agent Playability:** Debt management is a classic constrained optimization problem.

### 4. Special Events System
**Current:** Markets drift randomly via tick-based distribution. No named events.
**Proposed:** Add 6-8 named events that trigger on market roll:
- `OfficerDied` — Cocaine crashes to minimum price
- `AddictsSpike` — Heroin price spikes 5-10x
- `MuggersAmbush` — Forced encounter, lose % of cash
- `FoundStash` — Free drugs added to inventory
- `MarketCrash` — All drugs drop 50% for 2-3 turns
- `MarketBoom` — All drugs rise 50% for 2-3 turns
- `PoliceRaid` — Increased encounter probability for destination
- `SupplierShortage` — One drug type unavailable at all shops
**Impact:** Breaks the predictable loop. Creates memorable moments and forces strategy pivots mid-run.
**Agent Playability:** Events create non-stationary market conditions, forcing agents to adapt rather than follow a fixed policy.

### 5. Location-Specific Modifiers
**Current:** All 6 locations (Queens, Bronx, Brooklyn, Jersey, Central Park, Coney Island) have identical mechanics — only random tick states differ.
**Proposed:** Each location gets 2-3 persistent modifiers:
- Central Park: +50% encounter rate, +30% price on premium drugs
- Bronx: Gang encounters scale faster, but shop prices 15% lower
- Jersey: Safer travel (-40% encounter rate), but market ticks drift slower
- Brooklyn: Bonus drug tier unlocked one reputation level earlier
- Queens: Bank interest rate +2% (financial district)
- Coney Island: Casino access, special item vendors
**Impact:** Travel decisions become genuinely strategic, not just "check ticks and go."
**Agent Playability:** Creates a spatial optimization problem — agents must weigh risk vs. reward vs. distance vs. modifiers.

### 6. Encounter Escalation & Police Heat System
**Current:** Encounters are Cops/Gangs with linear scaling based on reputation. Three outcome options (Fight/Run/Pay).
**Proposed:** Inspired by Schedule 1's escalating police system:
- Track "Heat Level" (0-3) that accumulates from encounters, wanted level, and large transactions
- Level 0: No encounters
- Level 1: Under Surveillance — occasional cop checks
- Level 2: Wanted — frequent encounters, roadblocks
- Level 3: Dead or Alive — guaranteed encounters, lethal force, asset freeze
- Players can reduce heat by laying low (skip turns), paying bribes, or using specific locations
- Gang encounters can escalate to turf wars (multi-turn events)
**Impact:** Adds a persistent risk meter that players must actively manage, not just react to.
**Agent Playability:** Heat creates a state variable that agents must model and control proactively.

### 7. Combat Depth — Gear Synergies & Set Bonuses
**Current:** Gear stats are purely additive. No synergies between items.
**Proposed:** Add set bonuses — equipping 2+ items from the same tier/set grants bonuses:
- "Tactical Set" (weapon + clothes): +10% defense reduction
- "Speed Set" (transport + feet): +15% speed, escape chance bonus
- "Heavy Set" (weapon + transport): +20% attack, but -10% speed
- Introduce "builds" — agents can optimize for combat, evasion, or trade specialization
**Impact:** Makes the shop system strategically interesting, not just "buy the highest stat item available."
**Agent Playability:** Introduces combinatorial optimization across gear slots — classic multi-objective optimization.

### 8. Drug Quality & Mixing System (Inspired by Schedule 1)
**Current:** Drugs are binary — you have a type and a quantity. Quality is not a factor.
**Proposed:** Introduce drug quality tiers matching Schedule 1's model:
- Each drug has 3 quality tiers: Standard / Premium / Heavenly
- Higher quality drugs sell for 2-5x more but require better gear/locations to produce/acquire
- Add a simplified "mixing" mechanic — combine raw drug with 1-2 "boosters" (purchased at special vendors) to upgrade quality
- Quality decays slightly per turn (storage costs)
**Impact:** Adds a production/upgrade layer to the simple buy-sell model.
**Agent Playability:** Introduces a timing optimization — when to hold, when to upgrade, when to sell.

---

## Part B: Additional Features from Schedule 1 Wiki

### 9. Customer Network System
**Inspired by:** Schedule 1's 70+ named customers with unique budgets, schedules, and preferences.  
**Current:** No customers. All trade is at shops with dynamic pricing.
**Proposed:** Add named NPC customers:
- Each customer has: preferred drug, budget, order frequency, price sensitivity, police call probability
- Unlock customers by reputation or location visits
- Customer relationships improve with consistent supply — better prices, more frequent orders
- Bad products (low quality) or late deliveries reduce relationship
- Some customers are informants — high police risk but high payout
**Impact:** Creates a relationship management layer. Different players specialize in different customer bases.
**Agent Playability:** Customer portfolio management is a well-understood optimization domain.

### 10. Dealer Network / Automation Layer
**Inspired by:** Schedule 1's dealer system that automates sales.  
**Current:** Players must manually execute every trade action.
**Proposed:** Introduce NPC dealers who buy inventory at a discount:
- Players can "contract" with dealers at a percentage cut (15-25%)
- Dealers automatically buy from stock at turn end
- Multiple dealers compete — players can switch contracts
- Contract violations (not delivering) damage reputation
**Impact:** Frees agent players from repetitive trades while creating a new strategic decision: direct trade vs. dealer commission.
**Agent Playability:** Critical — agents should not burn 30 turns on manual click-trading when the strategy is already determined.

### 11. Money Laundering & Asset System
**Inspired by:** Schedule 1's laundering businesses and deposit limits.  
**Current:** The laundromat system exists in code but is minimally integrated.
**Proposed:** Expand laundromat into a full laundering system:
- Cash earned from encounters/trades is "dirty" — counts as score but cannot be banked
- Launder through businesses: Laundromat, Car Wash, Post Office, Front (each with capacity and cost)
- Bank only accepts "clean" money
- Dirty-to-clean ratio affects heat level
- Businesses generate passive income (reinvestment incentive)
**Impact:** Adds an endgame investment layer — players transition from hustler to businessman.
**Agent Playability:** Portfolio diversification across active trading and passive income.

### 12. Production Chain for High-Value Drugs
**Inspired by:** Schedule 1's multi-step drug production (grow → dry → mix → cook).  
**Current:** All drugs available at shops, no supply-side mechanics.
**Proposed:** Top-tier drugs (Cocaine, Ketamine) require processing:
- Raw materials purchased at specific locations
- Processing takes turns and equipment
- Processed drugs have 3-5x higher sell value than raw materials
- Processing equipment costs money and takes inventory space
**Impact:** Adds an operations management dimension — players choose between trading margins and manufacturing margins.
**Agent Playability:** Multi-stage production scheduling is a classic OR problem.

---

## Part C: Agent-Specific Improvements

### 13. Deterministic Seed / Replay Mode
**Current:** VRF randomness from Cartridge — cannot be replayed or simulated.
**Proposed:** Add an offchain simulation mode using seed-based PRNG (Poseidon hash chain):
- `create_game_with_seed(seed)` — deterministic game state evolution
- `fn simulate_travel(game_id, destination) -> SimulationResult` — preview outcomes
- `fn market_snapshot(game_id) -> MarketState[]` — full market visibility for analysis
- Game replay export to JSON format for training datasets
**Impact:** Essential for agent training, testing, and competition. Without deterministic seeds, agents cannot learn from replays.

### 14. Strategy Prediction Hooks / Agent API
**Current:** Agents must query raw state and compute everything themselves.
**Proposed:** Add helper functions:
- `fn estimate_profit(game_id, drug, from_location, to_location) -> int`
- `fn get_optimal_travel(game_id) -> (destination, expected_gain)`
- `fn encounter_risk(game_id, destination) -> RiskScore`
- `fn best_trade_opportunity(game_id) -> Trade`
**Impact:** Levels the playing field — agents can focus on strategy rather than raw computation.

### 15. Game State Serialization & Training Datasets
**Current:** No mechanism to export/replay game state.
**Proposed:** Add export functionality:
- `fn serialize_game(game_id) -> JSON` — complete game state
- `fn serialize_replay(game_id) -> JSON` — all actions taken with outcomes
- Store replays on IPFS or Arweave for agent training datasets
- Leaderboard includes replay links for strategy sharing
**Impact:** Creates a dataset for training competing agents — the game becomes a benchmark platform.

### 16. Multi-Agent Competitive Modes
**Current:** Leaderboards are post-hoc. No live multiplayer interaction.
**Proposed:** Add competitive modes:
- **Shared Market:** Multiple players' trades shift shared market prices (aggregate supply/demand)
- **Turf Control:** Players compete for territory bonuses — control a district for price advantages
- **Sniper Mode:** Race to catch specific price events before opponents
- **Observer Mode:** Spectate and learn from top-agent replays in real-time
**Impact:** Transforms the game from a solitaire puzzle to a competitive ecosystem.

---

## Part D: Quality-of-Life & Balance Fixes

### 17. Fix Encounter Balance
**Current:** Encounter combat is trivial — encounters have hardcoded damage nerfs (`attack / 3`, `attack / 5` marked TODO in code).
**Proposed:** Remove hardcoded nerfs, implement proper scaling. Introduce a configurable combat difficulty curve. Add critical hits, stamina, or armor-piercing mechanics.

### 18. Hospital / Health Recovery
**Current:** No way to recover health except by not losing it.
**Proposed:** Add hospital visits that cost cash and skip a turn. Adds a recovery decision node — is it worth losing a turn to heal?

### 19. Ammo System
**Current:** Weapons have infinite ammo. No resource management in combat.
**Proposed:** Weapons deplete ammo. Ammo purchased at shops. Adds a pre-combat resource decision.

### 20. Dynamic Drug Tiers
**Current:** Drugs are unlocked linearly by reputation level (`drug_level` to `drug_level + 3`).
**Proposed:** Introduce market events where drug availability changes — shortages, new strains discovered, regulatory crackdowns. Makes the unlock progression non-deterministic.

---

## Priority Roadmap

| Priority | Feature | Impact | Effort | Agent Value |
|----------|---------|--------|--------|-------------|
| P0 | Multi-drug inventory | HIGH | Medium | Transforms trivial → strategic |
| P0 | Bank + interest | HIGH | Low | Creates risk modeling |
| P0 | Special events | HIGH | Medium | Breaks stationarity |
| P0 | Deterministic seed mode | HIGH | Medium | Enables training entirely |
| P1 | Location modifiers | MEDIUM | Low | Spatial optimization |
| P1 | Customer network | HIGH | Medium | Portfolio management |
| P1 | Heat system | MEDIUM | Medium | State management |
| P1 | Dealer automation | MEDIUM | Medium | Reduces agent click-burn |
| P2 | Drug quality/mixing | MEDIUM | Medium | Operations optimization |
| P2 | Gear synergies | LOW | Medium | Build diversity |
| P2 | Money laundering | MEDIUM | Medium | Passive income layer |
| P2 | Production chains | MEDIUM | High | Multi-stage scheduling |
| P3 | Combat fixes | MEDIUM | Low | Better encounter game |
| P3 | Hospital recovery | LOW | Low | Adds recovery node |
| P3 | Shared market / PVP | HIGH | High | Creates adversarial env |

---

## Comparison: Dope Wars vs This Implementation vs Schedule 1

| Feature | Classic Dope Wars | Current Implementation | Schedule 1 | Recommended for This Game |
|---------|-------------------|----------------------|------------|--------------------------|
| Bank + interest | Yes | No | No (ATM only) | Add |
| Debt/loan shark | Yes | No | No | Add |
| Multi-drug inventory | Yes (coat) | No (single) | Yes (multi-slot) | Add |
| Special events | Yes | No | Yes (random events) | Add |
| Multi-city travel | Yes (airports) | No | Yes (7 regions) | Add location mods |
| Customer network | No | No | 70+ NPCs | Add simplified |
| Manufacturing/production | No | No | Full chains | Add simplified |
| Employee automation | No | No | Yes (buggy) | Add dealer system |
| Police escalation | No | Partial (wanted) | 3 heat levels | Expand |
| Money laundering | No | Minimal laundromat | Businesses + limits | Expand fully |
| Deterministic replay | N/A | N/A | No | Add |
| Multi-agent competitive | N/A | Leaderboard only | Co-op | Add shared market |

---

## Next Steps

1. Review and prioritize this list with the dev team
2. Start with P0 items — bank system and multi-drug inventory have highest impact-to-effort ratio
3. Implement deterministic seed mode in parallel — enables all agent testing
4. Design the agent API hooks early so they're part of the contract interfaces from the start
5. Consider a "season 2" that layers these systems on top of the existing game without breaking backward compatibility

---

*This document was generated by automated analysis of the codebase, Schedule 1 wiki mechanics, and independent technical review. All suggestions are grounded in existing code patterns and proven game design from both classic Dope Wars and Schedule 1.*
