# Agent2: Game Complexity & Replayability Enhancement Suggestions

> Analysis conducted by Agent2 after reviewing both the existing DopeWars Dojo/Starknet codebase and the Schedule 1 game mechanics from the official wiki.

## Executive Summary

The current DopeWars on-chain game provides solid infrastructure (Cairo/Starknet with Dojo, packed state, VRF-based randomness) but is constrained by shallow decision spaces. Schedule 1 demonstrates how depth emerges from mixing mechanics, customer networks, and regional specialization. The suggestions below bridge these worlds—adding complexity that works for both human strategists and AI agents while respecting on-chain constraints.

---

## 1. Core Game Logic Changes

### Drug Inventory & Mixing System
- **Expand inventory**: Allow carrying 2-4 drug types simultaneously (portfolio management)
- **Drug mixing**: Implement a simplified mixing mechanic inspired by Schedule 1's 34+ effects system
  - Base price calculation: `Round(Price * (1 + sum[multipliers]))`
  - 5-8 core effects with meaningful gameplay impact (not just cosmetic)
  - Mixing costs reputation or requires specific location (mixing tables)
- **Quality degradation**: Products lose value over time/turns, creating urgency
- **Strain/varietal system**: Each drug type has 3-4 variants with different risk/reward profiles

### Dynamic Market Mechanics
- **Customer preference system**: Each location has 2-3 preferred effects/drug types
  - Matching preferences = 1.5x-2x sell multiplier
  - Mismatched = 0.5x-0.7x multiplier
  - Creates regional arbitrage opportunities
- **Supply/demand simulation**: Heavy selling in one area crashes local prices temporarily
- **Market events**: Random "busts" or "raids" that spike/drop specific drug prices
- **Price history tracking**: Store last 3 ticks for trend analysis (AI agents need this)

### Movement & Geography
- **Location hierarchy**: Areas unlock progressively based on reputation/rank
- **Travel cost system**: Distance between locations affects time and encounter probability
- **Safe houses**: Unlockable locations with no encounter risk, lower wanted decay
- **Region control**: High-rep players control local drug prices in their primary area

---

## 2. Systems for Human Replayability

### Reputation & Rank Progression
- **Rank tiers**: Street Rat → Dealer → Kingpin (mirrors Schedule 1's progression)
- **Unlockables per rank**:
  - Higher-tier drugs
  - More inventory slots
  - Special abilities
  - Location access
- **Faction system**: Join/ally with different crews for bonuses

### Personal Effects System
- **Consumable effects**: Items that provide temporary buffs/debuffs
  - Speed: +movement, -stealth
  - Stealth: +escape chance, -carrying capacity
  - Combat: +fight damage, -negotiation ability
- **Addiction mechanic**: Using your own supplies provides temporary benefits but long-term penalties

### Social Multiplayer Elements
- **P2P trading**: Players can trade drugs/items directly (with escrow)
- **Leaderboard improvements**: Track multiple stats (profit, survival, encounters won)
- **Crew/guild system**: Form teams for cooperative objectives
- **Reputation network**: Player-to-player trust scores for trading

### Narrative & Immersion
- **Random events**: Overdoses, informant sightings, territory disputes
- **NPC encounters**: 5-6 encounter types beyond Cops/Gang (rival dealers, informants, addicts)
- **Decision consequences**: Choices affect future encounter probabilities and market prices
- **Seasonal storylines**: Each game season has a theme with unique modifiers

---

## 3. Systems for AI Agent Viability

### State Observability Enhancements
- **Market API**: Expose price history, current spread, volume data
- **Opponent visibility**: In ranked mode, show anonymized market activity
- **Encounter prediction**: Provide statistical likelihood of encounter types
- **Achievement tracking**: Real-time progress indicators for optimization targets

### Decision Space Expansion
- **Portfolio optimization**: Multiple asset classes create non-trivial decisions
- **Risk management**: Wanted level management across multiple locations
- **Timing decisions**: When to hold vs. sell based on market trends
- **Resource allocation**: Balance between equipment, drugs, and cash reserves

### Agent-Specific Features
- **API endpoints**: Direct contract interaction endpoints for automated trading
- **Simulation mode**: Test strategies without ranked consequences
- **Strategy templates**: Common agent patterns (arbitrage, accumulation, etc.)
- **Performance metrics**: Sharpe ratio equivalent for drug trading performance

---

## 4. Technical Implementation Considerations

### On-Chain Constraints
- **Bit-packing**: Current `GameStorePacked` efficiently uses ~144+ bits; redesign for additional drug slots and market data
- **Gas optimization**: Batch state updates, pre-compute market variations
- **Storage limits**: Balance detailed market history with on-chain storage costs
- **VRF integration**: Maintain verifiable randomness for market movements and encounters

### Architecture Recommendations
- **Modular systems**: Keep mixing, trading, and encounter systems separate for easier updates
- **Configuration-driven**: Move drug/effects parameters to config contracts for赛季 updates
- **Event-driven**: Emit comprehensive events for off-chain indexers and AI monitoring
- **Upgrade path**: Implement proxy pattern for contract upgrades without state loss

### Testing & Balancing
- **Simulation framework**: Off-chain Monte Carlo simulations for market balancing
- **AI vs AI testing**: Deploy agent strategies to stress-test economy
- **Parameter tuning**: Gradual introduction with community feedback
- **Economic modeling**: Prevent inflation/deflation loops in drug economy

---

## 5. Priority Roadmap

### Phase 1: Foundation (Low Risk, High Impact)
1. Expand drug inventory to 2-3 types
2. Add customer preference system per location
3. Implement basic mixing with 3-4 effects
4. Fix existing bugs (is_first_sell flag, price stasis)

### Phase 2: Depth (Medium Complexity)
1. Full rank progression system
2. Regional market dynamics and supply/demand
3. P2P trading with escrow
4. Enhanced encounter variety

### Phase 3: Scale (High Complexity)
1. Full faction/guild system
2. Advanced AI agent API
3. Comprehensive market history
4. Multi-location territory control

---

## 6. Bug Fixes Required

From codebase analysis, these bugs must be addressed:
- `is_first_sell = false` misused in Buy branch (breaks BUY_LOW achievement)
- Price stasis issue: prices only change on turn transitions
- Back-and-forth wanted level manipulation
- Tier 3 items cheaper than Tier 2 (inverted progression)

---

## References

- Schedule 1 Official Wiki: https://schedule-1.fandom.com/wiki/Schedule_1_Wiki
- DopeWars Repository: https://github.com/0xminion/dopewars
- Dojo Engine Documentation: https://book.dojoengine.org/
- Schedule 1 Game Mechanics Research (Drugs, Effects, Customer Preferences, Price Calculation)

---

*Generated by Agent2 - March 2025*