import { Box, Grid, GridItem, HStack, Text, VStack } from "@chakra-ui/react";
import { CartelInventory } from "../../dojo/class/CartelInventory";
import { CartelOperation } from "../../dojo/class/CartelOperation";
import { CartelReputation } from "../../dojo/class/CartelReputation";
import { CartelSlot, SlotStatus } from "../../dojo/class/CartelSlot";

interface CartelOverviewProps {
  slots: CartelSlot[];
  operations: CartelOperation[];
  inventory: CartelInventory | null;
  wallet: { dirtyCash: number; cleanCash: number } | null;
  reputation: CartelReputation | null;
}

function StatBox({ label, value, color }: { label: string; value: string | number; color?: string }) {
  return (
    <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
      <Text fontSize="10px" color="gray.400" textTransform="uppercase" letterSpacing="wider" mb={1}>
        {label}
      </Text>
      <Text fontSize="lg" fontWeight="bold" color={color ?? "white"}>
        {value}
      </Text>
    </Box>
  );
}

export function CartelOverview({ slots, operations, inventory, wallet, reputation }: CartelOverviewProps) {
  const activeCount = slots.filter((s) => s.state.status === SlotStatus.Active).length;
  const bustedCount = slots.filter((s) => s.state.status === SlotStatus.Busted).length;
  const totalDrugs = inventory ? inventory.slots.reduce((sum, s) => sum + s.quantity, 0) : 0;

  const repSummary = reputation
    ? `Trader Lv${reputation.state.traderLvl} / Enforcer Lv${reputation.state.enforcerLvl} / Operator Lv${reputation.state.operatorLvl}`
    : "—";

  return (
    <VStack align="stretch" gap={4}>
      <Text fontWeight="bold" fontSize="sm" color="white" textTransform="uppercase" letterSpacing="wider">
        Empire Overview
      </Text>

      <Grid templateColumns="repeat(2, 1fr)" gap={3}>
        <StatBox
          label="Active Dealers"
          value={`${activeCount} active / ${bustedCount} busted`}
          color={bustedCount > 0 ? "red.300" : "green.300"}
        />
        <StatBox label="Operations" value={operations.length} color="cyan.300" />
        <StatBox
          label="Treasury (Clean)"
          value={wallet ? `$${wallet.cleanCash.toLocaleString()}` : "—"}
          color="yellow.300"
        />
        <StatBox label="Dirty Cash" value={wallet ? `$${wallet.dirtyCash.toLocaleString()}` : "—"} color="orange.300" />
      </Grid>

      {/* Stash summary */}
      <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
        <Text fontSize="10px" color="gray.400" textTransform="uppercase" letterSpacing="wider" mb={2}>
          Stash
        </Text>
        {!inventory || inventory.isEmpty ? (
          <Text fontSize="sm" color="gray.600">
            Empty
          </Text>
        ) : (
          <VStack align="stretch" gap={1}>
            {inventory.slots
              .filter((s) => s.drugId !== 0)
              .map((s, idx) => (
                <HStack key={idx} justify="space-between">
                  <Text fontSize="xs" color="white">
                    {s.drugId} — Q{s.quality}
                  </Text>
                  <Text fontSize="xs" color="gray.300">
                    x{s.quantity}
                  </Text>
                </HStack>
              ))}
            <Text fontSize="10px" color="gray.500" mt={1}>
              Total units: {totalDrugs}
            </Text>
          </VStack>
        )}
      </Box>

      {/* Reputation summary */}
      <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
        <Text fontSize="10px" color="gray.400" textTransform="uppercase" letterSpacing="wider" mb={1}>
          Reputation
        </Text>
        <Text fontSize="sm" color="purple.300">
          {repSummary}
        </Text>
      </Box>
    </VStack>
  );
}
