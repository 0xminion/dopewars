import { Box, Divider, Heading, HStack, Spinner, Text, VStack } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { CartelOverview } from "../../../components/cartel/CartelOverview";
import { ReputationTree } from "../../../components/cartel/ReputationTree";
import { useCartelGame } from "../../../dojo/hooks/useCartelGame";
import { useCartelOperations } from "../../../dojo/hooks/useCartelOperations";
import { useCartelSlots } from "../../../dojo/hooks/useCartelSlots";

export default function EmpirePage() {
  const router = useRouter();
  const { gameId } = router.query;

  const parsedGameId = gameId && !Array.isArray(gameId) ? parseInt(gameId, 16) || parseInt(gameId, 10) || null : null;

  const { inventory, wallet, reputation, loading: gameLoading } = useCartelGame(parsedGameId);
  const { slots, loading: slotsLoading } = useCartelSlots(parsedGameId);
  const { operations, loading: opsLoading } = useCartelOperations(parsedGameId);

  const loading = gameLoading || slotsLoading || opsLoading;

  return (
    <Box minH="100dvh" bg="gray.900" color="white" p={[2, 4]}>
      <HStack mb={4} justify="space-between">
        <Heading size="md" color="yellow.400">
          EMPIRE
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
      ) : loading ? (
        <VStack gap={4} pt={8} align="center">
          <Spinner size="xl" color="yellow.400" />
          <Text color="gray.400">Loading empire...</Text>
        </VStack>
      ) : (
        <VStack align="stretch" gap={6}>
          <CartelOverview
            slots={slots}
            operations={operations}
            inventory={inventory}
            wallet={wallet}
            reputation={reputation}
          />
          <Divider borderColor="gray.700" />
          <ReputationTree reputation={reputation} />
        </VStack>
      )}
    </Box>
  );
}
