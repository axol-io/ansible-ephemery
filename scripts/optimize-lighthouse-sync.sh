#!/bin/bash
# Optimized Lighthouse Sync for Ephemery
# This script configures and restarts Lighthouse with optimal sync settings

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Ephemery Lighthouse Sync Optimization${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check Docker status
echo -e "${YELLOW}Checking Docker status...${NC}"
if docker info &>/dev/null; then
  echo -e "${GREEN}✓ Docker is running${NC}"
else
  echo -e "${RED}✗ Docker is not running or you don't have permissions${NC}"
  echo -e "${YELLOW}Try running this script with sudo${NC}"
  exit 1
fi

# Confirm with user before proceeding
echo -e "${YELLOW}This script will stop your current Lighthouse container and start a new one with optimized settings.${NC}"
echo -e "${YELLOW}Your existing data can be kept or cleared.${NC}"
read -p "Do you want to proceed? (y/n): " proceed
if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
  echo -e "${RED}Operation cancelled.${NC}"
  exit 0
fi

# Ask if user wants to clear existing data
read -p "Clear existing Lighthouse database for fresh sync? (recommended for fastest sync) (y/n): " clear_db
if [[ "$clear_db" == "y" || "$clear_db" == "Y" ]]; then
  echo -e "${YELLOW}Will clear Lighthouse database for fresh sync${NC}"
  CLEAR_DB=true
else
  echo -e "${YELLOW}Using existing Lighthouse database${NC}"
  CLEAR_DB=false
fi

# Check if checkpoint sync or genesis sync should be used
read -p "Use checkpoint sync? (recommended, but if it fails, use genesis sync) (y/n): " use_checkpoint
if [[ "$use_checkpoint" == "y" || "$use_checkpoint" == "Y" ]]; then
  echo -e "${YELLOW}Will use checkpoint sync${NC}"
  USE_CHECKPOINT=true
else
  echo -e "${YELLOW}Will use genesis sync${NC}"
  USE_CHECKPOINT=false
fi

# Apply network optimizations
echo -e "${YELLOW}Applying network optimizations...${NC}"
# Increase socket buffer sizes
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.core.rmem_default=1048576
sudo sysctl -w net.core.wmem_default=1048576
sudo sysctl -w net.ipv4.tcp_rmem="4096 1048576 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 1048576 16777216"

# Increase connection tracking table size
sudo sysctl -w net.netfilter.nf_conntrack_max=1000000 2>/dev/null || true

# Optimize TCP settings
sudo sysctl -w net.ipv4.tcp_fastopen=3
sudo sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sudo sysctl -w net.ipv4.tcp_no_metrics_save=1

echo -e "${GREEN}✓ Network optimizations applied${NC}"

# Stop and remove the existing Lighthouse container
echo -e "${YELLOW}Stopping existing Lighthouse container...${NC}"
docker stop ephemery-lighthouse 2>/dev/null || true
docker rm ephemery-lighthouse 2>/dev/null || true
echo -e "${GREEN}✓ Old container removed${NC}"

# Clear database if requested
if [ "$CLEAR_DB" = true ]; then
  echo -e "${YELLOW}Clearing Lighthouse database...${NC}"
  sudo rm -rf /opt/ephemery/ephemery/data/lighthouse/* 2>/dev/null || true
  echo -e "${GREEN}✓ Database cleared${NC}"
fi

# Define bootstrap nodes with proper UDP format
BOOTSTRAP_NODES="/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ,/ip4/136.243.15.66/tcp/9000/udp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG,/ip4/88.198.2.150/tcp/9000/udp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3,/ip4/135.181.91.151/tcp/9000/udp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b,/ip4/95.217.131.28/tcp/9000/udp/9000/p2p/16Uiu2HAm4ijy2FE8SntNeBTFqKqLxKVWUqZ2QHPz4m8tQcJNvvBc,/ip4/159.69.65.98/tcp/9000/udp/9000/p2p/16Uiu2HAmTACwFnTRoTWZRen4whDMMgcR7QAQoJKBrsBLNJqJiEkD,/ip4/95.217.99.173/tcp/9000/udp/9000/p2p/16Uiu2HAkvq1xTJR2fNy4wY2bZ4xtCGZrLx7Zc9VpBLmAXmVeYYBD"

# Construct the Lighthouse command
LIGHTHOUSE_CMD="lighthouse beacon_node --datadir=/data --execution-jwt=/jwt.hex --execution-endpoint=http://127.0.0.1:8551 --http --http-address=0.0.0.0 --http-port=5052 --metrics --metrics-address=0.0.0.0 --metrics-port=5054 --testnet-dir=/ephemery_config --target-peers=150 --execution-timeout-multiplier=10 --disable-deposit-contract-sync --import-all-attestations --disable-backfill-rate-limiting --boot-nodes=$BOOTSTRAP_NODES"

# Add checkpoint sync if enabled, otherwise use genesis sync
if [ "$USE_CHECKPOINT" = true ]; then
  LIGHTHOUSE_CMD="$LIGHTHOUSE_CMD --checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io"
else
  LIGHTHOUSE_CMD="$LIGHTHOUSE_CMD --allow-insecure-genesis-sync"
fi

# Start the new Lighthouse container with optimized settings
echo -e "${YELLOW}Starting new Lighthouse container with optimized settings...${NC}"

docker run -d --name ephemery-lighthouse --restart=unless-stopped --network=host \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/ephemery/data/lighthouse:/data \
  -v /opt/ephemery/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 $LIGHTHOUSE_CMD

echo -e "${GREEN}✓ New Lighthouse container started with optimized settings${NC}"

# Wait a bit for container to start
sleep 5

# Check if container is running
if docker ps -f name=ephemery-lighthouse | grep -q ephemery-lighthouse; then
  echo -e "${GREEN}✓ Lighthouse container is running${NC}"
else
  echo -e "${RED}✗ Lighthouse container failed to start. Check logs with:${NC}"
  echo -e "${YELLOW}  docker logs ephemery-lighthouse${NC}"
  exit 1
fi

# Create a script to monitor sync status
echo -e "${YELLOW}Creating sync status monitoring script...${NC}"
cat > /opt/ephemery/scripts/monitor-sync.sh << 'EOF'
#!/bin/bash
# Monitoring script for Lighthouse sync progress

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

while true; do
  clear
  echo -e "${BLUE}==========================================${NC}"
  echo -e "${BLUE}Ephemery Lighthouse Sync Monitor${NC}"
  echo -e "${BLUE}==========================================${NC}"

  # Check if curl and jq are available
  if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "${RED}curl and jq are required. Please install them.${NC}"
    exit 1
  fi

  # Get sync status
  SYNC_STATUS=$(curl -s http://localhost:5052/eth/v1/node/syncing)

  if [ -z "$SYNC_STATUS" ]; then
    echo -e "${RED}Could not get sync status. Is the API accessible?${NC}"
  else
    # Parse JSON with error handling
    IS_SYNCING=$(echo "$SYNC_STATUS" | jq -r '.data.is_syncing' 2>/dev/null || echo "unknown")
    HEAD_SLOT=$(echo "$SYNC_STATUS" | jq -r '.data.head_slot' 2>/dev/null || echo "unknown")
    SYNC_DISTANCE=$(echo "$SYNC_STATUS" | jq -r '.data.sync_distance' 2>/dev/null || echo "unknown")

    echo -e "${YELLOW}Sync Status:${NC}"
    echo -e "  Is Syncing: ${IS_SYNCING}"
    echo -e "  Head Slot: ${HEAD_SLOT}"
    echo -e "  Sync Distance: ${SYNC_DISTANCE}"
  fi

  # Get peer count
  PEER_COUNT=$(curl -s http://localhost:5052/eth/v1/node/peer_count)
  if [ -n "$PEER_COUNT" ]; then
    CONNECTED=$(echo "$PEER_COUNT" | jq -r '.data.connected' 2>/dev/null || echo "unknown")

    echo -e "${YELLOW}Peer Count:${NC}"
    echo -e "  Connected Peers: ${CONNECTED}"

    if [ "$CONNECTED" != "unknown" ]; then
      if [ "$CONNECTED" -lt 10 ]; then
        echo -e "${RED}Warning: Low peer count. This may slow down your sync.${NC}"
      else
        echo -e "${GREEN}Good peer count. Sync should proceed normally.${NC}"
      fi
    fi
  fi

  # Show recent logs
  echo -e "${YELLOW}Recent Logs:${NC}"
  docker logs --tail 5 ephemery-lighthouse 2>/dev/null || echo "Cannot retrieve logs"

  echo -e "\n${BLUE}Press Ctrl+C to exit${NC}"
  sleep 10
done
EOF

chmod +x /opt/ephemery/scripts/monitor-sync.sh

# Finalize and provide instructions
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}Lighthouse has been configured with optimized settings!${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}To monitor sync progress, run:${NC}"
echo -e "  /opt/ephemery/scripts/monitor-sync.sh"
echo -e "\n${YELLOW}To check sync status once:${NC}"
echo -e "  curl -s http://localhost:5052/eth/v1/node/syncing | jq"
echo -e "\n${YELLOW}To check peer count:${NC}"
echo -e "  curl -s http://localhost:5052/eth/v1/node/peer_count | jq"
echo -e "\n${YELLOW}If sync is still too slow, try:${NC}"
echo -e "  1. Increasing your server's resources (RAM/CPU)"
echo -e "  2. Clearing the database again with another run of this script"
echo -e "  3. Running with 'genesis sync' instead of 'checkpoint sync'"
echo -e "  4. Check firewall settings to ensure P2P ports are open"
