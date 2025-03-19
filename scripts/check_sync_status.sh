#!/bin/bash
# check_sync_status.sh - Monitor Ephemery node sync progress
# This script checks both execution and consensus client sync status
# Version: 1.0.0

# Don't exit on errors to ensure the script completes even with API issues
set +e

# Default container names (can be overridden by environment variables)
LIGHTHOUSE_CONTAINER=${LIGHTHOUSE_CONTAINER:-ephemery-lighthouse}
GETH_CONTAINER=${GETH_CONTAINER:-ephemery-geth}

# API endpoints
LIGHTHOUSE_API="http://localhost:5052"
GETH_API="http://localhost:8545"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}===== Ephemery Node Sync Status =====${NC}"
echo -e "${CYAN}$(date)${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

# Check container status
echo -e "${BLUE}Container Status:${NC}"
if docker ps | grep -q "${GETH_CONTAINER}"; then
  echo -e "${GREEN}✓ Execution client (${GETH_CONTAINER}) is running${NC}"
  GETH_RUNNING=true
else
  echo -e "${RED}✗ Execution client (${GETH_CONTAINER}) is not running${NC}"
  GETH_RUNNING=false
fi

if docker ps | grep -q "${LIGHTHOUSE_CONTAINER}"; then
  echo -e "${GREEN}✓ Consensus client (${LIGHTHOUSE_CONTAINER}) is running${NC}"
  LIGHTHOUSE_RUNNING=true
else
  echo -e "${RED}✗ Consensus client (${LIGHTHOUSE_CONTAINER}) is not running${NC}"
  LIGHTHOUSE_RUNNING=false
fi
echo ""

# Check execution client sync status
if [ "$GETH_RUNNING" = true ]; then
  echo -e "${BLUE}Execution Client Sync Status:${NC}"
  GETH_SYNC=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' $GETH_API)

  if [[ "$GETH_SYNC" == *"false"* ]]; then
    echo -e "${GREEN}Execution client is fully synced${NC}"

    # Get latest block
    LATEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $GETH_API)
    BLOCK_HEX=$(echo "$LATEST_BLOCK" | grep -o '"result":"0x[^"]*' | cut -d'"' -f3 || echo "")
    if [ -n "$BLOCK_HEX" ]; then
      BLOCK_DEC=$(printf "%d" "$BLOCK_HEX" 2>/dev/null || echo "0")
      echo -e "Current block: ${BLOCK_DEC}"
    else
      echo -e "${YELLOW}Could not determine current block number${NC}"
    fi
  else
    CURRENT_BLOCK=$(echo "$GETH_SYNC" | grep -o '"currentBlock":"0x[^"]*' | cut -d'"' -f3 || echo "")
    HIGHEST_BLOCK=$(echo "$GETH_SYNC" | grep -o '"highestBlock":"0x[^"]*' | cut -d'"' -f3 || echo "")

    if [ -n "$CURRENT_BLOCK" ] && [ -n "$HIGHEST_BLOCK" ]; then
      CURRENT_DEC=$(printf "%d" "$CURRENT_BLOCK" 2>/dev/null || echo "0")
      HIGHEST_DEC=$(printf "%d" "$HIGHEST_BLOCK" 2>/dev/null || echo "0")

      if [ "$HIGHEST_DEC" -gt 0 ] && [ "$CURRENT_DEC" -ge 0 ]; then
        REMAINING=$((HIGHEST_DEC - CURRENT_DEC))
        PROGRESS=$(awk "BEGIN {printf \"%.2f\", ($CURRENT_DEC * 100 / $HIGHEST_DEC)}" 2>/dev/null || echo "calculating...")

        echo -e "${YELLOW}Execution client is syncing${NC}"
        echo -e "Current block: ${CURRENT_DEC}"
        echo -e "Target block: ${HIGHEST_DEC}"
        echo -e "Remaining blocks: ${REMAINING}"
        echo -e "Progress: ${PROGRESS}%"
      else
        echo -e "${YELLOW}Execution client is syncing${NC}"
        echo -e "Current block: ${CURRENT_DEC}"
        echo -e "Target block: ${HIGHEST_DEC}"
      fi
    else
      echo -e "${YELLOW}Execution client is syncing, but detailed progress information is not available${NC}"
    fi
  fi
  echo ""
fi

# Check consensus client sync status
if [ "$LIGHTHOUSE_RUNNING" = true ]; then
  echo -e "${BLUE}Consensus Client Sync Status:${NC}"
  LIGHTHOUSE_SYNC=$(curl -s $LIGHTHOUSE_API/eth/v1/node/syncing)

  if [[ "$LIGHTHOUSE_SYNC" == *'"is_syncing":false'* ]]; then
    echo -e "${GREEN}Consensus client is fully synced${NC}"
    HEAD_SLOT=$(echo "$LIGHTHOUSE_SYNC" | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
    echo -e "Current slot: ${HEAD_SLOT}"
  else
    HEAD_SLOT=$(echo "$LIGHTHOUSE_SYNC" | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
    SYNC_DISTANCE=$(echo "$LIGHTHOUSE_SYNC" | grep -o '"sync_distance":"[0-9]*"' | grep -o '[0-9]*' || echo "0")

    if [ -n "$HEAD_SLOT" ] && [ -n "$SYNC_DISTANCE" ]; then
      TARGET_SLOT=$((HEAD_SLOT + SYNC_DISTANCE))

      if [ "$TARGET_SLOT" -gt 0 ]; then
        PROGRESS=$(awk "BEGIN {printf \"%.2f\", ($HEAD_SLOT * 100 / $TARGET_SLOT)}" 2>/dev/null || echo "calculating...")
        echo -e "${YELLOW}Consensus client is syncing${NC}"
        echo -e "Current slot: ${HEAD_SLOT}"
        echo -e "Sync distance: ${SYNC_DISTANCE}"
        echo -e "Target slot: ${TARGET_SLOT}"
        echo -e "Progress: ${PROGRESS}%"
      else
        echo -e "${YELLOW}Consensus client is syncing${NC}"
        echo -e "Current slot: ${HEAD_SLOT}"
        echo -e "Sync distance: ${SYNC_DISTANCE}"
        echo -e "Target slot: ${TARGET_SLOT}"
      fi
    else
      echo -e "${YELLOW}Consensus client is syncing, but detailed progress information is not available${NC}"
    fi
  fi
  echo ""
fi

# Get peer counts for both clients
if [ "$GETH_RUNNING" = true ]; then
  echo -e "${BLUE}Execution Client Peer Count:${NC}"
  GETH_PEERS=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' $GETH_API)
  PEERS_HEX=$(echo "$GETH_PEERS" | grep -o '"result":"0x[^"]*' | cut -d'"' -f3 || echo "")

  if [ -n "$PEERS_HEX" ]; then
    PEERS_DEC=$(printf "%d" "$PEERS_HEX" 2>/dev/null || echo "0")
    echo -e "Connected peers: ${PEERS_DEC}"
  else
    echo -e "${YELLOW}Could not determine peer count${NC}"
  fi
  echo ""
fi

if [ "$LIGHTHOUSE_RUNNING" = true ]; then
  echo -e "${BLUE}Consensus Client Peer Count:${NC}"
  LIGHTHOUSE_PEERS=$(curl -s $LIGHTHOUSE_API/eth/v1/node/peer_count)
  CONNECTED=$(echo "$LIGHTHOUSE_PEERS" | grep -o '"connected":"[0-9]*"' | grep -o '[0-9]*' || echo "0")

  if [ -n "$CONNECTED" ]; then
    echo -e "Connected peers: ${CONNECTED}"
  else
    echo -e "${YELLOW}Could not determine peer count${NC}"
  fi
  echo ""
fi

# Check for errors in logs
echo -e "${BLUE}Recent Error Log Check:${NC}"

if [ "$GETH_RUNNING" = true ]; then
  echo -e "${CYAN}Execution client recent errors:${NC}"
  GETH_ERRORS=$(docker logs --tail 50 "$GETH_CONTAINER" 2>&1 | grep -i "error\|fatal\|critical" | tail -3)
  if [ -z "$GETH_ERRORS" ]; then
    echo -e "${GREEN}No recent errors found in execution client logs${NC}"
  else
    echo -e "${RED}Recent errors in execution client logs:${NC}"
    echo "$GETH_ERRORS"
  fi
  echo ""
fi

if [ "$LIGHTHOUSE_RUNNING" = true ]; then
  echo -e "${CYAN}Consensus client recent errors:${NC}"
  LIGHTHOUSE_ERRORS=$(docker logs --tail 50 "$LIGHTHOUSE_CONTAINER" 2>&1 | grep -i "error\|fatal\|critical" | tail -3)
  if [ -z "$LIGHTHOUSE_ERRORS" ]; then
    echo -e "${GREEN}No recent errors found in consensus client logs${NC}"
  else
    echo -e "${RED}Recent errors in consensus client logs:${NC}"
    echo "$LIGHTHOUSE_ERRORS"

    # Add explanation for common errors
    if [[ "$LIGHTHOUSE_ERRORS" == *"deposit contract cache"* ]]; then
      echo -e "${YELLOW}Note: 'Error updating deposit contract cache' is normal during initial sync${NC}"
      echo -e "${YELLOW}This will resolve once the execution client has synced further${NC}"
    fi
  fi
  echo ""
fi

echo -e "${CYAN}===== End of Status Report =====${NC}"
