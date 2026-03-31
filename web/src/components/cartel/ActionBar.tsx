import { Box, HStack, Text, VStack } from "@chakra-ui/react";
import { CartelPlayer } from "../../dojo/class/CartelPlayer";

interface ActionBarProps {
  player: CartelPlayer | null;
  wallet: { dirtyCash: number; cleanCash: number } | null;
}

export function ActionBar({ player, wallet }: ActionBarProps) {
  const apRemaining = player?.state.apRemaining ?? 0;
  const maxAp = 6;

  return (
    <VStack align="stretch" gap={3} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        ACTION POINTS
      </Text>
      <HStack gap={2}>
        {Array.from({ length: maxAp }).map((_, i) => (
          <Box
            key={i}
            w="20px"
            h="20px"
            borderRadius="full"
            bg={i < apRemaining ? "yellow.400" : "gray.600"}
            borderWidth="1px"
            borderColor="gray.500"
          />
        ))}
      </HStack>
      <Text fontSize="xs" color="gray.400">
        {apRemaining} / {maxAp} AP remaining
      </Text>

      <Box borderTopWidth="1px" borderColor="gray.600" pt={2}>
        <Text fontWeight="bold" fontSize="sm" mb={1}>
          WALLET
        </Text>
        <HStack justify="space-between">
          <Text fontSize="xs" color="yellow.300">
            Dirty: ${wallet?.dirtyCash?.toLocaleString() ?? 0}
          </Text>
          <Text fontSize="xs" color="green.300">
            Clean: ${wallet?.cleanCash?.toLocaleString() ?? 0}
          </Text>
        </HStack>
      </Box>
    </VStack>
  );
}
