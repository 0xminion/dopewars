import { Box, Grid, GridItem, Heading, HStack, Spinner, Text, VStack } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { ActionBar } from "../../../components/cartel/ActionBar";
import { HeatMeter } from "../../../components/cartel/HeatMeter";
import { InventoryPanel } from "../../../components/cartel/InventoryPanel";
import { LocationMap } from "../../../components/cartel/LocationMap";
import { MarketTable } from "../../../components/cartel/MarketTable";
import { MixingStation } from "../../../components/cartel/MixingStation";
import { useCartelGame } from "../../../dojo/hooks/useCartelGame";

export default function CartelGameView() {
  const router = useRouter();
  const { gameId } = router.query;

  const parsedGameId = gameId && !Array.isArray(gameId) ? parseInt(gameId, 16) || parseInt(gameId, 10) || null : null;

  const { player, inventory, wallet, heat, reputation, markets, loading } = useCartelGame(parsedGameId);

  const currentMarket = markets.find((m) => m.locationId === player?.state.location) ?? null;

  if (loading) {
    return (
      <Box minH="100dvh" display="flex" alignItems="center" justifyContent="center" bg="gray.900">
        <VStack gap={4}>
          <Spinner size="xl" color="yellow.400" />
          <Text color="gray.400">Loading game...</Text>
        </VStack>
      </Box>
    );
  }

  return (
    <Box minH="100dvh" bg="gray.900" color="white" p={[2, 4]}>
      <HStack mb={4} justify="space-between">
        <Heading size="md" color="yellow.400">
          CARTEL
        </Heading>
        <HStack gap={3}>
          {player && (
            <Text fontSize="sm" color="gray.400">
              Turn {player.state.turn}/{player.state.maxTurns} — {player.locationName}
            </Text>
          )}
        </HStack>
      </HStack>

      <Grid templateColumns={["1fr", "1fr", "1fr 1fr"]} templateRows="auto" gap={4}>
        {/* Left column: map + market */}
        <GridItem>
          <VStack gap={4} align="stretch">
            <LocationMap player={player} heat={heat} />
            <MarketTable market={currentMarket} />
          </VStack>
        </GridItem>

        {/* Right column: action bar + inventory + heat + mixing */}
        <GridItem>
          <VStack gap={4} align="stretch">
            <ActionBar player={player} wallet={wallet} />
            <HeatMeter heat={heat} />
            <InventoryPanel inventory={inventory} />
            <MixingStation inventory={inventory} />
          </VStack>
        </GridItem>
      </Grid>
    </Box>
  );
}
