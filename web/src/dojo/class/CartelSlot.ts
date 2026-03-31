import { DRUG_NAMES } from "./CartelInventory";
import { LOCATION_NAMES } from "./CartelPlayer";

export enum SlotType {
  None = 0,
  Dealer = 1,
  Cook = 2,
  Runner = 3,
  Muscle = 4,
}
export enum SlotStatus {
  Inactive = 0,
  Active = 1,
  Busted = 2,
  LayingLow = 3,
}
export const STRATEGY_NAMES: Record<number, string> = { 0: "Cautious", 1: "Aggressive", 2: "Balanced" };

export interface SlotState {
  gameId: number;
  slotId: number;
  slotType: SlotType;
  status: SlotStatus;
  strategy: number;
  location: number;
  drugId: number;
  drugQuantity: number;
  earnings: number;
  reliability: number;
  stealth: number;
  salesmanship: number;
}

export class CartelSlot {
  state: SlotState;
  constructor(state: SlotState) {
    this.state = state;
  }
  get locationName(): string {
    return LOCATION_NAMES[this.state.location] || "Unknown";
  }
  get drugName(): string {
    return DRUG_NAMES[this.state.drugId] || "None";
  }
  get strategyName(): string {
    return STRATEGY_NAMES[this.state.strategy] || "Unknown";
  }
  get isActive(): boolean {
    return this.state.status === SlotStatus.Active;
  }
  get isBusted(): boolean {
    return this.state.status === SlotStatus.Busted;
  }

  static fromRaw(raw: any): CartelSlot {
    return new CartelSlot({
      gameId: Number(raw.game_id),
      slotId: Number(raw.slot_id),
      slotType: Number(raw.slot_type),
      status: Number(raw.status),
      strategy: Number(raw.strategy),
      location: Number(raw.location),
      drugId: Number(raw.drug_id),
      drugQuantity: Number(raw.drug_quantity),
      earnings: Number(raw.earnings_held),
      reliability: Number(raw.reliability),
      stealth: Number(raw.stealth),
      salesmanship: Number(raw.salesmanship),
    });
  }
}
