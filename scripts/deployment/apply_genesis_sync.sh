#!/bin/bash
# apply_genesis_sync.sh - Apply genesis sync to local Ephemery node
# This script will reset the Lighthouse client to use genesis sync

set -e

# Default values
EPHEMERY_DIR=${EPHEMERY_DIR:-/opt/ephemery}
LIGHTHOUSE_CONTAINER=${LIGHTHOUSE_CONTAINER:-ephemery-lighthouse}
GETH_CONTAINER=${GETH_CONTAINER:-ephemery-geth}
DATA_DIR="${EPHEMERY_DIR}/data"
CL_DATA_DIR="${DATA_DIR}/lighthouse"
JWT_FILE="${EPHEMERY_DIR}/jwt.hex"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Ephemery Genesis Sync Conversion Script =====${NC}"
echo -e "${BLUE}This script will reset your Lighthouse client to use genesis sync${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

# Check if Lighthouse container exists
if ! docker ps -a | grep -q ${LIGHTHOUSE_CONTAINER}; then
  echo -e "${RED}Lighthouse container ${LIGHTHOUSE_CONTAINER} not found.${NC}"
  echo -e "${YELLOW}If your container has a different name, use: LIGHTHOUSE_CONTAINER=your-container-name $0${NC}"
  exit 1
fi

# Check if Geth container exists
if ! docker ps -a | grep -q ${GETH_CONTAINER}; then
  echo -e "${YELLOW}Warning: Geth container ${GETH_CONTAINER} not found. The script will continue, but may not work correctly.${NC}"
  echo -e "${YELLOW}If your container has a different name, use: GETH_CONTAINER=your-container-name $0${NC}"
fi

echo -e "${BLUE}Step 1: Stopping Lighthouse container...${NC}"
docker stop ${LIGHTHOUSE_CONTAINER} || true

echo -e "${BLUE}Step 2: Clearing Lighthouse database...${NC}"
if [ -d "${CL_DATA_DIR}" ]; then
  echo -e "${YELLOW}Backing up Lighthouse data to ${CL_DATA_DIR}.bak${NC}"
  mv "${CL_DATA_DIR}" "${CL_DATA_DIR}.bak"
fi
mkdir -p "${CL_DATA_DIR}"

echo -e "${BLUE}Step 3: Preparing optimized genesis sync parameters...${NC}"
# Lighthouse command with genesis sync optimizations
LIGHTHOUSE_CMD="lighthouse beacon_node \
  --datadir=/data \
  --execution-jwt=/jwt.hex \
  --execution-endpoint=http://127.0.0.1:8551 \
  --http \
  --http-address=0.0.0.0 \
  --http-port=5052 \
  --metrics \
  --metrics-address=0.0.0.0 \
  --metrics-port=5054 \
  --testnet-dir=/ephemery_config \
  --target-peers=100 \
  --execution-timeout-multiplier=5 \
  --allow-insecure-genesis-sync \
  --genesis-backfill \
  --disable-backfill-rate-limiting"

echo -e "${BLUE}Step 4: Starting Lighthouse with genesis sync...${NC}"
docker run -d --name ${LIGHTHOUSE_CONTAINER} \
  --network host \
  -v ${CL_DATA_DIR}:/data \
  -v ${JWT_FILE}:/jwt.hex \
  -v ${EPHEMERY_DIR}/config/ephemery_network:/ephemery_config:ro \
  pk910/ephemery-lighthouse:latest \
  ${LIGHTHOUSE_CMD}

echo -e "${GREEN}Lighthouse container started with genesis sync!${NC}"
echo -e "${YELLOW}Note: The initial sync may take several hours.${NC}"
echo ""
echo -e "${BLUE}Monitoring sync status... (press Ctrl+C to exit)${NC}"
echo ""

# Monitor sync status
while true; do
  sleep 10
  SYNC_STATUS=$(curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Waiting for Lighthouse API to become available...${NC}"
    continue
  fi

  IS_SYNCING=$(echo $SYNC_STATUS | grep -o '"is_syncing":true' || echo "false")
  HEAD_SLOT=$(echo $SYNC_STATUS | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*')
  SYNC_DISTANCE=$(echo $SYNC_STATUS | grep -o '"sync_distance":"[0-9]*"' | grep -o '[0-9]*')

  if [ -n "$HEAD_SLOT" ] && [ -n "$SYNC_DISTANCE" ]; then
    echo -e "${GREEN}Current sync status:${NC}"
    echo -e "  Head slot: ${HEAD_SLOT}"
    echo -e "  Sync distance: ${SYNC_DISTANCE}"

    # Check if we're making progress
    if [ "$IS_SYNCING" = "false" ]; then
      echo -e "${GREEN}Node is synced!${NC}"
      break
    fi
  else
    echo -e "${YELLOW}Could not parse sync status. Will retry...${NC}"
  fi
done

echo -e "${GREEN}Genesis sync has been successfully configured and started!${NC}"
exit 0
