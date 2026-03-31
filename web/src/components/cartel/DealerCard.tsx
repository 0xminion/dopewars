import { Badge, Box, Button, HStack, Select, Text, VStack } from "@chakra-ui/react";
import { CartelSlot, SlotStatus, STRATEGY_NAMES } from "../../dojo/class/CartelSlot";

interface DealerCardProps {
  slot: CartelSlot;
  onCollect: (slotId: number) => void;
  onFire: (slotId: number) => void;
  onSetStrategy: (slotId: number, strategy: number) => void;
}

function statusColor(status: SlotStatus): string {
  switch (status) {
    case SlotStatus.Active:
      return "green";
    case SlotStatus.Busted:
      return "red";
    case SlotStatus.LayingLow:
      return "yellow";
    default:
      return "gray";
  }
}

function statusLabel(status: SlotStatus): string {
  switch (status) {
    case SlotStatus.Active:
      return "Active";
    case SlotStatus.Busted:
      return "Busted";
    case SlotStatus.LayingLow:
      return "Laying Low";
    default:
      return "Inactive";
  }
}

export function DealerCard({ slot, onCollect, onFire, onSetStrategy }: DealerCardProps) {
  const { slotId, status, location, drugId, drugQuantity, earnings, strategy } = slot.state;

  return (
    <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
      <VStack align="stretch" gap={2}>
        {/* Header row: slot ID, location, status */}
        <HStack justify="space-between">
          <Text fontWeight="bold" fontSize="sm" color="white">
            Slot #{slotId} — {slot.locationName}
          </Text>
          <Badge colorScheme={statusColor(status)} fontSize="10px">
            {statusLabel(status)}
          </Badge>
        </HStack>

        {/* Drug info */}
        <HStack gap={2}>
          <Text fontSize="xs" color="gray.400">
            Drug:
          </Text>
          <Text fontSize="xs" color={drugId === 0 ? "gray.600" : "white"}>
            {drugId === 0 ? "None" : slot.drugName}
          </Text>
          {drugId !== 0 && (
            <Text fontSize="xs" color="gray.300">
              x{drugQuantity}
            </Text>
          )}
        </HStack>

        {/* Earnings row */}
        <HStack justify="space-between">
          <HStack gap={2}>
            <Text fontSize="xs" color="gray.400">
              Held:
            </Text>
            <Text fontSize="xs" color="yellow.300">
              ${earnings.toLocaleString()}
            </Text>
          </HStack>
          <Button
            size="xs"
            colorScheme="yellow"
            variant="outline"
            isDisabled={earnings === 0}
            onClick={() => onCollect(slotId)}
          >
            Collect
          </Button>
        </HStack>

        {/* Strategy dropdown */}
        <HStack gap={2}>
          <Text fontSize="xs" color="gray.400" whiteSpace="nowrap">
            Strategy:
          </Text>
          <Select
            size="xs"
            value={strategy}
            bg="gray.700"
            borderColor="gray.600"
            color="white"
            onChange={(e) => onSetStrategy(slotId, Number(e.target.value))}
          >
            {Object.entries(STRATEGY_NAMES).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </Select>
        </HStack>

        {/* Action buttons */}
        <HStack gap={2} justify="flex-end">
          <Button size="xs" colorScheme="blue" variant="outline">
            Restock
          </Button>
          <Button size="xs" colorScheme="red" variant="outline" onClick={() => onFire(slotId)}>
            Fire
          </Button>
        </HStack>
      </VStack>
    </Box>
  );
}
