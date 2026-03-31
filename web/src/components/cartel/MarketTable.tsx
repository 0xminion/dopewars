import { Box, Table, Tbody, Td, Text, Th, Thead, Tr, VStack } from "@chakra-ui/react";
import { CartelMarket } from "../../dojo/class/CartelMarket";

interface MarketTableProps {
  market: CartelMarket | null;
}

export function MarketTable({ market }: MarketTableProps) {
  if (!market || !market.isVisible) {
    return (
      <VStack align="stretch" gap={2} p={3} borderWidth="1px" borderRadius="md">
        <Text fontWeight="bold" fontSize="sm">
          MARKET
        </Text>
        <Text fontSize="sm" color="gray.500">
          Market not visible — travel here to reveal prices.
        </Text>
      </VStack>
    );
  }

  return (
    <VStack align="stretch" gap={2} p={3} borderWidth="1px" borderRadius="md">
      <Text fontWeight="bold" fontSize="sm">
        MARKET
      </Text>
      <Box overflowX="auto">
        <Table size="sm" variant="simple">
          <Thead>
            <Tr>
              <Th color="gray.400" fontSize="10px">
                DRUG
              </Th>
              <Th color="gray.400" fontSize="10px" isNumeric>
                PRICE
              </Th>
              <Th color="gray.400" fontSize="10px" isNumeric>
                SUPPLY
              </Th>
            </Tr>
          </Thead>
          <Tbody>
            {market.drugs.map((drug) => (
              <Tr key={drug.drugId}>
                <Td fontSize="xs">{drug.name}</Td>
                <Td fontSize="xs" isNumeric color="yellow.300">
                  ${drug.price.toLocaleString()}
                </Td>
                <Td fontSize="xs" isNumeric color={drug.supply < 10 ? "red.400" : "green.300"}>
                  {drug.supply}
                </Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      </Box>
    </VStack>
  );
}
