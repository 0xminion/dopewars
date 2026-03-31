import { CartelInventory } from "./CartelInventory";

export interface CartelState {
  gameId: number;
  name: string;
  slotCount: number;
  treasury: number;
  stashSlots: bigint[];
}

export class CartelCartel {
  state: CartelState;
  constructor(state: CartelState) {
    this.state = state;
  }

  get stash(): CartelInventory {
    return new CartelInventory(this.state.stashSlots.map((s) => CartelInventory.unpackSlot(s)));
  }

  static fromRaw(raw: any): CartelCartel {
    return new CartelCartel({
      gameId: Number(raw.game_id),
      name: raw.name,
      slotCount: Number(raw.slot_count),
      treasury: Number(raw.treasury),
      stashSlots: [
        BigInt(raw.stash_slot_0 || 0),
        BigInt(raw.stash_slot_1 || 0),
        BigInt(raw.stash_slot_2 || 0),
        BigInt(raw.stash_slot_3 || 0),
        BigInt(raw.stash_slot_4 || 0),
        BigInt(raw.stash_slot_5 || 0),
      ],
    });
  }
}
