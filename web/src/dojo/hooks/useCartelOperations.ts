import { useState, useEffect } from "react";
import { CartelOperation } from "../class/CartelOperation";

export interface CartelOperationsState {
  operations: CartelOperation[];
  loading: boolean;
}

export function useCartelOperations(gameId: number | null): CartelOperationsState {
  const [state, setState] = useState<CartelOperationsState>({ operations: [], loading: true });

  useEffect(() => {
    if (!gameId) {
      setState({ operations: [], loading: false });
      return;
    }
    setState({ operations: [], loading: false });
  }, [gameId]);

  return state;
}
