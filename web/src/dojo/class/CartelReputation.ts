export const BRANCH_NAMES = ["Trader", "Enforcer", "Operator"] as const;
export type BranchName = (typeof BRANCH_NAMES)[number];
export const LEVEL_THRESHOLDS = [100, 300, 600, 1000, 1500];

export interface ReputationState {
  traderXp: number;
  enforcerXp: number;
  operatorXp: number;
  traderLvl: number;
  enforcerLvl: number;
  operatorLvl: number;
}

export class CartelReputation {
  state: ReputationState;
  constructor(state: ReputationState) {
    this.state = state;
  }

  getXp(branch: BranchName): number {
    switch (branch) {
      case "Trader":
        return this.state.traderXp;
      case "Enforcer":
        return this.state.enforcerXp;
      case "Operator":
        return this.state.operatorXp;
    }
  }

  getLevel(branch: BranchName): number {
    switch (branch) {
      case "Trader":
        return this.state.traderLvl;
      case "Enforcer":
        return this.state.enforcerLvl;
      case "Operator":
        return this.state.operatorLvl;
    }
  }

  getNextThreshold(branch: BranchName): number {
    const lvl = this.getLevel(branch);
    if (lvl >= 5) return Infinity;
    return LEVEL_THRESHOLDS[lvl];
  }

  getProgress(branch: BranchName): number {
    const xp = this.getXp(branch);
    const next = this.getNextThreshold(branch);
    if (next === Infinity) return 1;
    const prev = this.getLevel(branch) > 0 ? LEVEL_THRESHOLDS[this.getLevel(branch) - 1] : 0;
    return (xp - prev) / (next - prev);
  }

  static fromRaw(raw: any): CartelReputation {
    return new CartelReputation({
      traderXp: Number(raw.trader_xp),
      enforcerXp: Number(raw.enforcer_xp),
      operatorXp: Number(raw.operator_xp),
      traderLvl: Number(raw.trader_lvl),
      enforcerLvl: Number(raw.enforcer_lvl),
      operatorLvl: Number(raw.operator_lvl),
    });
  }
}
