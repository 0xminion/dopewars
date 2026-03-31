export enum PlayerStatus {
  Normal = 0,
  Jailed = 1,
  Hospitalized = 2,
  Dead = 3,
  Finished = 4,
}

export const LOCATION_NAMES: Record<number, string> = {
  0: "Home",
  1: "Queens",
  2: "Bronx",
  3: "Brooklyn",
  4: "Jersey City",
  5: "Central Park",
  6: "Coney Island",
};

export interface PlayerState {
  gameId: number;
  playerId: string;
  location: number;
  apRemaining: number;
  turn: number;
  maxTurns: number;
  status: PlayerStatus;
  score: number;
}

export class CartelPlayer {
  state: PlayerState;

  constructor(state: PlayerState) {
    this.state = state;
  }

  get locationName(): string {
    return LOCATION_NAMES[this.state.location] || "Unknown";
  }

  get isActive(): boolean {
    return this.state.status === PlayerStatus.Normal;
  }

  get turnsRemaining(): number {
    return Math.max(0, this.state.maxTurns - this.state.turn + 1);
  }

  static fromRaw(raw: any): CartelPlayer {
    return new CartelPlayer({
      gameId: Number(raw.game_id),
      playerId: raw.player_id,
      location: Number(raw.location),
      apRemaining: Number(raw.ap_remaining),
      turn: Number(raw.turn),
      maxTurns: Number(raw.max_turns),
      status: Number(raw.status) as PlayerStatus,
      score: Number(raw.score),
    });
  }
}
