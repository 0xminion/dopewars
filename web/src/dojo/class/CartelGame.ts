export interface GameConfig {
  gameId: number;
  mode: number;
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
