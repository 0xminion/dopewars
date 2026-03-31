import { useCallback } from "react";
import { CallData, shortString } from "starknet";
import { getContractByName } from "@dojoengine/core";
import { useAccount } from "@starknet-react/core";
import { useDojoContext } from "./useDojoContext";
import { DW_NS } from "../constants";
import { waitForTransaction } from "./useSystems";

export interface ActionInput {
  actionType: number;
  targetLocation: number;
  drugId: number;
  quantity: number;
  ingredientId: number;
  slotIndex: number;
}

function serializeActions(actions: ActionInput[]): bigint[] {
  return actions.map(
    (a) =>
      BigInt(a.actionType) |
      (BigInt(a.targetLocation) << 8n) |
      (BigInt(a.drugId) << 16n) |
      (BigInt(a.quantity) << 24n) |
      (BigInt(a.ingredientId) << 40n) |
      (BigInt(a.slotIndex) << 48n),
  );
}

function hashActions(actions: ActionInput[], salt: bigint): bigint {
  // Simple Poseidon-like hash placeholder — actual on-chain hash must match contract
  const serialized = serializeActions(actions);
  let h = salt;
  for (const v of serialized) {
    h = (h ^ v) * 6364136223846793005n + 1442695040888963407n;
    h = BigInt.asUintN(64, h);
  }
  return h;
}

export function useCartelSystems() {
  const {
    clients: { dojoProvider },
  } = useDojoContext();

  const { account } = useAccount();

  const cartelGameAddress = (() => {
    try {
      return getContractByName(dojoProvider.manifest, DW_NS, "cartel_game").address;
    } catch {
      return "0x0";
    }
  })();

  const execute = useCallback(
    async (entrypoint: string, calldata: any[]) => {
      if (!account) {
        console.warn("useCartelSystems: no account connected");
        return { hash: "0x0" };
      }
      try {
        const tx = await dojoProvider.execute(
          account,
          [
            {
              contractAddress: cartelGameAddress,
              entrypoint,
              calldata: CallData.compile(calldata),
            },
          ],
          DW_NS,
        );
        const receipt = await waitForTransaction(account, tx.transaction_hash);
        return { hash: tx.transaction_hash, receipt };
      } catch (e: any) {
        console.error(`useCartelSystems.${entrypoint} error`, e);
        return { hash: "0x0", error: e?.toString() };
      }
    },
    [account, dojoProvider, cartelGameAddress],
  );

  const createGame = useCallback(
    async (mode: number, playerName: string) => {
      return execute("create_game", [mode, shortString.encodeShortString(playerName)]);
    },
    [execute],
  );

  const commitActions = useCallback(
    async (gameId: number, actions: ActionInput[], salt: bigint) => {
      const commitHash = hashActions(actions, salt);
      const apCost = actions.length;
      const tx = await execute("commit_actions", [gameId, `0x${commitHash.toString(16)}`, apCost]);
      return { ...tx, salt, actions };
    },
    [execute],
  );

  const revealResolve = useCallback(
    async (gameId: number, actions: ActionInput[], salt: bigint) => {
      const serialized = serializeActions(actions);
      return execute("reveal_resolve", [
        gameId,
        `0x${salt.toString(16)}`,
        serialized.length,
        ...serialized.map((v) => `0x${v.toString(16)}`),
      ]);
    },
    [execute],
  );

  const endGame = useCallback(
    async (gameId: number) => {
      return execute("end_game", [gameId]);
    },
    [execute],
  );

  return { createGame, commitActions, revealResolve, endGame };
}
