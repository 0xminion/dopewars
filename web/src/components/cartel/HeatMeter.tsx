import { Box, Progress, Text, VStack } from "@chakra-ui/react";
import { CartelHeat } from "../../dojo/class/CartelHeat";

interface HeatMeterProps {
  heat: CartelHeat | null;
}

const PROGRESS_COLOR: Record<number, string> = {
  0: "green",
  1: "yellow",
  2: "orange",
  3: "red",
};

export function HeatMeter({ heat }: HeatMeterProps) {
  const tierName = heat?.tierName ?? "None";
  const tierColor = heat?.tierColor ?? "green.400";
  const tier = heat?.state.tier ?? 0;
  const notoriety = heat?.state.notoriety ?? 0;

  const progressValue = Math.min(100, notoriety);
  const colorScheme = PROGRESS_COLOR[tier] ?? "green";

  return (
    <VStack align="stretch" gap={2} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        HEAT
      </Text>
      <Box>
        <Text fontSize="sm" color={tierColor} fontWeight="bold">
          {tierName}
        </Text>
        <Text fontSize="xs" color="gray.400">
          Notoriety: {notoriety}
        </Text>
      </Box>
      <Progress value={progressValue} max={100} colorScheme={colorScheme} size="sm" borderRadius="full" bg="gray.700" />
    </VStack>
  );
}
