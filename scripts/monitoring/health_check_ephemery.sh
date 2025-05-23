#!/bin/bash

# Ephemery Node Health Check Script
# This script performs health checks and performance monitoring for Ephemery nodes
# Version: 1.1.0

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
  log_warn "Path configuration not found. Using legacy path definitions."
  # Fallback to local definitions if common config not found
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_GETH_CONTAINER="ephemery-geth"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
  # Allow the script to continue on errors for health checks
  ERROR_CONTINUE_ON_ERROR=true
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
fi

# Default settings
CHECK_MODE="basic"
CUSTOM_BASE_DIR=""

# Function to display usage information
show_usage() {
  log_info "Ephemery Node Health Check Script"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -b, --basic           Run basic health checks (default)"
  echo "  -f, --full            Run comprehensive health checks"
  echo "  -p, --performance     Run performance checks"
  echo "  -n, --network         Run network checks"
  echo "  --base-dir PATH       Specify a custom base directory (default: ${EPHEMERY_BASE_DIR})"
  echo "  -h, --help            Show this help message"
  echo ""
}

# Parse command line arguments
CHECK_TYPE="basic"

while [[ $# -gt 0 ]]; do
  case $1 in
    -b | --basic)
      CHECK_TYPE="basic"
      shift
      ;;
    -f | --full)
      CHECK_TYPE="full"
      shift
      ;;
    -p | --performance)
      CHECK_TYPE="performance"
      shift
      ;;
    -n | --network)
      CHECK_TYPE="network"
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
      if type handle_error &>/dev/null; then
        handle_error "ERROR" "Unknown option: $1" "${EXIT_CODES[INVALID_ARGUMENT]}"
      else
        log_error "Unknown option: $1"
        show_usage
        exit 1
      fi
      ;;
  esac
done

log_info "===== Ephemery Node Health Check ====="
log_info "Running ${CHECK_TYPE} health check..."
echo ""

# Basic container status check
check_container_status() {
  local container_name=$1

  if type log_info &>/dev/null; then
    log_info "Checking ${container_name} status..."
  else
    log_info "Checking ${container_name} status..."
  fi

  if type is_container_running &>/dev/null; then
    if is_container_running "${container_name}"; then
      if type log_success &>/dev/null; then
        log_success "${container_name} is running"
      else
        log_success "${container_name} is running"
      fi
      return 0
    else
      if type log_error &>/dev/null; then
        log_error "${container_name} is not running"
      else
        log_error "${container_name} is not running"
      fi
      return 1
    fi
  else
    # Fallback if common.sh is not available
    if docker ps | grep -q "${container_name}"; then
      log_success "${container_name} is running"
      return 0
    else
      log_error "${container_name} is not running"
      return 1
    fi
  fi
}

# Check container resource usage
check_container_resources() {
  local container_name=$1

  if type log_info &>/dev/null; then
    log_info "Checking ${container_name} resource usage..."
  else
    log_info "Checking ${container_name} resource usage..."
  fi

  if type is_container_running &>/dev/null; then
    if is_container_running "${container_name}"; then
      # Get resource statistics
      if type run_with_error_handling &>/dev/null; then
        local cpu_usage=$(run_with_error_handling "Get CPU usage" docker stats --no-stream --format "{{.CPUPerc}}" "${container_name}")
        local mem_usage=$(run_with_error_handling "Get memory usage" docker stats --no-stream --format "{{.MemUsage}}" "${container_name}")
        local mem_perc=$(run_with_error_handling "Get memory percentage" docker stats --no-stream --format "{{.MemPerc}}" "${container_name}")
      else
        local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "${container_name}")
        local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "${container_name}")
        local mem_perc=$(docker stats --no-stream --format "{{.MemPerc}}" "${container_name}")
      fi

      echo -e "CPU: ${cpu_usage}"
      echo -e "Memory: ${mem_usage} (${mem_perc})"

      # Check if memory usage is high (>85%)
      if [[ ${mem_perc} > 85% ]]; then
        if type log_error &>/dev/null; then
          log_error "High memory usage detected"
        else
          log_error "High memory usage detected"
        fi
      else
        if type log_success &>/dev/null; then
          log_success "Memory usage within normal range"
        else
          log_success "Memory usage within normal range"
        fi
      fi
    else
      if type log_error &>/dev/null; then
        log_error "Container not running, cannot check resources"
      else
        log_error "Container not running, cannot check resources"
      fi
      return 1
    fi
  else
    # Fallback if common.sh is not available
    if docker ps | grep -q "${container_name}"; then
      # Get resource statistics
      local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "${container_name}")
      local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "${container_name}")
      local mem_perc=$(docker stats --no-stream --format "{{.MemPerc}}" "${container_name}")

      echo -e "CPU: ${cpu_usage}"
      echo -e "Memory: ${mem_usage} (${mem_perc})"

      # Check if memory usage is high (>85%)
      if [[ ${mem_perc} > 85% ]]; then
        log_error "High memory usage detected"
      else
        log_success "Memory usage within normal range"
      fi
    else
      log_error "Container not running, cannot check resources"
      return 1
    fi
  fi
}

# Check disk space
check_disk_space() {
  if type log_info &>/dev/null; then
    log_info "Checking disk space..."
  else
    log_info "Checking disk space..."
  fi

  # Use standardized path if available
  local data_dir="${EPHEMERY_DATA_DIR:-${EPHEMERY_BASE_DIR}/data}"

  # Get disk usage for Ephemery data directory
  if type run_with_error_handling &>/dev/null; then
    local disk_usage=$(run_with_error_handling "Get disk usage" du -sh "${data_dir}" 2>/dev/null || echo "N/A")
  else
    local disk_usage=$(du -sh "${data_dir}" 2>/dev/null || echo "N/A")
  fi

  echo -e "Ephemery data directory size: ${disk_usage}"

  # Check available disk space
  if type run_with_error_handling &>/dev/null; then
    local available_space=$(run_with_error_handling "Get available space" df -h "${data_dir}" | awk 'NR==2 {print $4}')
    local use_percentage=$(run_with_error_handling "Get usage percentage" df -h "${data_dir}" | awk 'NR==2 {print $5}')
  else
    local available_space=$(df -h "${data_dir}" | awk 'NR==2 {print $4}')
    local use_percentage=$(df -h "${data_dir}" | awk 'NR==2 {print $5}')
  fi

  echo -e "Available disk space: ${available_space}"
  echo -e "Disk usage: ${use_percentage}"

  # Check if disk usage is high (>85%)
  if [[ ${use_percentage%\%} -gt 85 ]]; then
    if type log_error &>/dev/null; then
      log_error "Disk usage is high (${use_percentage})"
      log_warn "Consider pruning data or adding more storage"
    else
      log_error "Disk usage is high (${use_percentage})"
      log_warn "Consider pruning data or adding more storage"
    fi
  else
    if type log_success &>/dev/null; then
      log_success "Disk usage within normal range"
    else
      log_success "Disk usage within normal range"
    fi
  fi
}

# Check Geth sync status
check_geth_sync_status() {
  if type log_info &>/dev/null; then
    log_info "Checking Geth sync status..."
  else
    log_info "Checking Geth sync status..."
  fi

  local geth_endpoint="http://localhost:8545"
  local curl_cmd="curl -s -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}'"

  if type run_with_error_handling &>/dev/null; then
    local geth_result=$(run_with_error_handling "Check Geth sync status" curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' "${geth_endpoint}" 2>/dev/null)
  else
    local geth_result=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' "${geth_endpoint}" 2>/dev/null)
  fi

  if [ $? -eq 0 ]; then
    if echo "${geth_result}" | grep -q '"result":false'; then
      if type log_success &>/dev/null; then
        log_success "Geth is fully synced"
      else
        log_success "Geth is fully synced"
      fi

      # Get latest block info
      if type run_with_error_handling &>/dev/null; then
        local latest_block=$(run_with_error_handling "Get latest block" curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "${geth_endpoint}")
      else
        local latest_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "${geth_endpoint}")
      fi

      local block_hex=$(echo "${latest_block}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)
      if [ ! -z "${block_hex}" ]; then
        local block_dec=$((16#${block_hex:2}))
        echo -e "Latest Block: ${block_dec}"
      fi
    else
      if type log_warn &>/dev/null; then
        log_warn "Geth is syncing"
      else
        log_warn "Geth is syncing"
      fi

      # Extract sync information
      local current_block=$(echo "${geth_result}" | grep -o '"currentBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)
      local highest_block=$(echo "${geth_result}" | grep -o '"highestBlock":"0x[0-9a-f]*"' | cut -d'"' -f4)

      if [ ! -z "${current_block}" ] && [ ! -z "${highest_block}" ]; then
        local current_dec=$((16#${current_block:2}))
        local highest_dec=$((16#${highest_block:2}))
        local remaining=$((highest_dec - current_dec))
        local percent_complete=$(((current_dec * 100) / highest_dec))

        echo -e "Current Block: ${current_dec}"
        echo -e "Highest Block: ${highest_dec}"
        echo -e "Remaining Blocks: ${remaining}"
        echo -e "Sync Percentage: ${percent_complete}%"
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Failed to connect to Geth API"
    else
      log_error "Failed to connect to Geth API"
    fi
  fi
}

# Check Lighthouse sync status
check_lighthouse_sync_status() {
  if type log_info &>/dev/null; then
    log_info "Checking Lighthouse sync status..."
  else
    log_info "Checking Lighthouse sync status..."
  fi

  local lighthouse_endpoint="http://localhost:5052/eth/v1/node/syncing"

  if type run_with_error_handling &>/dev/null; then
    local lighthouse_result=$(run_with_error_handling "Check Lighthouse sync status" curl -s -X GET "${lighthouse_endpoint}" -H "Content-Type: application/json" 2>/dev/null)
  else
    local lighthouse_result=$(curl -s -X GET "${lighthouse_endpoint}" -H "Content-Type: application/json" 2>/dev/null)
  fi

  if [ $? -eq 0 ]; then
    local is_syncing=$(echo "${lighthouse_result}" | grep -o '"is_syncing":[a-z]*' | cut -d':' -f2)

    if [[ "${is_syncing}" == "false" ]]; then
      if type log_success &>/dev/null; then
        log_success "Lighthouse is fully synced"
      else
        log_success "Lighthouse is fully synced"
      fi

      # Get current head slot
      if type run_with_error_handling &>/dev/null; then
        local head_info=$(run_with_error_handling "Get lighthouse head" curl -s -X GET "http://localhost:5052/eth/v1/beacon/headers/head" -H "Content-Type: application/json" 2>/dev/null)
      else
        local head_info=$(curl -s -X GET "http://localhost:5052/eth/v1/beacon/headers/head" -H "Content-Type: application/json" 2>/dev/null)
      fi

      local slot=$(echo "${head_info}" | grep -o '"slot":"[0-9]*"' | cut -d'"' -f4)
      if [ ! -z "${slot}" ]; then
        echo -e "Current Head Slot: ${slot}"
      fi
    else
      if type log_warn &>/dev/null; then
        log_warn "Lighthouse is syncing"
      else
        log_warn "Lighthouse is syncing"
      fi

      # Extract sync information if available
      local head_slot=$(echo "${lighthouse_result}" | grep -o '"head_slot":"[0-9]*"' | cut -d'"' -f4)
      local sync_distance=$(echo "${lighthouse_result}" | grep -o '"sync_distance":"[0-9]*"' | cut -d'"' -f4)

      if [ ! -z "${head_slot}" ] && [ ! -z "${sync_distance}" ]; then
        echo -e "Current Head Slot: ${head_slot}"
        echo -e "Sync Distance: ${sync_distance} slots"

        # Calculate estimated time remaining (rough estimate)
        local remaining_time=$((sync_distance / 225)) # ~225 slots per hour (12s per slot)
        if [ ${remaining_time} -gt 24 ]; then
          echo -e "Estimated time remaining: ~$((remaining_time / 24)) days, $((remaining_time % 24)) hours"
        else
          echo -e "Estimated time remaining: ~${remaining_time} hours"
        fi
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Failed to connect to Lighthouse API"
    else
      log_error "Failed to connect to Lighthouse API"
    fi
  fi
}

# Check validators
check_validators() {
  if type log_info &>/dev/null; then
    log_info "Checking validators..."
  else
    log_info "Checking validators..."
  fi

  if type is_container_running &>/dev/null; then
    if ! is_container_running "${EPHEMERY_VALIDATOR_CONTAINER}"; then
      if type log_warn &>/dev/null; then
        log_warn "Validator client not running"
      else
        log_warn "Validator client not running"
      fi
      return 1
    fi
  elif ! docker ps | grep -q "${EPHEMERY_VALIDATOR_CONTAINER}"; then
    if type log_warn &>/dev/null; then
      log_warn "Validator client not running"
    else
      log_warn "Validator client not running"
    fi
    return 1
  fi

  # Use standardized path if available
  local validator_keys_dir="${EPHEMERY_VALIDATOR_KEYS_DIR:-${EPHEMERY_BASE_DIR}/data/validator-keys}"

  if type run_with_error_handling &>/dev/null; then
    local validator_count=$(run_with_error_handling "Count validators" docker exec "${EPHEMERY_VALIDATOR_CONTAINER}" ls -1 /validatordata/validators/*/voting-keystore.json 2>/dev/null | wc -l)
  else
    local validator_count=$(docker exec "${EPHEMERY_VALIDATOR_CONTAINER}" ls -1 /validatordata/validators/*/voting-keystore.json 2>/dev/null | wc -l)
  fi

  if [ $? -eq 0 ] && [ "${validator_count}" -gt 0 ]; then
    if type log_success &>/dev/null; then
      log_success "${validator_count} validators configured"
    else
      log_success "${validator_count} validators configured"
    fi

    # Try to get active validators
    if type run_with_error_handling &>/dev/null; then
      local validator_status=$(run_with_error_handling "Get validator status" curl -s -X GET http://localhost:5052/eth/v1/beacon/states/head/validators 2>/dev/null)
    else
      local validator_status=$(curl -s -X GET http://localhost:5052/eth/v1/beacon/states/head/validators 2>/dev/null)
    fi

    if [ $? -eq 0 ] && [ ! -z "${validator_status}" ]; then
      local active_count=$(echo "${validator_status}" | grep -o '"status":"active_ongoing"' | wc -l)
      local pending_count=$(echo "${validator_status}" | grep -o '"status":"pending"' | wc -l)

      if [ "${active_count}" -gt 0 ]; then
        if type log_success &>/dev/null; then
          log_success "${active_count} validators active"
        else
          log_success "${active_count} validators active"
        fi
      fi
      if [ "${pending_count}" -gt 0 ]; then
        if type log_warn &>/dev/null; then
          log_warn "${pending_count} validators pending activation"
        else
          log_warn "${pending_count} validators pending activation"
        fi
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "No validators configured or unable to access validator data"
    else
      log_error "No validators configured or unable to access validator data"
    fi
  fi
}

# Check network connectivity
check_network_connectivity() {
  if type log_info &>/dev/null; then
    log_info "Checking network connectivity..."
  else
    log_info "Checking network connectivity..."
  fi

  # Check Geth peer count
  if type run_with_error_handling &>/dev/null; then
    local peer_count=$(run_with_error_handling "Get Geth peer count" curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545)
  else
    local peer_count=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545)
  fi

  local peer_hex=$(echo "${peer_count}" | grep -o '"result":"0x[0-9a-f]*"' | cut -d'"' -f4)

  if [ ! -z "${peer_hex}" ]; then
    local peer_dec=$((16#${peer_hex:2}))
    echo -e "Geth connected peers: ${peer_dec}"

    if [ ${peer_dec} -lt 5 ]; then
      if type log_error &>/dev/null; then
        log_error "Low peer count for Geth (< 5)"
      else
        log_error "Low peer count for Geth (< 5)"
      fi
    else
      if type log_success &>/dev/null; then
        log_success "Geth peer count is good"
      else
        log_success "Geth peer count is good"
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Unable to get Geth peer count"
    else
      log_error "Unable to get Geth peer count"
    fi
  fi

  # Check Lighthouse peer count
  if type run_with_error_handling &>/dev/null; then
    local lighthouse_peer_count=$(run_with_error_handling "Get Lighthouse peer count" curl -s -X GET http://localhost:5052/eth/v1/node/peers_count -H "Content-Type: application/json" 2>/dev/null)
  else
    local lighthouse_peer_count=$(curl -s -X GET http://localhost:5052/eth/v1/node/peers_count -H "Content-Type: application/json" 2>/dev/null)
  fi

  local connected=$(echo "${lighthouse_peer_count}" | grep -o '"connected":[0-9]*' | cut -d':' -f2)

  if [ ! -z "${connected}" ]; then
    echo -e "Lighthouse connected peers: ${connected}"

    if [ "${connected}" -lt 5 ]; then
      if type log_error &>/dev/null; then
        log_error "Low peer count for Lighthouse (< 5)"
      else
        log_error "Low peer count for Lighthouse (< 5)"
      fi
    else
      if type log_success &>/dev/null; then
        log_success "Lighthouse peer count is good"
      else
        log_success "Lighthouse peer count is good"
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Unable to get Lighthouse peer count"
    else
      log_error "Unable to get Lighthouse peer count"
    fi
  fi
}

# Run performance checks
run_performance_checks() {
  if type log_info &>/dev/null; then
    log_info "Running performance checks..."
  else
    log_info "Running performance checks..."
  fi

  # Check Geth performance
  check_container_resources "${EPHEMERY_GETH_CONTAINER}"

  # Check Lighthouse performance
  check_container_resources "${EPHEMERY_LIGHTHOUSE_CONTAINER}"

  # Check if validator is running and its performance
  if type is_container_running &>/dev/null; then
    if is_container_running "${EPHEMERY_VALIDATOR_CONTAINER}"; then
      check_container_resources "${EPHEMERY_VALIDATOR_CONTAINER}"
    fi
  else
    if docker ps | grep -q "${EPHEMERY_VALIDATOR_CONTAINER}"; then
      check_container_resources "${EPHEMERY_VALIDATOR_CONTAINER}"
    fi
  fi

  # Check disk I/O
  if type log_info &>/dev/null; then
    log_info "Checking disk I/O performance..."
  else
    log_info "Checking disk I/O performance..."
  fi

  if which iostat >/dev/null 2>&1; then
    if type run_with_error_handling &>/dev/null; then
      run_with_error_handling "Get I/O statistics" iostat -x | grep -v loop | grep -v ram
    else
      iostat -x | grep -v loop | grep -v ram
    fi
  else
    if type log_warn &>/dev/null; then
      log_warn "iostat not available, skipping detailed I/O statistics"
      log_info "Basic disk performance:"
    else
      log_warn "iostat not available, skipping detailed I/O statistics"
      log_info "Basic disk performance:"
    fi

    # Use standardized path if available
    local temp_file="${EPHEMERY_DATA_DIR:-${EPHEMERY_BASE_DIR}/data}/test_io.tmp"

    # Simple disk performance check
    echo -e "Writing 100MB test file..."
    if type run_with_error_handling &>/dev/null; then
      run_with_error_handling "Test disk write" dd if=/dev/zero of="${temp_file}" bs=1M count=100 2>&1 | grep -v records
      echo -e "Reading 100MB test file..."
      run_with_error_handling "Test disk read" dd if="${temp_file}" of=/dev/null bs=1M 2>&1 | grep -v records
      run_with_error_handling "Remove temp file" rm "${temp_file}"
    else
      dd if=/dev/zero of="${temp_file}" bs=1M count=100 2>&1 | grep -v records
      echo -e "Reading 100MB test file..."
      dd if="${temp_file}" of=/dev/null bs=1M 2>&1 | grep -v records
      rm "${temp_file}"
    fi
  fi
}

# Main execution logic based on check type
if type log_info &>/dev/null; then
  log_info "Starting health check (type: ${CHECK_TYPE})"
else
  log_info "Starting health check (type: ${CHECK_TYPE})"
fi

case ${CHECK_TYPE} in
  basic)
    if type log_info &>/dev/null; then
      log_info "Running basic health checks..."
    else
      log_info "Running basic health checks..."
    fi
    check_container_status "${EPHEMERY_GETH_CONTAINER}"
    check_container_status "${EPHEMERY_LIGHTHOUSE_CONTAINER}"
    check_container_status "${EPHEMERY_VALIDATOR_CONTAINER}"
    check_disk_space
    check_geth_sync_status
    check_lighthouse_sync_status
    ;;
  full)
    if type log_info &>/dev/null; then
      log_info "Running comprehensive health checks..."
    else
      log_info "Running comprehensive health checks..."
    fi
    check_container_status "${EPHEMERY_GETH_CONTAINER}"
    check_container_status "${EPHEMERY_LIGHTHOUSE_CONTAINER}"
    check_container_status "${EPHEMERY_VALIDATOR_CONTAINER}"
    check_disk_space
    check_geth_sync_status
    check_lighthouse_sync_status
    check_validators
    check_network_connectivity
    run_performance_checks
    ;;
  performance)
    run_performance_checks
    ;;
  network)
    if type log_info &>/dev/null; then
      log_info "Running network checks..."
    else
      log_info "Running network checks..."
    fi
    check_container_status "${EPHEMERY_GETH_CONTAINER}"
    check_container_status "${EPHEMERY_LIGHTHOUSE_CONTAINER}"
    check_network_connectivity
    ;;
  *)
    if type handle_error &>/dev/null; then
      handle_error "ERROR" "Unknown check type: ${CHECK_TYPE}" "${EXIT_CODES[INVALID_ARGUMENT]}"
    else
      log_error "Unknown check type: ${CHECK_TYPE}"
      show_usage
      exit 1
    fi
    ;;
esac

if type log_success &>/dev/null; then
  log_success "Health checks completed"
else
  log_success "Health checks completed"
fi
