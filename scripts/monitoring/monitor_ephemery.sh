#!/bin/bash

# Ephemery Node Monitoring Script
# This script provides a convenient way to monitor Ephemery nodes
# Version: 1.2.0

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
CORE_DIR="${SCRIPT_DIR}/../core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  log_error "Path configuration not found at ${CORE_DIR}/path_config.sh"
  log_error "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
else
  log_error "Error handling script not found at ${CORE_DIR}/error_handling.sh"
  log_error "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
else
  log_error "Common utilities script not found at ${CORE_DIR}/common.sh"
  log_error "Please ensure the core scripts are properly installed."
  exit 1
fi

# Version information for dependencies
TMUX_VERSION="3.3"
JQ_VERSION="1.6"

# Default settings
EPHEMERY_BASE_DIR=~/ephemery
MONITOR_MODE="combined"

# Function to display usage information
show_usage() {
  log_info "Ephemery Node Monitoring Script"
  log_info ""
  log_info "Usage: $0 [options]"
  log_info ""
  log_info "Options:"
  log_info "  -g, --geth         Monitor Geth logs only"
  log_info "  -l, --lighthouse   Monitor Lighthouse logs only"
  log_info "  -v, --validator    Monitor validator logs only"
  log_info "  -c, --combined     Monitor all logs in split view (default, requires tmux)"
  log_info "  -s, --status       Show current node status"
  log_info "  -y, --sync         Show detailed sync status"
  log_info "  --base-dir PATH    Specify a custom base directory (default: ${EPHEMERY_BASE_DIR})"
  log_info "  -h, --help         Show this help message"
  log_info ""
  log_info "Examples:"
  log_info "  $0                  # Default: Combined view"
  log_info "  $0 --geth           # Monitor Geth logs only"
  log_info "  $0 --lighthouse     # Monitor Lighthouse logs only"
  log_info "  $0 --validator      # Monitor validator logs only"
  log_info "  $0 --status         # Show current status"
  log_info "  $0 --sync           # Show detailed sync status"
}

# Check dependencies
check_dependencies() {
  local missing_deps=false

  if [[ "${MONITOR_MODE}" == "combined" ]]; then
    if ! command -v tmux &>/dev/null; then
      log_error "tmux is not installed and is required for combined mode. Please install tmux v${TMUX_VERSION} or later."
      missing_deps=true
    else
      local tmux_version
      tmux_version=$(tmux -V | sed -n 's/tmux \([0-9]*\.[0-9]*\).*/\1/p')
      if ! version_greater_equal "${tmux_version}" "${TMUX_VERSION}"; then
        log_warn "tmux version ${tmux_version} is older than recommended version ${TMUX_VERSION}"
      else
        log_success "tmux version ${tmux_version} is installed (✓)"
      fi
    fi
  fi

  if ! command -v jq &>/dev/null; then
    log_warn "jq is not installed. Status checks will have limited formatting."
  else
    local jq_version
    jq_version=$(jq --version | sed -n 's/jq-\([0-9]*\.[0-9]*\).*/\1/p')
    if ! version_greater_equal "${jq_version}" "${JQ_VERSION}"; then
      log_warn "jq version ${jq_version} is older than recommended version ${JQ_VERSION}"
    else
      log_success "jq version ${jq_version} is installed (✓)"
    fi
  fi

  if [ "${missing_deps}" = true ]; then
    log_error "Missing required dependencies. Please install them and try again."
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
  log_info "Monitoring Validator logs. Press Ctrl+C to exit."
  if docker ps | grep -q ephemery-validator; then
    docker logs -f ephemery-validator
  else
    log_error "Validator container (ephemery-validator) is not running."
    exit 1
  fi
}

# Function to monitor both logs using tmux
monitor_combined() {
  if ! command -v tmux &>/dev/null; then
    log_error "tmux is not installed. Please install tmux or use -g, -l, or -v options instead."
    exit 1
  fi

  log_info "Starting combined monitoring using tmux. Press Ctrl+B then D to detach."

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
    tmux send-keys -t ephemery_monitor:0.0 "log_info 'Geth Logs'; docker logs -f ephemery-geth" C-m

    # Run Lighthouse logs in the top right pane
    tmux send-keys -t ephemery_monitor:0.1 "log_info 'Lighthouse Logs'; docker logs -f ephemery-lighthouse" C-m

    # Run Validator logs in the bottom right pane
    tmux send-keys -t ephemery_monitor:0.2 "log_info 'Validator Logs'; docker logs -f ephemery-validator" C-m
  else
    # Split for two panes
    tmux split-window -h -t ephemery_monitor

    # Run Geth logs in the left pane
    tmux send-keys -t ephemery_monitor:0.0 "log_info 'Geth Logs'; docker logs -f ephemery-geth" C-m

    # Run Lighthouse logs in the right pane
    tmux send-keys -t ephemery_monitor:0.1 "log_info 'Lighthouse Logs'; docker logs -f ephemery-lighthouse" C-m
  fi

  # Attach to the session
  tmux attach-session -t ephemery_monitor
}

# Function to show current status
show_status() {
  log_info "===== Ephemery Node Status ====="
  log_info ""

  # Check if containers are running
  log_info "Container Status:"
  docker ps --format "{{.Names}} - {{.Status}}" | grep ephemery || log_error "No Ephemery containers running"
  log_info ""

  # Check checkpoint sync status
  if [ -f "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" ]; then
    CHECKPOINT_URL=$(cat "${EPHEMERY_BASE_DIR}"/checkpoint_url.txt)
    log_info "Checkpoint Sync: Enabled (${CHECKPOINT_URL})"
  else
    log_warn "Checkpoint Sync: Disabled (using genesis sync)"
  fi
  log_info ""

  # Check Geth API
  log_info "Geth API Status:"
  geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 2>/dev/null)
  if [ $? -eq 0 ]; then
    if echo "${geth_result}" | grep -q '"result":false'; then
      log_success "Geth is fully synced"
    else
      log_warn "Geth is syncing:"
      log_info "$(echo "${geth_result}" | sed 's/.*currentBlock":"\(0x[0-9a-f]*\).*/Current Block: \1/')"
    fi
  else
    log_error "Geth API is not responding"
  fi
  log_info ""

  # Check Lighthouse API
  log_info "Lighthouse API Status:"
  lighthouse_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json" 2>/dev/null)
  if [ $? -eq 0 ]; then
    if echo "${lighthouse_result}" | grep -q '"is_syncing":false'; then
      log_success "Lighthouse is fully synced"
    else
      log_warn "Lighthouse is syncing:"
      head_slot=$(echo "${lighthouse_result}" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
      sync_distance=$(echo "${lighthouse_result}" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)
      log_info "Head Slot: ${head_slot}, Sync Distance: ${sync_distance}"
    fi

    # Check if optimistic
    if echo "${lighthouse_result}" | grep -q '"is_optimistic":true'; then
      log_warn "Node is in optimistic mode (waiting for execution layer)"
    fi
  else
    log_error "Lighthouse API is not responding"
  fi
  log_info ""

  # Check validator status if it exists
  if docker ps | grep -q ephemery-validator; then
    log_info "Validator Status:"
    validator_count=$(docker exec ephemery-validator ls -1 /validatordata/validators/*/voting-keystore.json 2>/dev/null | wc -l)
    if [ $? -eq 0 ] && [ "${validator_count}" -gt 0 ]; then
      log_success "${validator_count} validators configured"

      # Try to get active validators
      validator_status=$(curl -s -X GET http://localhost:5052/eth/v1/beacon/states/head/validators?status=active 2>/dev/null)
      if [ $? -eq 0 ] && [ ! -z "${validator_status}" ]; then
        active_count=$(echo "${validator_status}" | grep -o '"status":"active_ongoing"' | wc -l)
        pending_count=$(echo "${validator_status}" | grep -o '"status":"pending"' | wc -l)
        if [ "${active_count}" -gt 0 ]; then
          log_success "${active_count} validators active"
        fi
        if [ "${pending_count}" -gt 0 ]; then
          log_warn "${pending_count} validators pending activation"
        fi
      fi
    else
      log_error "No validators configured or unable to access validator data"
    fi
  else
    log_warn "Validator client not running"
  fi
  log_info ""

  # Get container stats
  log_info "Container Resource Usage:"
  docker stats --no-stream $(docker ps -q -f name=ephemery)
}

# Function to show detailed sync status
show_sync_status() {
  log_info "===== Ephemery Sync Status ====="
  log_info ""

  # Check if checkpoint sync is enabled
  if [ -f "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" ]; then
    CHECKPOINT_URL=$(cat "${EPHEMERY_BASE_DIR}"/checkpoint_url.txt)
    log_info "Checkpoint Sync: Enabled"
    log_info "URL: ${CHECKPOINT_URL}"

    # Test if URL is still accessible
    if curl --connect-timeout 5 --max-time 10 -s "${CHECKPOINT_URL}" >/dev/null; then
      log_success "URL Status: Accessible"
    else
      log_error "URL Status: Not Accessible (may impact sync)"
    fi
  else
    log_warn "Checkpoint Sync: Disabled (using genesis sync)"
  fi
  log_info ""

  # Get detailed Geth sync status
  log_info "Execution Layer (Geth) Sync Status:"
  geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)

  if [ $? -eq 0 ]; then
    if echo "${geth_result}" | grep -q '"result":false'; then
      log_success "✓ Fully Synced"

      # Get latest block info
      latest_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545)
      block_hex=$(echo "${latest_block}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "${block_hex}" ]; then
        block_dec=$((16#${block_hex:2}))
        log_info "Latest Block: ${block_dec}"
      fi

      # Get peer count
      peer_count=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545)
      peer_hex=$(echo "${peer_count}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "${peer_hex}" ]; then
        peer_dec=$((16#${peer_hex:2}))
        log_info "Connected Peers: ${peer_dec}"
      fi
    else
      log_warn "⟳ Syncing"

      # Extract and convert hex values to decimal
      current_block_hex=$(echo "${geth_result}" | grep -o '"currentBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)
      highest_block_hex=$(echo "${geth_result}" | grep -o '"highestBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)

      if [ ! -z "${current_block_hex}" ] && [ ! -z "${highest_block_hex}" ]; then
        current_block=$((16#${current_block_hex:2}))
        highest_block=$((16#${highest_block_hex:2}))
        remaining=$((highest_block - current_block))
        percent=$(((current_block * 100) / (highest_block > 0 ? highest_block : 1)))

        log_info "Current Block: ${current_block}"
        log_info "Highest Block: ${highest_block}"
        log_info "Remaining: ${remaining} blocks"
        log_info "Progress: ${percent}%"
      else
        log_info "${geth_result}"
      fi
    fi
  else
    log_error "✗ API not responding"
  fi
  log_info ""

  # Get detailed Lighthouse sync status
  log_info "Consensus Layer (Lighthouse) Sync Status:"
  lighthouse_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json")

  if [ $? -eq 0 ]; then
    is_syncing=$(echo "${lighthouse_result}" | grep -o '"is_syncing":[a-z]*' | cut -d':' -f2)
    is_optimistic=$(echo "${lighthouse_result}" | grep -o '"is_optimistic":[a-z]*' | cut -d':' -f2)

    if [ "${is_syncing}" == "false" ]; then
      log_success "✓ Fully Synced"
    else
      log_warn "⟳ Syncing"

      head_slot=$(echo "${lighthouse_result}" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
      sync_distance=$(echo "${lighthouse_result}" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)

      if [ ! -z "${head_slot}" ] && [ ! -z "${sync_distance}" ]; then
        target_slot=$((head_slot + sync_distance))
        percent=$(((head_slot * 100) / (target_slot > 0 ? target_slot : 1)))

        log_info "Current Head Slot: ${head_slot}"
        log_info "Sync Distance: ${sync_distance} slots"
        log_info "Target Slot: ${target_slot}"
        log_info "Progress: ${percent}%"
      else
        log_info "${lighthouse_result}"
      fi
    fi

    if [ "${is_optimistic}" == "true" ]; then
      log_warn "Node is in optimistic mode (waiting for execution layer)"
    fi

    # Get additional details using the beacon node API
    peers_result=$(curl -s -X GET http://localhost:5052/eth/v1/node/peers -H "Content-Type: application/json")
    if [ $? -eq 0 ]; then
      peer_count=$(echo "${peers_result}" | grep -o '"meta"' | wc -l)
      log_info "Connected Peers: ${peer_count}"
    fi
  else
    log_error "✗ API not responding"
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g | --geth)
      MONITOR_MODE="geth"
      shift
      ;;
    -l | --lighthouse)
      MONITOR_MODE="lighthouse"
      shift
      ;;
    -v | --validator)
      MONITOR_MODE="validator"
      shift
      ;;
    -c | --combined)
      MONITOR_MODE="combined"
      shift
      ;;
    -s | --status)
      MONITOR_MODE="status"
      shift
      ;;
    -y | --sync)
      MONITOR_MODE="sync"
      shift
      ;;
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    -h | --help)
      show_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
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
    log_error "Invalid monitoring mode: ${MONITOR_MODE}"
    show_usage
    exit 1
    ;;
esac
