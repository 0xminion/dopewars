export const OP_TYPE_NAMES: Record<number, string> = {
  1: "Laundromat",
  2: "Car Wash",
  3: "Taco Shop",
  4: "Post Office",
};

export interface OperationState {
  gameId: number;
  opId: number;
  opType: number;
  level: number;
  capacityPerTurn: number;
  processingAmount: number;
  processingTurnsLeft: number;
  totalLaundered: number;
}

export class CartelOperation {
  state: OperationState;
  constructor(state: OperationState) {
    this.state = state;
  }
  get typeName(): string {
    return OP_TYPE_NAMES[this.state.opType] || "Unknown";
  }
  get isProcessing(): boolean {
    return this.state.processingAmount > 0;
  }

  static fromRaw(raw: any): CartelOperation {
    return new CartelOperation({
      gameId: Number(raw.game_id),
      opId: Number(raw.op_id),
      opType: Number(raw.op_type),
      level: Number(raw.level),
      capacityPerTurn: Number(raw.capacity_per_turn),
      processingAmount: Number(raw.processing_amount),
      processingTurnsLeft: Number(raw.processing_turns_left),
      totalLaundered: Number(raw.total_laundered),
    });
  }
}
