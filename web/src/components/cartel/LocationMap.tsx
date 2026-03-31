import { Box, SimpleGrid, Text, VStack } from "@chakra-ui/react";
import { LOCATION_NAMES, CartelPlayer } from "../../dojo/class/CartelPlayer";
import { CartelHeat } from "../../dojo/class/CartelHeat";

interface LocationMapProps {
  player: CartelPlayer | null;
  heat: CartelHeat | null;
  onSelectLocation?: (locationId: number) => void;
}

const LOCATION_IDS = [1, 2, 3, 4, 5, 6];

export function LocationMap({ player, heat, onSelectLocation }: LocationMapProps) {
  const currentLocation = player?.state.location ?? -1;

  return (
    <VStack align="stretch" gap={2} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        MAP
      </Text>
      <SimpleGrid columns={3} gap={2}>
        {LOCATION_IDS.map((locId) => {
          const isCurrent = locId === currentLocation;
          const locationHeat = heat?.getLocationHeat(locId - 1) ?? 0;
          const isFog = locationHeat === 0 && !isCurrent;

          return (
            <Box
              key={locId}
              p={2}
              borderRadius="md"
              borderWidth="2px"
              borderColor={isCurrent ? "yellow.400" : "gray.600"}
              bg={isCurrent ? "yellow.900" : isFog ? "gray.800" : "gray.700"}
              cursor={onSelectLocation ? "pointer" : "default"}
              onClick={() => onSelectLocation?.(locId)}
              opacity={isFog ? 0.5 : 1}
              _hover={onSelectLocation ? { borderColor: "yellow.500" } : {}}
            >
              <Text fontSize="xs" fontWeight={isCurrent ? "bold" : "normal"} color={isCurrent ? "yellow.300" : "white"}>
                {LOCATION_NAMES[locId]}
              </Text>
              {isFog && (
                <Text fontSize="10px" color="gray.500">
                  ???
                </Text>
              )}
              {!isFog && (
                <Text fontSize="10px" color={locationHeat > 128 ? "red.400" : "gray.400"}>
                  Heat: {locationHeat}
                </Text>
              )}
            </Box>
          );
        })}
      </SimpleGrid>
    </VStack>
  );
}
