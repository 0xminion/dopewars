import { Box, Heading, HStack, Spinner, Text, VStack } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { DealerPanel } from "../../../components/cartel/DealerPanel";
import { useCartelSlots } from "../../../dojo/hooks/useCartelSlots";

export default function DealersPage() {
  const router = useRouter();
  const { gameId } = router.query;

  const parsedGameId = gameId && !Array.isArray(gameId) ? parseInt(gameId, 16) || parseInt(gameId, 10) || null : null;

  const { slots, loading } = useCartelSlots(parsedGameId);

  const handleCollect = (slotId: number) => {
    console.log("collect", slotId);
  };

  const handleFire = (slotId: number) => {
    console.log("fire", slotId);
  };

  const handleSetStrategy = (slotId: number, strategy: number) => {
    console.log("set strategy", slotId, strategy);
  };

  const handleHire = (locationId: number) => {
    console.log("hire at", locationId);
  };

  return (
    <Box minH="100dvh" bg="gray.900" color="white" p={[2, 4]}>
      <HStack mb={4} justify="space-between">
        <Heading size="md" color="yellow.400">
          DEALERS
        </Heading>
        {parsedGameId && (
          <Text fontSize="xs" color="gray.500">
            Game #{parsedGameId}
          </Text>
        )}
      </HStack>

      {!parsedGameId ? (
        <VStack gap={4} pt={8} align="center">
          <Text color="gray.500">No game ID found.</Text>
        </VStack>
      ) : (
        <DealerPanel
          slots={slots}
          loading={loading}
          onCollect={handleCollect}
          onFire={handleFire}
          onSetStrategy={handleSetStrategy}
          onHire={handleHire}
        />
      )}
    </Box>
  );
}
