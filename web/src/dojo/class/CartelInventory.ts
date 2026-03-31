export const DRUG_NAMES: Record<number, string> = {
  0: "Empty",
  1: "Weed",
  2: "Shrooms",
  3: "Acid",
  4: "Ecstasy",
  5: "Speed",
  6: "Heroin",
  7: "Meth",
  8: "Cocaine",
};

export const EFFECT_NAMES: Record<number, string> = {
  0: "None",
  1: "Cut",
  2: "Energizing",
  3: "Potent",
  4: "Bulking",
  5: "Healthy",
  6: "Toxic",
  7: "Speedy",
  8: "Electric",
};

export interface DrugSlot {
  drugId: number;
  quantity: number;
  quality: number;
  effects: number[];
}

export class CartelInventory {
  slots: DrugSlot[];

  constructor(slots: DrugSlot[]) {
    this.slots = slots;
  }

  static unpackSlot(packed: bigint): DrugSlot {
    const drugId = Number(packed & 0xffn);
    const quantity = Number((packed >> 8n) & 0xffffn);
    const quality = Number((packed >> 24n) & 0xffn);
    const effectsPacked = Number((packed >> 32n) & 0xffffffffn);
    const effects = [
      effectsPacked & 0xff,
      (effectsPacked >> 8) & 0xff,
      (effectsPacked >> 16) & 0xff,
      (effectsPacked >> 24) & 0xff,
    ].filter((e) => e !== 0);
    return { drugId, quantity, quality, effects };
  }

  static fromRaw(raw: any): CartelInventory {
    return new CartelInventory([
      CartelInventory.unpackSlot(BigInt(raw.slot_0)),
      CartelInventory.unpackSlot(BigInt(raw.slot_1)),
      CartelInventory.unpackSlot(BigInt(raw.slot_2)),
      CartelInventory.unpackSlot(BigInt(raw.slot_3)),
    ]);
  }

  get isEmpty(): boolean {
    return this.slots.every((s) => s.drugId === 0);
  }
  getSlot(index: number): DrugSlot {
    return this.slots[index];
  }
  get filledSlots(): number {
    return this.slots.filter((s) => s.drugId !== 0).length;
  }
}
