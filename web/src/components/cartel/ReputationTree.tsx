import { Box, Grid, GridItem, Progress, Text, VStack } from "@chakra-ui/react";
import { BRANCH_NAMES, BranchName, CartelReputation } from "../../dojo/class/CartelReputation";

const BRANCH_UNLOCKS: Record<BranchName, Record<number, string>> = {
  Trader: {
    1: "Max drugs +1",
    2: "Max drugs +2",
    3: "Better buy prices",
    4: "Max drugs +3",
    5: "Trade master",
  },
  Enforcer: {
    1: "Crew bonus +5%",
    2: "Intimidation",
    3: "Crew bonus +10%",
    4: "Street protection",
    5: "Enforcer master",
  },
  Operator: {
    1: "Max slots +1",
    2: "Max slots +2",
    3: "Launder bonus",
    4: "Max slots +3",
    5: "Operator master",
  },
};

const BRANCH_COLORS: Record<BranchName, string> = {
  Trader: "yellow",
  Enforcer: "red",
  Operator: "cyan",
};

interface BranchColumnProps {
  branch: BranchName;
  reputation: CartelReputation;
}

function BranchColumn({ branch, reputation }: BranchColumnProps) {
  const level = reputation.getLevel(branch);
  const xp = reputation.getXp(branch);
  const progress = reputation.getProgress(branch);
  const nextThreshold = reputation.getNextThreshold(branch);
  const color = BRANCH_COLORS[branch];
  const unlock = level > 0 ? BRANCH_UNLOCKS[branch][level] : null;

  return (
    <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
      <VStack align="stretch" gap={2}>
        {/* Branch name */}
        <Text fontWeight="bold" fontSize="xs" textTransform="uppercase" letterSpacing="wider" color={`${color}.300`}>
          {branch}
        </Text>

        {/* Level */}
        <Text fontSize="2xl" fontWeight="bold" color="white" lineHeight={1}>
          Lv{level}
        </Text>

        {/* XP progress */}
        <VStack align="stretch" gap={1}>
          <Text fontSize="10px" color="gray.400">
            {xp.toLocaleString()} XP
            {nextThreshold !== Infinity ? ` / ${nextThreshold.toLocaleString()}` : " (MAX)"}
          </Text>
          <Progress value={progress * 100} size="xs" colorScheme={color} borderRadius="full" bg="gray.700" />
        </VStack>

        {/* Current unlock */}
        {unlock ? (
          <Box p={2} bg="gray.700" borderRadius="sm">
            <Text fontSize="10px" color="gray.300">
              {unlock}
            </Text>
          </Box>
        ) : (
          <Box p={2} bg="gray.700" borderRadius="sm">
            <Text fontSize="10px" color="gray.600">
              No unlocks yet
            </Text>
          </Box>
        )}
      </VStack>
    </Box>
  );
}

interface ReputationTreeProps {
  reputation: CartelReputation | null;
}

export function ReputationTree({ reputation }: ReputationTreeProps) {
  if (!reputation) {
    return (
      <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
        <Text fontSize="sm" color="gray.500">
          Reputation data unavailable.
        </Text>
      </Box>
    );
  }

  return (
    <VStack align="stretch" gap={3}>
      <Text fontWeight="bold" fontSize="sm" color="white" textTransform="uppercase" letterSpacing="wider">
        Reputation Tree
      </Text>
      <Grid templateColumns="repeat(3, 1fr)" gap={3}>
        {BRANCH_NAMES.map((branch) => (
          <GridItem key={branch}>
            <BranchColumn branch={branch} reputation={reputation} />
          </GridItem>
        ))}
      </Grid>
    </VStack>
  );
}
