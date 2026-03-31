import { Box, Button, Heading, HStack, Input, Progress, Select, Spinner, Text, VStack } from "@chakra-ui/react";
import { useState } from "react";
import { CartelOperation, OP_TYPE_NAMES } from "../../dojo/class/CartelOperation";

interface OperationPanelProps {
  operations: CartelOperation[];
  loading: boolean;
  onLaunder: (opId: number, amount: number) => void;
  onBuyOperation: (opType: number) => void;
}

function OperationCard({
  operation,
  onLaunder,
}: {
  operation: CartelOperation;
  onLaunder: (opId: number, amount: number) => void;
}) {
  const [amount, setAmount] = useState<string>("");

  const { opId, capacityPerTurn, processingAmount, processingTurnsLeft } = operation.state;
  const progressPct = operation.isProcessing ? Math.max(0, Math.min(100, (1 - processingTurnsLeft / 5) * 100)) : 0;

  const handleLaunder = () => {
    const parsed = parseInt(amount, 10);
    if (parsed > 0) {
      onLaunder(opId, parsed);
      setAmount("");
    }
  };

  return (
    <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
      <VStack align="stretch" gap={2}>
        {/* Header */}
        <HStack justify="space-between">
          <Text fontWeight="bold" fontSize="sm" color="white">
            {operation.typeName}
          </Text>
          <Text fontSize="xs" color="gray.400">
            Cap: {capacityPerTurn.toLocaleString()} / turn
          </Text>
        </HStack>

        {/* Processing status */}
        {operation.isProcessing ? (
          <VStack align="stretch" gap={1}>
            <HStack justify="space-between">
              <Text fontSize="xs" color="blue.300">
                Processing ${processingAmount.toLocaleString()}
              </Text>
              <Text fontSize="xs" color="gray.400">
                {processingTurnsLeft} turn{processingTurnsLeft !== 1 ? "s" : ""} left
              </Text>
            </HStack>
            <Progress value={progressPct} size="xs" colorScheme="blue" borderRadius="full" />
          </VStack>
        ) : (
          <Text fontSize="xs" color="green.400">
            Ready
          </Text>
        )}

        {/* Launder input */}
        <HStack gap={2}>
          <Input
            size="xs"
            placeholder="Amount to launder"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            bg="gray.700"
            borderColor="gray.600"
            color="white"
            type="number"
            min={0}
            flex={1}
            isDisabled={operation.isProcessing}
          />
          <Button
            size="xs"
            colorScheme="cyan"
            onClick={handleLaunder}
            isDisabled={operation.isProcessing || !amount || parseInt(amount, 10) <= 0}
          >
            Start Laundering
          </Button>
        </HStack>

        {/* Stats */}
        <Text fontSize="10px" color="gray.500">
          Total laundered: ${operation.state.totalLaundered.toLocaleString()}
        </Text>
      </VStack>
    </Box>
  );
}

export function OperationPanel({ operations, loading, onLaunder, onBuyOperation }: OperationPanelProps) {
  const [buyType, setBuyType] = useState<number>(1);

  if (loading) {
    return (
      <Box p={4} display="flex" alignItems="center" justifyContent="center">
        <Spinner color="yellow.400" />
      </Box>
    );
  }

  return (
    <VStack align="stretch" gap={4}>
      {/* Buy operation section */}
      <Box p={3} borderWidth="1px" borderRadius="md" borderColor="gray.600" bg="gray.800">
        <Text fontWeight="bold" fontSize="sm" color="white" mb={2}>
          BUY OPERATION
        </Text>
        <HStack gap={2}>
          <Select
            size="sm"
            value={buyType}
            bg="gray.700"
            borderColor="gray.600"
            color="white"
            onChange={(e) => setBuyType(Number(e.target.value))}
            flex={1}
          >
            {Object.entries(OP_TYPE_NAMES).map(([key, name]) => (
              <option key={key} value={key}>
                {name}
              </option>
            ))}
          </Select>
          <Button size="sm" colorScheme="green" onClick={() => onBuyOperation(buyType)}>
            Buy
          </Button>
        </HStack>
      </Box>

      {/* Operations list */}
      <Heading size="xs" color="gray.400" textTransform="uppercase" letterSpacing="wider">
        Operations ({operations.length})
      </Heading>

      {operations.length === 0 ? (
        <Box p={4} borderWidth="1px" borderRadius="md" borderColor="gray.700" bg="gray.800">
          <Text fontSize="sm" color="gray.500" textAlign="center">
            No operations owned yet.
          </Text>
        </Box>
      ) : (
        operations.map((op) => <OperationCard key={op.state.opId} operation={op} onLaunder={onLaunder} />)
      )}
    </VStack>
  );
}
