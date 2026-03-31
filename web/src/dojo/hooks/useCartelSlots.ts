import { useState, useEffect } from "react";
import { CartelSlot } from "../class/CartelSlot";

export interface CartelSlotsState {
  slots: CartelSlot[];
  loading: boolean;
}

export function useCartelSlots(gameId: number | null): CartelSlotsState {
  const [state, setState] = useState<CartelSlotsState>({ slots: [], loading: true });

  useEffect(() => {
    if (!gameId) {
      setState({ slots: [], loading: false });
      return;
    }
    // Placeholder: Torii subscription to be wired later
    setState({ slots: [], loading: false });
  }, [gameId]);

  return state;
}
