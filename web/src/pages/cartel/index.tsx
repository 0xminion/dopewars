import { Box, Button, Heading, Input, Select, Text, VStack } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { useState } from "react";
import { useCartelSystems } from "../../dojo/hooks/useCartelSystems";

const GAME_MODES = [
  { value: 0, label: "Casual" },
  { value: 1, label: "Ranked" },
];

export default function CartelLobby() {
  const router = useRouter();
  const { createGame } = useCartelSystems();

  const [playerName, setPlayerName] = useState("");
  const [gameMode, setGameMode] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleStartGame = async () => {
    if (!playerName.trim()) {
      setError("Player name is required");
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const result = await createGame(gameMode, playerName.trim());
      if (result.hash && result.hash !== "0x0") {
        // Navigate to a game view — hash used as placeholder gameId until Torii resolves
        router.push(`/cartel/${result.hash}`);
      } else {
        setError("Transaction failed. Please try again.");
      }
    } catch (e: any) {
      setError(e?.message ?? "An unknown error occurred");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Box minH="100dvh" display="flex" alignItems="center" justifyContent="center" bg="gray.900" p={4}>
      <Box w="full" maxW="400px">
        <VStack gap={6} align="stretch">
          <Heading size="lg" color="yellow.400" textAlign="center">
            CARTEL
          </Heading>
          <Text color="gray.400" textAlign="center" fontSize="sm">
            Build your empire. Control the streets.
          </Text>

          <VStack gap={4} align="stretch">
            <Box>
              <Text fontSize="sm" color="gray.300" mb={1}>
                Player Name
              </Text>
              <Input
                value={playerName}
                onChange={(e) => setPlayerName(e.target.value)}
                placeholder="Enter your name"
                bg="gray.800"
                borderColor="gray.600"
                color="white"
                _placeholder={{ color: "gray.500" }}
                maxLength={31}
              />
            </Box>

            <Box>
              <Text fontSize="sm" color="gray.300" mb={1}>
                Game Mode
              </Text>
              <Select
                value={gameMode}
                onChange={(e) => setGameMode(Number(e.target.value))}
                bg="gray.800"
                borderColor="gray.600"
                color="white"
              >
                {GAME_MODES.map((mode) => (
                  <option key={mode.value} value={mode.value}>
                    {mode.label}
                  </option>
                ))}
              </Select>
            </Box>

            {error && (
              <Text color="red.400" fontSize="sm">
                {error}
              </Text>
            )}

            <Button
              colorScheme="yellow"
              size="lg"
              onClick={handleStartGame}
              isLoading={isLoading}
              loadingText="Starting..."
              isDisabled={!playerName.trim()}
            >
              Start Game
            </Button>
          </VStack>
        </VStack>
      </Box>
    </Box>
  );
}
