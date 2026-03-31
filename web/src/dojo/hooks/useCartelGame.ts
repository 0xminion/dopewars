import { useState, useEffect } from "react";
import { CartelPlayer } from "../class/CartelPlayer";
import { CartelInventory } from "../class/CartelInventory";
import { CartelHeat } from "../class/CartelHeat";
import { CartelReputation } from "../class/CartelReputation";
import { CartelMarket } from "../class/CartelMarket";

export interface CartelGameState {
  player: CartelPlayer | null;
  inventory: CartelInventory | null;
  wallet: { dirtyCash: number; cleanCash: number } | null;
  heat: CartelHeat | null;
  reputation: CartelReputation | null;
  markets: CartelMarket[];
  loading: boolean;
}

export function useCartelGame(gameId: number | null): CartelGameState {
  const [state, setState] = useState<CartelGameState>({
    player: null,
    inventory: null,
    wallet: null,
    heat: null,
    reputation: null,
    markets: [],
    loading: true,
  });

  useEffect(() => {
    if (!gameId) {
      setState((prev) => ({ ...prev, loading: false }));
      return;
    }
    // Placeholder: actual Torii subscription will be wired up later
    setState((prev) => ({ ...prev, loading: false }));
  }, [gameId]);

  return state;
}
