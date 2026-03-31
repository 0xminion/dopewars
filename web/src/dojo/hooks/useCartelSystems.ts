import { useCallback } from "react";
import { CallData, shortString, hash } from "starknet";
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

function packAction(a: ActionInput): bigint {
  return (
    BigInt(a.actionType) +
    BigInt(a.targetLocation) * 0x100n +
    BigInt(a.drugId) * 0x10000n +
    BigInt(a.quantity) * 0x1000000n +
    BigInt(a.ingredientId) * 0x10000000000n +
    BigInt(a.slotIndex) * 0x1000000000000n
  );
}

function serializeActions(actions: ActionInput[]): bigint[] {
  return actions.map(packAction);
}

function hashActions(actions: ActionInput[], salt: bigint): bigint {
  // Poseidon hash matching Cairo's hash_actions:
  //   state.update(salt); for each action: state.update(pack(action)); state.finalize()
  // poseidonHashMany([salt, ...packed]) is equivalent to the above sponge sequence.
  const inputs = [salt, ...actions.map(packAction)];
  const hexResult = hash.computePoseidonHashOnElements(inputs.map((v) => `0x${v.toString(16)}`));
  return BigInt(hexResult);
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
      // Cairo signature: reveal_resolve(game_id: u32, actions: Array<Action>, salt: felt252)
      // Calldata order: game_id, array_length, ...array_elements, salt
      return execute("reveal_resolve", [
        gameId,
        serialized.length,
        ...serialized.map((v) => `0x${v.toString(16)}`),
        `0x${salt.toString(16)}`,
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
