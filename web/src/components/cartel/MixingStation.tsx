import { Badge, Box, Button, HStack, Select, Text, VStack } from "@chakra-ui/react";
import { useState } from "react";
import { CartelInventory, DRUG_NAMES, EFFECT_NAMES } from "../../dojo/class/CartelInventory";

const INGREDIENT_NAMES: Record<number, string> = {
  1: "Baking Soda",
  2: "Acetone",
  3: "Ammonia",
  4: "Bleach",
  5: "Ethanol",
  6: "Hydrochloric Acid",
};

interface MixingStationProps {
  inventory: CartelInventory | null;
  onMix?: (slotIndex: number, ingredientId: number) => void;
}

export function MixingStation({ inventory, onMix }: MixingStationProps) {
  const [selectedSlot, setSelectedSlot] = useState<number>(0);
  const [selectedIngredient, setSelectedIngredient] = useState<number>(1);

  const filledSlots = (inventory?.slots ?? []).filter((s) => s.drugId !== 0);
  const currentSlot = inventory?.slots[selectedSlot];

  const handleMix = () => {
    if (onMix) {
      onMix(selectedSlot, selectedIngredient);
    }
  };

  return (
    <VStack align="stretch" gap={3} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        MIXING STATION
      </Text>

      <Box>
        <Text fontSize="xs" color="gray.400" mb={1}>
          Drug Slot
        </Text>
        <Select
          size="sm"
          value={selectedSlot}
          onChange={(e) => setSelectedSlot(Number(e.target.value))}
          bg="gray.700"
          borderColor="gray.600"
        >
          {(inventory?.slots ?? []).map((slot, idx) => (
            <option key={idx} value={idx}>
              Slot {idx + 1}: {slot.drugId === 0 ? "Empty" : DRUG_NAMES[slot.drugId] ?? "Unknown"}
            </option>
          ))}
        </Select>
      </Box>

      <Box>
        <Text fontSize="xs" color="gray.400" mb={1}>
          Ingredient
        </Text>
        <Select
          size="sm"
          value={selectedIngredient}
          onChange={(e) => setSelectedIngredient(Number(e.target.value))}
          bg="gray.700"
          borderColor="gray.600"
        >
          {Object.entries(INGREDIENT_NAMES).map(([id, name]) => (
            <option key={id} value={id}>
              {name}
            </option>
          ))}
        </Select>
      </Box>

      {currentSlot && currentSlot.drugId !== 0 && (
        <Box p={2} bg="gray.800" borderRadius="md">
          <Text fontSize="xs" color="gray.400" mb={1}>
            Current effects
          </Text>
          <HStack flexWrap="wrap" gap={1}>
            {currentSlot.effects.length === 0 ? (
              <Text fontSize="xs" color="gray.600">
                None
              </Text>
            ) : (
              currentSlot.effects.map((eff) => (
                <Badge key={eff} colorScheme="teal" fontSize="10px">
                  {EFFECT_NAMES[eff] ?? `eff${eff}`}
                </Badge>
              ))
            )}
          </HStack>
        </Box>
      )}

      <Button size="sm" colorScheme="yellow" onClick={handleMix} isDisabled={!currentSlot || currentSlot.drugId === 0}>
        Mix
      </Button>
    </VStack>
  );
}
