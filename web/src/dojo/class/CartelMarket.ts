import { DRUG_NAMES } from "./CartelInventory";

const DRUG_CONFIGS: Record<number, { basePrice: number; priceStep: number }> = {
  1: { basePrice: 15, priceStep: 2 },
  2: { basePrice: 30, priceStep: 4 },
  3: { basePrice: 60, priceStep: 6 },
  4: { basePrice: 100, priceStep: 10 },
  5: { basePrice: 200, priceStep: 15 },
  6: { basePrice: 400, priceStep: 25 },
  7: { basePrice: 600, priceStep: 40 },
  8: { basePrice: 1000, priceStep: 60 },
};

export interface DrugMarketInfo {
  drugId: number;
  name: string;
  priceTick: number;
  price: number;
  supply: number;
}

export class CartelMarket {
  locationId: number;
  drugs: DrugMarketInfo[];
  isVisible: boolean;

  constructor(locationId: number, drugs: DrugMarketInfo[], isVisible: boolean) {
    this.locationId = locationId;
    this.drugs = drugs;
    this.isVisible = isVisible;
  }

  static unpackPrices(packed: bigint, count: number = 8): number[] {
    const ticks: number[] = [];
    for (let i = 0; i < count; i++) {
      ticks.push(Number((packed >> BigInt(i * 16)) & 0xffffn));
    }
    return ticks;
  }

  static tickToPrice(drugId: number, tick: number): number {
    const config = DRUG_CONFIGS[drugId];
    if (!config) return 0;
    return config.basePrice + tick * config.priceStep;
  }

  static fromRaw(raw: any, playerIdx: number): CartelMarket {
    const locationId = Number(raw.location_id);
    const visibleTo = BigInt(raw.visible_to);
    const isVisible = (visibleTo & (1n << BigInt(playerIdx))) !== 0n;
    if (!isVisible) return new CartelMarket(locationId, [], false);

    const priceTicks = CartelMarket.unpackPrices(BigInt(raw.drug_prices));
    const supplies = CartelMarket.unpackPrices(BigInt(raw.drug_supply));
    const drugs: DrugMarketInfo[] = [];
    for (let i = 0; i < 8; i++) {
      const drugId = i + 1;
      drugs.push({
        drugId,
        name: DRUG_NAMES[drugId],
        priceTick: priceTicks[i],
        price: CartelMarket.tickToPrice(drugId, priceTicks[i]),
        supply: supplies[i],
      });
    }
    return new CartelMarket(locationId, drugs, true);
  }
}
