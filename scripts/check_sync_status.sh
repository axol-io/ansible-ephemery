#!/bin/bash
# Script to check the sync status of Ethereum clients for Ephemery
# Usage: ./check_sync_status.sh

set -e

# Colors for prettier output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
LIGHTHOUSE_API="http://localhost:5052"
GETH_API="http://localhost:8545"
# EPHEMERY_DIR="/opt/ephemery"

echo -e "${BLUE}====== Ephemery Node Sync Status ======${NC}"
echo "Date: $(date)"
echo ""

# Function to check if curl is installed
check_curl() {
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl to use this script.${NC}"
    exit 1
  fi
}

# Function to format time duration
format_duration() {
  local seconds=$1
  local days=$((seconds/86400))
  local hours=$(((seconds%86400)/3600))
  local minutes=$(((seconds%3600)/60))
  local remaining_seconds=$((seconds%60))

  if [ $days -gt 0 ]; then
    echo "${days}d ${hours}h ${minutes}m ${remaining_seconds}s"
  elif [ $hours -gt 0 ]; then
    echo "${hours}h ${minutes}m ${remaining_seconds}s"
  elif [ $minutes -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${remaining_seconds}s"
  fi
}

# Check Docker containers
check_containers() {
  echo -e "${BLUE}Checking Docker containers...${NC}"

  # Check if the containers are running
  geth_running=$(docker ps --filter "name=ephemery-geth" --format "{{.Status}}" | grep -c "Up" || echo 0)
  lighthouse_running=$(docker ps --filter "name=ephemery-lighthouse" --format "{{.Status}}" | grep -c "Up" || echo 0)

  if [ "$geth_running" -gt 0 ]; then
    echo -e "Execution Client (Geth): ${GREEN}Running${NC}"
  else
    echo -e "Execution Client (Geth): ${RED}Not running${NC}"
  fi

  if [ "$lighthouse_running" -gt 0 ]; then
    echo -e "Consensus Client (Lighthouse): ${GREEN}Running${NC}"
  else
    echo -e "Consensus Client (Lighthouse): ${RED}Not running${NC}"
  fi

  echo ""
}

# Check Geth execution client status
check_geth() {
  echo -e "${BLUE}Checking Execution Client (Geth)...${NC}"

  # Get sync status from Geth
  geth_syncing=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' $GETH_API)

  if [[ "$geth_syncing" == *"\"result\":false"* ]]; then
    echo -e "Sync Status: ${GREEN}Synced${NC}"

    # Get current block
    current_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $GETH_API | grep -o '"result":"0x[^"]*' | sed 's/"result":"//g')
    current_block_dec=$(printf "%d\n" $current_block 2>/dev/null || echo 0)
    echo "Current Block: ${current_block_dec}"
  else
    # Parse JSON response
    if [[ "$geth_syncing" == *"currentBlock"* ]]; then
      current_block=$(echo $geth_syncing | grep -o '"currentBlock":"0x[^"]*' | sed 's/"currentBlock":"//g')
      highest_block=$(echo $geth_syncing | grep -o '"highestBlock":"0x[^"]*' | sed 's/"highestBlock":"//g')

      # Convert hex to decimal
      current_block_dec=$(printf "%d\n" $current_block 2>/dev/null || echo 0)
      highest_block_dec=$(printf "%d\n" $highest_block 2>/dev/null || echo 0)

      remaining_blocks=$((highest_block_dec - current_block_dec))
      percent_complete=$(echo "scale=2; $current_block_dec * 100 / $highest_block_dec" | bc 2>/dev/null || echo 0)

      echo -e "Sync Status: ${YELLOW}Syncing${NC}"
      echo "Current Block: ${current_block_dec}"
      echo "Highest Block: ${highest_block_dec}"
      echo "Remaining Blocks: ${remaining_blocks}"
      echo "Completion: ${percent_complete}%"
    else
      echo -e "Sync Status: ${RED}Unable to determine${NC}"
      echo "Raw response: $geth_syncing"
    fi
  fi

  # Get peer count
  peer_count=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' $GETH_API | grep -o '"result":"0x[^"]*' | sed 's/"result":"//g')
  peer_count_dec=$(printf "%d\n" $peer_count 2>/dev/null || echo 0)
  echo "Peers: ${peer_count_dec}"

  echo ""
}

# Check Lighthouse consensus client status
check_lighthouse() {
  echo -e "${BLUE}Checking Consensus Client (Lighthouse)...${NC}"

  # Get sync status
  sync_status=$(curl -s "${LIGHTHOUSE_API}/eth/v1/node/syncing")

  # Get peer count
  peer_count=$(curl -s "${LIGHTHOUSE_API}/eth/v1/node/peers" | grep -o '"data":\[[^]]*\]' | grep -o "id" | wc -l)

  if [[ "$sync_status" == *"is_syncing\":false"* ]]; then
    echo -e "Sync Status: ${GREEN}Synced${NC}"
    head_slot=$(echo $sync_status | grep -o '"head_slot":"\w*\"' | sed 's/"head_slot":"//g' | sed 's/"//g')
    echo "Head Slot: ${head_slot}"
  else
    head_slot=$(echo $sync_status | grep -o '"head_slot":"\w*\"' | sed 's/"head_slot":"//g' | sed 's/"//g')
    sync_distance=$(echo $sync_status | grep -o '"sync_distance":"\w*\"' | sed 's/"sync_distance":"//g' | sed 's/"//g')

    echo -e "Sync Status: ${YELLOW}Syncing${NC}"
    echo "Head Slot: ${head_slot}"
    echo "Sync Distance: ${sync_distance} slots"

    # Calculate estimated time to completion
    # Assuming 12 seconds per slot
    seconds_per_slot=12
    estimated_seconds=$((sync_distance * seconds_per_slot))
    estimated_time=$(format_duration $estimated_seconds)

    echo "Estimated Time to Sync: ${estimated_time}"
  fi

  echo "Peers: ${peer_count}"

  # Check if a checkpoint sync is working
  if [[ "$sync_status" == *"is_syncing\":true"* ]] && [ "$head_slot" -gt 0 ]; then
    echo -e "Checkpoint Sync: ${GREEN}Working${NC}"
  elif [[ "$sync_status" == *"is_syncing\":true"* ]] && [ "$head_slot" -eq 0 ]; then
    echo -e "Checkpoint Sync: ${RED}Not working - still at slot 0${NC}"
  fi

  echo ""
}

# Check if checkpoint sync is configured
check_checkpoint_sync_config() {
  echo -e "${BLUE}Checking Checkpoint Sync Configuration...${NC}"

  # Check lighthouse logs for checkpoint sync
  checkpoint_logs=$(docker logs --tail 200 ephemery-lighthouse 2>&1 | grep -i checkpoint)

  if [[ "$checkpoint_logs" == *"checkpoint sync"* ]] && [[ "$checkpoint_logs" != *"checkpoint sync disabled"* ]]; then
    echo -e "Checkpoint Sync: ${GREEN}Enabled${NC}"
    echo "Log entries related to checkpoint sync:"
    echo "$checkpoint_logs" | head -5
  else
    echo -e "Checkpoint Sync: ${RED}Not enabled or not working${NC}"
    echo "To enable checkpoint sync, run the fix_checkpoint_sync.yaml playbook."
  fi

  echo ""
}

# Main function
main() {
  check_curl
  check_containers
  check_geth
  check_lighthouse
  check_checkpoint_sync_config

  echo -e "${BLUE}====== Recommendations ======${NC}"

  # Check for low peer count in Lighthouse
  if [ "$peer_count" -lt 5 ]; then
    echo "- Low peer count detected. Consider adding more bootstrap nodes or checking network connectivity."
  fi

  # Check if checkpoint sync is working
  if [[ "$sync_status" == *"is_syncing\":true"* ]] && [ "$head_slot" -eq 0 ]; then
    echo "- Checkpoint sync appears not to be working. Try running the fix_checkpoint_sync.yaml playbook."
  fi

  # Check if Geth is syncing
  if [ "$current_block_dec" -eq 0 ] && [ "$highest_block_dec" -eq 0 ]; then
    echo "- Execution client (Geth) seems stalled. Check Engine API configuration between Geth and Lighthouse."
  fi

  echo -e "${BLUE}==============================${NC}"
}

# Run main function
main
