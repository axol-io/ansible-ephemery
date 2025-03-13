#!/bin/bash

# Ephemery Node Health Check Script
# This script performs health checks and performance monitoring for Ephemery nodes

# Source common configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/scripts/core/ephemery_config.sh" ]; then
  source "$SCRIPT_DIR/scripts/core/ephemery_config.sh"
else
  # Fallback to local definitions if common config not found
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_GETH_CONTAINER="ephemery-geth"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
fi

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
show_usage() {
    echo -e "${BLUE}Ephemery Node Health Check Script${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -b, --basic           Run basic health checks (default)"
    echo "  -f, --full            Run comprehensive health checks"
    echo "  -p, --performance     Run performance checks"
    echo "  -n, --network         Run network checks"
    echo "  --base-dir PATH       Specify a custom base directory (default: ~/ephemery)"
    echo "  -h, --help            Show this help message"
    echo ""
}

# Parse command line arguments
CHECK_TYPE="basic"

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--basic)
      CHECK_TYPE="basic"
      shift
      ;;
    -f|--full)
      CHECK_TYPE="full"
      shift
      ;;
    -p|--performance)
      CHECK_TYPE="performance"
      shift
      ;;
    -n|--network)
      CHECK_TYPE="network"
      shift
      ;;
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_usage
      exit 1
      ;;
  esac
done

echo -e "${BLUE}===== Ephemery Node Health Check =====${NC}"
echo -e "Running ${CHECK_TYPE} health check..."
echo ""

# Basic container status check
check_container_status() {
  local container_name=$1
  echo -e "${BLUE}Checking $container_name status...${NC}"

  if docker ps | grep -q $container_name; then
    echo -e "${GREEN}✓ $container_name is running${NC}"
    return 0
  else
    echo -e "${RED}✗ $container_name is not running${NC}"
    return 1
  fi
}

# Check container resource usage
check_container_resources() {
  local container_name=$1
  echo -e "${BLUE}Checking $container_name resource usage...${NC}"

  if docker ps | grep -q $container_name; then
    # Get CPU usage
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" $container_name)
    # Get memory usage
    local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" $container_name)
    # Get memory percentage
    local mem_perc=$(docker stats --no-stream --format "{{.MemPerc}}" $container_name)

    echo -e "CPU: $cpu_usage"
    echo -e "Memory: $mem_usage ($mem_perc)"

    # Check if memory usage is high (>85%)
    if [[ $mem_perc > 85% ]]; then
      echo -e "${RED}✗ High memory usage detected${NC}"
    else
      echo -e "${GREEN}✓ Memory usage within normal range${NC}"
    fi
  else
    echo -e "${RED}✗ Container not running, cannot check resources${NC}"
    return 1
  fi
}

# Check disk space
check_disk_space() {
  echo -e "${BLUE}Checking disk space...${NC}"

  # Get disk usage for Ephemery data directory
  local disk_usage=$(du -sh ${EPHEMERY_BASE_DIR} 2>/dev/null || echo "N/A")
  echo -e "Ephemery data directory size: $disk_usage"

  # Check available disk space
  local available_space=$(df -h ${EPHEMERY_BASE_DIR} | awk 'NR==2 {print $4}')
  local use_percentage=$(df -h ${EPHEMERY_BASE_DIR} | awk 'NR==2 {print $5}')
  echo -e "Available disk space: $available_space"
  echo -e "Disk usage: $use_percentage"

  # Check if disk usage is high (>85%)
  if [[ ${use_percentage%\%} -gt 85 ]]; then
    echo -e "${RED}✗ Disk usage is high (${use_percentage})${NC}"
    echo -e "${YELLOW}Consider pruning data or adding more storage${NC}"
  else
    echo -e "${GREEN}✓ Disk usage within normal range${NC}"
  fi
}

# Check Geth sync status
check_geth_sync_status() {
  echo -e "${BLUE}Checking Geth sync status...${NC}"

  local geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 2>/dev/null)

  if [ $? -eq 0 ]; then
    if echo "$geth_result" | grep -q '"result":false'; then
      echo -e "${GREEN}✓ Geth is fully synced${NC}"

      # Get latest block info
      local latest_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545)
      local block_hex=$(echo "$latest_block" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "$block_hex" ]; then
        local block_dec=$((16#${block_hex:2}))
        echo -e "Latest Block: $block_dec"
      fi
    else
      echo -e "${YELLOW}⟳ Geth is syncing${NC}"

      # Extract sync information
      local current_block=$(echo "$geth_result" | grep -o '"currentBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)
      local highest_block=$(echo "$geth_result" | grep -o '"highestBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)

      if [ ! -z "$current_block" ] && [ ! -z "$highest_block" ]; then
        local current_dec=$((16#${current_block:2}))
        local highest_dec=$((16#${highest_block:2}))
        local remaining=$((highest_dec - current_dec))
        local percent_complete=$(( (current_dec * 100) / highest_dec ))

        echo -e "Current Block: $current_dec"
        echo -e "Highest Block: $highest_dec"
        echo -e "Remaining Blocks: $remaining"
        echo -e "Sync Percentage: $percent_complete%"
      fi
    fi
  else
    echo -e "${RED}✗ Geth API is not responding${NC}"
  fi
}

# Check Lighthouse sync status
check_lighthouse_sync_status() {
  echo -e "${BLUE}Checking Lighthouse sync status...${NC}"

  local lighthouse_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json" 2>/dev/null)

  if [ $? -eq 0 ]; then
    if echo "$lighthouse_result" | grep -q '"is_syncing":false'; then
      echo -e "${GREEN}✓ Lighthouse is fully synced${NC}"
    else
      echo -e "${YELLOW}⟳ Lighthouse is syncing${NC}"

      # Extract sync information
      local head_slot=$(echo "$lighthouse_result" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
      local sync_distance=$(echo "$lighthouse_result" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)

      if [ ! -z "$head_slot" ] && [ ! -z "$sync_distance" ]; then
        local target_slot=$((head_slot + sync_distance))
        local percent_complete=0
        if [ $target_slot -gt 0 ]; then
          percent_complete=$(( (head_slot * 100) / target_slot ))
        fi

        echo -e "Current Slot: $head_slot"
        echo -e "Target Slot: $target_slot"
        echo -e "Remaining Distance: $sync_distance slots"
        echo -e "Sync Percentage: $percent_complete%"
      fi
    fi

    # Check if optimistic
    if echo "$lighthouse_result" | grep -q '"is_optimistic":true'; then
      echo -e "${YELLOW}⚠ Node is in optimistic mode (waiting for execution layer)${NC}"
    fi
  else
    echo -e "${RED}✗ Lighthouse API is not responding${NC}"
  fi
}

# Check validator status
check_validator_status() {
  echo -e "${BLUE}Checking validator status...${NC}"

  if docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    local validator_count=$(docker exec ${EPHEMERY_VALIDATOR_CONTAINER} ls -1 /validatordata/validators/*/voting-keystore.json 2>/dev/null | wc -l)

    if [ $? -eq 0 ] && [ $validator_count -gt 0 ]; then
      echo -e "${GREEN}✓ $validator_count validators configured${NC}"

      # Try to get active validators
      local validator_status=$(curl -s -X GET http://localhost:5052/eth/v1/beacon/states/head/validators 2>/dev/null)
      if [ $? -eq 0 ] && [ ! -z "$validator_status" ]; then
        local active_count=$(echo "$validator_status" | grep -o '"status":"active_ongoing"' | wc -l)
        local pending_count=$(echo "$validator_status" | grep -o '"status":"pending"' | wc -l)

        if [ $active_count -gt 0 ]; then
          echo -e "${GREEN}✓ $active_count validators active${NC}"
        fi
        if [ $pending_count -gt 0 ]; then
          echo -e "${YELLOW}⚠ $pending_count validators pending activation${NC}"
        fi
      fi
    else
      echo -e "${RED}✗ No validators configured or unable to access validator data${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Validator client not running${NC}"
  fi
}

# Check network connectivity
check_network_connectivity() {
  echo -e "${BLUE}Checking network connectivity...${NC}"

  # Check Geth peer count
  local peer_count=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545)
  local peer_hex=$(echo "$peer_count" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)

  if [ ! -z "$peer_hex" ]; then
    local peer_dec=$((16#${peer_hex:2}))
    echo -e "Geth connected peers: $peer_dec"

    if [ $peer_dec -lt 5 ]; then
      echo -e "${RED}✗ Low peer count for Geth (< 5)${NC}"
    else
      echo -e "${GREEN}✓ Geth peer count is good${NC}"
    fi
  else
    echo -e "${RED}✗ Unable to get Geth peer count${NC}"
  fi

  # Check Lighthouse peer count
  local lighthouse_peer_count=$(curl -s -X GET http://localhost:5052/eth/v1/node/peers_count -H "Content-Type: application/json" 2>/dev/null)
  local connected=$(echo "$lighthouse_peer_count" | grep -o '"connected":[0-9]*' | cut -d':' -f2)

  if [ ! -z "$connected" ]; then
    echo -e "Lighthouse connected peers: $connected"

    if [ $connected -lt 5 ]; then
      echo -e "${RED}✗ Low peer count for Lighthouse (< 5)${NC}"
    else
      echo -e "${GREEN}✓ Lighthouse peer count is good${NC}"
    fi
  else
    echo -e "${RED}✗ Unable to get Lighthouse peer count${NC}"
  fi
}

# Run performance checks
run_performance_checks() {
  echo -e "${BLUE}Running performance checks...${NC}"

  # Check Geth performance
  check_container_resources ${EPHEMERY_GETH_CONTAINER}

  # Check Lighthouse performance
  check_container_resources ${EPHEMERY_LIGHTHOUSE_CONTAINER}

  # Check if validator is running and its performance
  if docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    check_container_resources ${EPHEMERY_VALIDATOR_CONTAINER}
  fi

  # Check disk I/O
  echo -e "${BLUE}Checking disk I/O performance...${NC}"

  if which iostat > /dev/null 2>&1; then
    iostat -x | grep -v loop | grep -v ram
  else
    echo -e "${YELLOW}iostat not available, skipping detailed I/O statistics${NC}"

    echo -e "${BLUE}Basic disk performance:${NC}"
    # Simple disk performance check
    echo -e "Writing 100MB test file..."
    dd if=/dev/zero of=${EPHEMERY_BASE_DIR}/test_io.tmp bs=1M count=100 2>&1 | grep -v records
    echo -e "Reading 100MB test file..."
    dd if=${EPHEMERY_BASE_DIR}/test_io.tmp of=/dev/null bs=1M 2>&1 | grep -v records
    rm ${EPHEMERY_BASE_DIR}/test_io.tmp
  fi
}

# Run checks based on the selected type
case $CHECK_TYPE in
  basic)
    check_container_status ${EPHEMERY_GETH_CONTAINER}
    check_container_status ${EPHEMERY_LIGHTHOUSE_CONTAINER}
    check_container_status ${EPHEMERY_VALIDATOR_CONTAINER} || true
    check_disk_space
    check_geth_sync_status
    check_lighthouse_sync_status
    ;;
  full)
    check_container_status ${EPHEMERY_GETH_CONTAINER}
    check_container_status ${EPHEMERY_LIGHTHOUSE_CONTAINER}
    check_container_status ${EPHEMERY_VALIDATOR_CONTAINER} || true
    check_disk_space
    check_geth_sync_status
    check_lighthouse_sync_status
    check_validator_status
    check_network_connectivity
    run_performance_checks
    ;;
  performance)
    run_performance_checks
    ;;
  network)
    check_network_connectivity
    ;;
esac

echo ""
echo -e "${GREEN}===== Health Check Complete =====${NC}"
