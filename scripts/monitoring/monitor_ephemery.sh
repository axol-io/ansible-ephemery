#!/bin/bash

# Ephemery Node Monitoring Script
# This script provides a convenient way to monitor Ephemery nodes
# Version: 1.2.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Error: Path configuration not found at ${CORE_DIR}/path_config.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
else
  echo "Error: Error handling script not found at ${CORE_DIR}/error_handling.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
else
  echo "Error: Common utilities script not found at ${CORE_DIR}/common.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Declare version information for dependencies
declare -A VERSIONS=(
  [TMUX]="3.3"
  [JQ]="1.6"
)

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
EPHEMERY_BASE_DIR=~/ephemery
MONITOR_MODE="combined"

# Function to display usage information
show_usage() {
    log_info "Ephemery Node Monitoring Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -g, --geth         Monitor Geth logs only"
    echo "  -l, --lighthouse   Monitor Lighthouse logs only"
    echo "  -v, --validator    Monitor validator logs only"
    echo "  -c, --combined     Monitor all logs in split view (default, requires tmux)"
    echo "  -s, --status       Show current node status"
    echo "  -y, --sync         Show detailed sync status"
    echo "  --base-dir PATH    Specify a custom base directory (default: ${EPHEMERY_BASE_DIR})"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Default: Combined view"
    echo "  $0 --geth           # Monitor Geth logs only"
    echo "  $0 --lighthouse     # Monitor Lighthouse logs only"
    echo "  $0 --validator      # Monitor validator logs only"
    echo "  $0 --status         # Show current status"
    echo "  $0 --sync           # Show detailed sync status"
}

# Check dependencies
check_dependencies() {
  local missing_deps=false
  
  if [[ "${MONITOR_MODE}" == "combined" ]]; then
    if ! command -v tmux &> /dev/null; then
      log_error "tmux is not installed and is required for combined mode. Please install tmux v${VERSIONS[TMUX]} or later."
      missing_deps=true
    else
      local tmux_version
      tmux_version=$(tmux -V | sed -n 's/tmux \([0-9]*\.[0-9]*\).*/\1/p')
      if ! version_greater_equal "${tmux_version}" "${VERSIONS[TMUX]}"; then
        log_warning "tmux version ${tmux_version} is older than recommended version ${VERSIONS[TMUX]}"
      else
        log_success "tmux version ${tmux_version} is installed (✓)"
      fi
    fi
  fi
  
  if ! command -v jq &> /dev/null; then
    log_warning "jq is not installed. Status checks will have limited formatting."
  else
    local jq_version
    jq_version=$(jq --version | sed -n 's/jq-\([0-9]*\.[0-9]*\).*/\1/p')
    if ! version_greater_equal "${jq_version}" "${VERSIONS[JQ]}"; then
      log_warning "jq version ${jq_version} is older than recommended version ${VERSIONS[JQ]}"
    else
      log_success "jq version ${jq_version} is installed (✓)"
    fi
  fi
  
  if [ "${missing_deps}" = true ]; then
    log_fatal "Missing required dependencies. Please install them and try again."
    exit 1
  fi
}

# Helper function to compare versions
version_greater_equal() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Function to monitor Geth logs
monitor_geth() {
    log_info "Monitoring Geth logs. Press Ctrl+C to exit."
    docker logs -f ephemery-geth
}

# Function to monitor Lighthouse logs
monitor_lighthouse() {
    log_info "Monitoring Lighthouse logs. Press Ctrl+C to exit."
    docker logs -f ephemery-lighthouse
}

# Function to monitor Validator logs
monitor_validator() {
    echo -e "${BLUE}Monitoring Validator logs. Press Ctrl+C to exit.${NC}"
    if docker ps | grep -q ephemery-validator; then
        docker logs -f ephemery-validator
    else
        echo -e "${RED}Error: Validator container (ephemery-validator) is not running.${NC}"
        exit 1
    fi
}

# Function to monitor both logs using tmux
monitor_combined() {
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}Error: tmux is not installed. Please install tmux or use -g, -l, or -v options instead.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Starting combined monitoring using tmux. Press Ctrl+B then D to detach.${NC}"

    # Create a new tmux session
    tmux new-session -d -s ephemery_monitor

    # Check if validator is running
    VALIDATOR_RUNNING=false
    if docker ps | grep -q ephemery-validator; then
        VALIDATOR_RUNNING=true
    fi

    if [ "${VALIDATOR_RUNNING}" = true ]; then
        # Split for three panes
        tmux split-window -h -t ephemery_monitor
        tmux split-window -v -t ephemery_monitor:0.1

        # Run Geth logs in the left pane
        tmux send-keys -t ephemery_monitor:0.0 "echo -e '${GREEN}Geth Logs${NC}'; docker logs -f ephemery-geth" C-m

        # Run Lighthouse logs in the top right pane
        tmux send-keys -t ephemery_monitor:0.1 "echo -e '${GREEN}Lighthouse Logs${NC}'; docker logs -f ephemery-lighthouse" C-m

        # Run Validator logs in the bottom right pane
        tmux send-keys -t ephemery_monitor:0.2 "echo -e '${GREEN}Validator Logs${NC}'; docker logs -f ephemery-validator" C-m
    else
        # Split for two panes
        tmux split-window -h -t ephemery_monitor

        # Run Geth logs in the left pane
        tmux send-keys -t ephemery_monitor:0.0 "echo -e '${GREEN}Geth Logs${NC}'; docker logs -f ephemery-geth" C-m

        # Run Lighthouse logs in the right pane
        tmux send-keys -t ephemery_monitor:0.1 "echo -e '${GREEN}Lighthouse Logs${NC}'; docker logs -f ephemery-lighthouse" C-m
    fi

    # Attach to the session
    tmux attach-session -t ephemery_monitor
}

# Function to show current status
show_status() {
    echo -e "${BLUE}===== Ephemery Node Status =====${NC}"
    echo ""

    # Check if containers are running
    echo -e "${BLUE}Container Status:${NC}"
    docker ps --format "{{.Names}} - {{.Status}}" | grep ephemery || echo -e "${RED}No Ephemery containers running${NC}"
    echo ""

    # Check checkpoint sync status
    if [ -f "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" ]; then
        CHECKPOINT_URL=$(cat "${EPHEMERY_BASE_DIR}"/checkpoint_url.txt)
        echo -e "${BLUE}Checkpoint Sync:${NC} ${GREEN}Enabled${NC} (${CHECKPOINT_URL})"
    else
        echo -e "${BLUE}Checkpoint Sync:${NC} ${YELLOW}Disabled${NC} (using genesis sync)"
    fi
    echo ""

    # Check Geth API
    echo -e "${BLUE}Geth API Status:${NC}"
    geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 2>/dev/null)
    if [ $? -eq 0 ]; then
        if echo "${geth_result}" | grep -q '"result":false'; then
            echo -e "${GREEN}Geth is fully synced${NC}"
        else
            echo -e "${YELLOW}Geth is syncing:${NC}"
            echo "${geth_result}" | sed 's/.*currentBlock":"\(0x[0-9a-f]*\).*/Current Block: \1/'
        fi
    else
        echo -e "${RED}Geth API is not responding${NC}"
    fi
    echo ""

    # Check Lighthouse API
    echo -e "${BLUE}Lighthouse API Status:${NC}"
    lighthouse_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json" 2>/dev/null)
    if [ $? -eq 0 ]; then
        if echo "${lighthouse_result}" | grep -q '"is_syncing":false'; then
            echo -e "${GREEN}Lighthouse is fully synced${NC}"
        else
            echo -e "${YELLOW}Lighthouse is syncing:${NC}"
            head_slot=$(echo "${lighthouse_result}" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
            sync_distance=$(echo "${lighthouse_result}" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)
            echo "Head Slot: ${head_slot}, Sync Distance: ${sync_distance}"
        fi

        # Check if optimistic
        if echo "${lighthouse_result}" | grep -q '"is_optimistic":true'; then
            echo -e "${YELLOW}Node is in optimistic mode (waiting for execution layer)${NC}"
        fi
    else
        echo -e "${RED}Lighthouse API is not responding${NC}"
    fi
    echo ""

    # Check validator status if it exists
    if docker ps | grep -q ephemery-validator; then
        echo -e "${BLUE}Validator Status:${NC}"
        validator_count=$(docker exec ephemery-validator ls -1 /validatordata/validators/*/voting-keystore.json 2>/dev/null | wc -l)
        if [ $? -eq 0 ] && [ "${validator_count}" -gt 0 ]; then
            echo -e "${GREEN}${validator_count} validators configured${NC}"

            # Try to get active validators
            validator_status=$(curl -s -X GET http://localhost:5052/eth/v1/beacon/states/head/validators?status=active 2>/dev/null)
            if [ $? -eq 0 ] && [ ! -z "${validator_status}" ]; then
                active_count=$(echo "${validator_status}" | grep -o '"status":"active_ongoing"' | wc -l)
                pending_count=$(echo "${validator_status}" | grep -o '"status":"pending"' | wc -l)
                if [ "${active_count}" -gt 0 ]; then
                    echo -e "${GREEN}${active_count} validators active${NC}"
                fi
                if [ "${pending_count}" -gt 0 ]; then
                    echo -e "${YELLOW}${pending_count} validators pending activation${NC}"
                fi
            fi
        else
            echo -e "${RED}No validators configured or unable to access validator data${NC}"
        fi
    else
        echo -e "${YELLOW}Validator client not running${NC}"
    fi
    echo ""

    # Get container stats
    echo -e "${BLUE}Container Resource Usage:${NC}"
    docker stats --no-stream $(docker ps -q -f name=ephemery)
}

# Function to show detailed sync status
show_sync_status() {
    echo -e "${BLUE}===== Ephemery Sync Status =====${NC}"
    echo ""

    # Check if checkpoint sync is enabled
    if [ -f "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" ]; then
        CHECKPOINT_URL=$(cat "${EPHEMERY_BASE_DIR}"/checkpoint_url.txt)
        echo -e "${BLUE}Checkpoint Sync:${NC} ${GREEN}Enabled${NC}"
        echo -e "URL: ${CHECKPOINT_URL}"

        # Test if URL is still accessible
        if curl --connect-timeout 5 --max-time 10 -s "${CHECKPOINT_URL}" > /dev/null; then
            echo -e "URL Status: ${GREEN}Accessible${NC}"
        else
            echo -e "URL Status: ${RED}Not Accessible${NC} (may impact sync)"
        fi
    else
        echo -e "${BLUE}Checkpoint Sync:${NC} ${YELLOW}Disabled${NC} (using genesis sync)"
    fi
    echo ""

    # Get detailed Geth sync status
    echo -e "${BLUE}Execution Layer (Geth) Sync Status:${NC}"
    geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)

    if [ $? -eq 0 ]; then
        if echo "${geth_result}" | grep -q '"result":false'; then
            echo -e "${GREEN}✓ Fully Synced${NC}"

            # Get latest block info
            latest_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545)
            block_hex=$(echo "${latest_block}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
            if [ ! -z "${block_hex}" ]; then
                block_dec=$((16#${block_hex:2}))
                echo -e "Latest Block: ${block_dec}"
            fi

            # Get peer count
            peer_count=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545)
            peer_hex=$(echo "${peer_count}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
            if [ ! -z "${peer_hex}" ]; then
                peer_dec=$((16#${peer_hex:2}))
                echo -e "Connected Peers: ${peer_dec}"
            fi
        else
            echo -e "${YELLOW}⟳ Syncing${NC}"

            # Extract and convert hex values to decimal
            current_block_hex=$(echo "${geth_result}" | grep -o '"currentBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)
            highest_block_hex=$(echo "${geth_result}" | grep -o '"highestBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)

            if [ ! -z "${current_block_hex}" ] && [ ! -z "${highest_block_hex}" ]; then
                current_block=$((16#${current_block_hex:2}))
                highest_block=$((16#${highest_block_hex:2}))
                remaining=$((highest_block - current_block))
                percent=$(( (current_block * 100) / (highest_block > 0 ? highest_block : 1) ))

                echo -e "Current Block: ${current_block}"
                echo -e "Highest Block: ${highest_block}"
                echo -e "Remaining: ${remaining} blocks"
                echo -e "Progress: ${percent}%"
            else
                echo "${geth_result}"
            fi
        fi
    else
        echo -e "${RED}✗ API not responding${NC}"
    fi
    echo ""

    # Get detailed Lighthouse sync status
    echo -e "${BLUE}Consensus Layer (Lighthouse) Sync Status:${NC}"
    lighthouse_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json")

    if [ $? -eq 0 ]; then
        is_syncing=$(echo "${lighthouse_result}" | grep -o '"is_syncing":[a-z]*' | cut -d':' -f2)
        is_optimistic=$(echo "${lighthouse_result}" | grep -o '"is_optimistic":[a-z]*' | cut -d':' -f2)

        if [ "${is_syncing}" == "false" ]; then
            echo -e "${GREEN}✓ Fully Synced${NC}"
        else
            echo -e "${YELLOW}⟳ Syncing${NC}"

            head_slot=$(echo "${lighthouse_result}" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
            sync_distance=$(echo "${lighthouse_result}" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)

            if [ ! -z "${head_slot}" ] && [ ! -z "${sync_distance}" ]; then
                target_slot=$((head_slot + sync_distance))
                percent=$(( (head_slot * 100) / (target_slot > 0 ? target_slot : 1) ))

                echo -e "Current Head Slot: ${head_slot}"
                echo -e "Sync Distance: ${sync_distance} slots"
                echo -e "Target Slot: ${target_slot}"
                echo -e "Progress: ${percent}%"
            else
                echo "${lighthouse_result}"
            fi
        fi

        if [ "${is_optimistic}" == "true" ]; then
            echo -e "${YELLOW}Node is in optimistic mode (waiting for execution layer)${NC}"
        fi

        # Get additional details using the beacon node API
        peers_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/peers -H "Content-Type: application/json")
        if [ $? -eq 0 ]; then
            peer_count=$(echo "${peers_result}" | grep -o '"meta"' | wc -l)
            echo -e "Connected Peers: ${peer_count}"
        fi
    else
        echo -e "${RED}✗ API not responding${NC}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--geth)
            MONITOR_MODE="geth"
            shift
            ;;
        -l|--lighthouse)
            MONITOR_MODE="lighthouse"
            shift
            ;;
        -v|--validator)
            MONITOR_MODE="validator"
            shift
            ;;
        -c|--combined)
            MONITOR_MODE="combined"
            shift
            ;;
        -s|--status)
            MONITOR_MODE="status"
            shift
            ;;
        -y|--sync)
            MONITOR_MODE="sync"
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

# Execute the selected monitoring mode
case "${MONITOR_MODE}" in
    "geth")
        monitor_geth
        ;;
    "lighthouse")
        monitor_lighthouse
        ;;
    "validator")
        monitor_validator
        ;;
    "combined")
        monitor_combined
        ;;
    "status")
        show_status
        ;;
    "sync")
        show_sync_status
        ;;
    *)
        echo -e "${RED}Invalid monitoring mode: ${MONITOR_MODE}${NC}"
        show_usage
        exit 1
        ;;
esac
