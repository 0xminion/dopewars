import { Badge, Box, HStack, Text, VStack } from "@chakra-ui/react";
import { CartelInventory, DRUG_NAMES, EFFECT_NAMES } from "../../dojo/class/CartelInventory";

interface InventoryPanelProps {
  inventory: CartelInventory | null;
}

export function InventoryPanel({ inventory }: InventoryPanelProps) {
  const slots = inventory?.slots ?? [
    { drugId: 0, quantity: 0, quality: 0, effects: [] },
    { drugId: 0, quantity: 0, quality: 0, effects: [] },
    { drugId: 0, quantity: 0, quality: 0, effects: [] },
    { drugId: 0, quantity: 0, quality: 0, effects: [] },
  ];

  return (
    <VStack align="stretch" gap={2} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        INVENTORY
      </Text>
      {slots.map((slot, idx) => {
        const isEmpty = slot.drugId === 0;
        return (
          <Box
            key={idx}
            p={2}
            borderRadius="md"
            borderWidth="1px"
            borderColor={isEmpty ? "gray.700" : "gray.500"}
            bg={isEmpty ? "gray.800" : "gray.700"}
          >
            <HStack justify="space-between">
              <Text fontSize="sm" color={isEmpty ? "gray.600" : "white"} fontWeight="bold">
                {isEmpty ? "— empty —" : DRUG_NAMES[slot.drugId] ?? "Unknown"}
              </Text>
              {!isEmpty && (
                <Text fontSize="xs" color="gray.300">
                  x{slot.quantity}
                </Text>
              )}
            </HStack>
            {!isEmpty && (
              <HStack mt={1} flexWrap="wrap" gap={1}>
                <Badge colorScheme="purple" fontSize="10px">
                  Q{slot.quality}
                </Badge>
                {slot.effects.map((eff) => (
                  <Badge key={eff} colorScheme="teal" fontSize="10px">
                    {EFFECT_NAMES[eff] ?? `eff${eff}`}
                  </Badge>
                ))}
              </HStack>
            )}
          </Box>
        );
      })}
    </VStack>
  );
}
