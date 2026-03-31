import { Box, Button, Heading, HStack, Select, Spinner, Text, VStack } from "@chakra-ui/react";
import { useState } from "react";
import { LOCATION_NAMES } from "../../dojo/class/CartelPlayer";
import { CartelSlot } from "../../dojo/class/CartelSlot";
import { DealerCard } from "./DealerCard";

interface DealerPanelProps {
  slots: CartelSlot[];
  loading: boolean;
  onCollect: (slotId: number) => void;
  onFire: (slotId: number) => void;
  onSetStrategy: (slotId: number, strategy: number) => void;
  onHire: (locationId: number) => void;
}

export function DealerPanel({ slots, loading, onCollect, onFire, onSetStrategy, onHire }: DealerPanelProps) {
  const [hireLocation, setHireLocation] = useState<number>(1);

  if (loading) {
    return (
      <Box p={4} display="flex" alignItems="center" justifyContent="center">
        <Spinner color="yellow.400" />
      </Box>
    );
  }

  return (
    <VStack align="stretch" gap={4}>
      {/* Hire section */}
      <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.600" bg="gray.800">
        <Text fontWeight="bold" fontSize="sm" color="white" mb={2}>
          HIRE DEALER
        </Text>
        <HStack gap={2}>
          <Select
            size="sm"
            value={hireLocation}
            bg="gray.700"
            borderColor="gray.600"
            color="white"
            onChange={(e) => setHireLocation(Number(e.target.value))}
            flex={1}
          >
            {Object.entries(LOCATION_NAMES)
              .filter(([key]) => Number(key) > 0)
              .map(([key, name]) => (
                <option key={key} value={key}>
                  {name}
                </option>
              ))}
          </Select>
          <Button size="sm" colorScheme="green" onClick={() => onHire(hireLocation)}>
            Hire
          </Button>
        </HStack>
      </Box>

      {/* Dealer list */}
      <Heading size="xs" color="gray.400" textTransform="uppercase" letterSpacing="wider">
        Dealers ({slots.length})
      </Heading>

      {slots.length === 0 ? (
        <Box p={4} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
          <Text fontSize="sm" color="gray.500" textAlign="center">
            No dealers hired yet.
          </Text>
        </Box>
      ) : (
        slots.map((slot) => (
          <DealerCard
            key={slot.state.slotId}
            slot={slot}
            onCollect={onCollect}
            onFire={onFire}
            onSetStrategy={onSetStrategy}
          />
        ))
      )}
    </VStack>
  );
}
