import { Box, Heading, HStack, Text, VStack } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { OperationPanel } from "../../../components/cartel/OperationPanel";
import { useCartelOperations } from "../../../dojo/hooks/useCartelOperations";

export default function OperationsPage() {
  const router = useRouter();
  const { gameId } = router.query;

  const parsedGameId = gameId && !Array.isArray(gameId) ? parseInt(gameId, 16) || parseInt(gameId, 10) || null : null;

  const { operations, loading } = useCartelOperations(parsedGameId);

  const handleLaunder = (opId: number, amount: number) => {
    console.log("launder", opId, amount);
  };

  const handleBuyOperation = (opType: number) => {
    console.log("buy operation type", opType);
  };

  return (
    <Box minH="100dvh" bg="gray.900" color="white" p={[2, 4]}>
      <HStack mb={4} justify="space-between">
        <Heading size="md" color="yellow.400">
          OPERATIONS
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
        <OperationPanel
          operations={operations}
          loading={loading}
          onLaunder={handleLaunder}
          onBuyOperation={handleBuyOperation}
        />
      )}
    </Box>
  );
}
