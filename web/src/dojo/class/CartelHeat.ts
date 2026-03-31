export const HEAT_TIER_NAMES: Record<number, string> = {
  0: "None",
  1: "Surveillance",
  2: "Wanted",
  3: "Dead or Alive",
};
export const HEAT_TIER_COLORS: Record<number, string> = {
  0: "green.400",
  1: "yellow.400",
  2: "orange.400",
  3: "red.500",
};

export interface HeatState {
  tier: number;
  notoriety: number;
  locationHeat: number[];
}

export class CartelHeat {
  state: HeatState;
  constructor(state: HeatState) {
    this.state = state;
  }
  get tierName(): string {
    return HEAT_TIER_NAMES[this.state.tier] || "Unknown";
  }
  get tierColor(): string {
    return HEAT_TIER_COLORS[this.state.tier] || "gray.400";
  }
  getLocationHeat(locationIdx: number): number {
    return this.state.locationHeat[locationIdx] || 0;
  }

  static fromRaw(raw: any): CartelHeat {
    const packed = BigInt(raw.location_heat);
    const locationHeat: number[] = [];
    for (let i = 0; i < 6; i++) {
      locationHeat.push(Number((packed >> BigInt(i * 8)) & 0xffn));
    }
    return new CartelHeat({ tier: Number(raw.tier), notoriety: Number(raw.notoriety), locationHeat });
  }
}
