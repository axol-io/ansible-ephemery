#!/bin/bash
# Version: 1.0.0
# test_reset_recovery.sh - Test the recovery of nodes after an Ephemery network reset
# This script validates that the reset detection and recovery mechanisms work correctly

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Source core utilities
source "${PROJECT_ROOT}/scripts/core/path_config.sh"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
source "${PROJECT_ROOT}/scripts/core/common.sh"

# Setup error handling
setup_error_handling

# Test configuration
REPORT_FILE="${PROJECT_ROOT}/scripts/testing/reports/reset_recovery_$(date +%Y%m%d-%H%M%S).log"
MAX_WAIT_TIME=1800  # 30 minutes maximum wait for recovery

# Create report file
{
  echo "Ephemery Reset Recovery Test Report"
  echo "=================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "--------------------------------------------------------"
  echo ""
} > "${REPORT_FILE}"

# Function to check if required tools are available
check_prerequisites() {
  local missing_tools=()
  
  for tool in curl jq grep systemctl date bc timeout; do
    if ! command -v "${tool}" &> /dev/null; then
      missing_tools+=("${tool}")
    fi
  done
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
    echo "Please install these tools before running this test."
    echo "Missing tools: ${missing_tools[*]}" >> "${REPORT_FILE}"
    exit 1
  fi
}

# Function to get client information
get_execution_client() {
  # Read from inventory or config
  echo "geth"  # Replace with actual detection logic
}

get_consensus_client() {
  # Read from inventory or config
  echo "lighthouse"  # Replace with actual detection logic
}

# Function to check if services are running
check_services_running() {
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)
  
  echo -e "${BLUE}Checking if services are running...${NC}"
  echo "Checking if services are running..." >> "${REPORT_FILE}"
  
  # Check execution client service
  if systemctl is-active --quiet "${execution_client}.service"; then
    echo -e "${GREEN}✓ Execution client service (${execution_client}) is running${NC}"
    echo "✓ Execution client service (${execution_client}) is running" >> "${REPORT_FILE}"
  else
    echo -e "${RED}✗ Execution client service (${execution_client}) is not running${NC}"
    echo "✗ Execution client service (${execution_client}) is not running" >> "${REPORT_FILE}"
    return 1
  fi
  
  # Check consensus client service
  if systemctl is-active --quiet "${consensus_client}.service"; then
    echo -e "${GREEN}✓ Consensus client service (${consensus_client}) is running${NC}"
    echo "✓ Consensus client service (${consensus_client}) is running" >> "${REPORT_FILE}"
  else
    echo -e "${RED}✗ Consensus client service (${consensus_client}) is not running${NC}"
    echo "✗ Consensus client service (${consensus_client}) is not running" >> "${REPORT_FILE}"
    return 1
  fi
  
  # Check validator service if applicable
  if systemctl is-active --quiet "${consensus_client}-validator.service" 2>/dev/null; then
    echo -e "${GREEN}✓ Validator service (${consensus_client}-validator) is running${NC}"
    echo "✓ Validator service (${consensus_client}-validator) is running" >> "${REPORT_FILE}"
  fi
  
  return 0
}

# Function to check sync status of nodes
check_sync_status() {
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)
  
  echo -e "${BLUE}Checking sync status...${NC}"
  echo "Checking sync status..." >> "${REPORT_FILE}"
  
  # Check execution client sync status
  if [[ "${execution_client}" == "geth" ]]; then
    local eth_syncing=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 | jq '.result')
    
    if [[ "${eth_syncing}" == "false" ]]; then
      echo -e "${GREEN}✓ Execution client is in sync${NC}"
      echo "✓ Execution client is in sync" >> "${REPORT_FILE}"
    else
      echo -e "${YELLOW}! Execution client is still syncing${NC}"
      echo "! Execution client is still syncing" >> "${REPORT_FILE}"
      return 1
    fi
  fi
  
  # Check consensus client sync status
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    local sync_status=$(curl -s http://localhost:5052/lighthouse/syncing | jq '.is_syncing')
    
    if [[ "${sync_status}" == "false" ]]; then
      echo -e "${GREEN}✓ Consensus client is in sync${NC}"
      echo "✓ Consensus client is in sync" >> "${REPORT_FILE}"
    else
      echo -e "${YELLOW}! Consensus client is still syncing${NC}"
      echo "! Consensus client is still syncing" >> "${REPORT_FILE}"
      return 1
    fi
  fi
  
  return 0
}

# Function to check if validator is active
check_validator_status() {
  local consensus_client=$(get_consensus_client)
  
  echo -e "${BLUE}Checking validator status...${NC}"
  echo "Checking validator status..." >> "${REPORT_FILE}"
  
  # Get validator metrics (depends on client)
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    local validator_metrics=$(curl -s http://localhost:5064/metrics)
    
    # Check if there are active validators
    if echo "${validator_metrics}" | grep -q "process_validator_count"; then
      local validator_count=$(echo "${validator_metrics}" | grep "process_validator_count" | awk '{print $2}')
      
      if [[ "${validator_count}" -gt 0 ]]; then
        echo -e "${GREEN}✓ ${validator_count} validators are active${NC}"
        echo "✓ ${validator_count} validators are active" >> "${REPORT_FILE}"
        return 0
      fi
    fi
  fi
  
  echo -e "${YELLOW}! No active validators found${NC}"
  echo "! No active validators found" >> "${REPORT_FILE}"
  return 1
}

# Function to get current epoch
get_current_epoch() {
  local consensus_client=$(get_consensus_client)
  
  # Try to get current epoch from API
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    local head_info=$(curl -s http://localhost:5052/eth/v1/beacon/headers/head)
    local slot=$(echo "${head_info}" | jq '.data.header.message.slot')
    
    # Calculate epoch from slot (slot / 32)
    local epoch=$((slot / 32))
    echo "${epoch}"
    return 0
  fi
  
  # Fallback: return 0 if we can't determine
  echo "0"
}

# Function to simulate a network reset
simulate_network_reset() {
  echo -e "${BLUE}Simulating Ephemery network reset...${NC}"
  echo "Simulating Ephemery network reset..." >> "${REPORT_FILE}"
  
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)
  
  # Record current info
  local pre_reset_epoch=$(get_current_epoch)
  echo "Pre-reset epoch: ${pre_reset_epoch}" >> "${REPORT_FILE}"
  
  # Stop services
  echo -e "${BLUE}Stopping client services for reset simulation...${NC}"
  echo "Stopping client services for reset simulation..." >> "${REPORT_FILE}"
  
  # Stop validator if it exists
  if systemctl is-active --quiet "${consensus_client}-validator.service" 2>/dev/null; then
    sudo systemctl stop "${consensus_client}-validator.service"
  fi
  
  # Stop consensus client
  sudo systemctl stop "${consensus_client}.service"
  
  # Stop execution client
  sudo systemctl stop "${execution_client}.service"
  
  # Clear the chain data to simulate a fresh start
  echo -e "${BLUE}Clearing chain data to simulate reset...${NC}"
  echo "Clearing chain data to simulate reset..." >> "${REPORT_FILE}"
  
  # Backup current data directory for safety
  local datetime=$(date +%Y%m%d-%H%M%S)
  
  # Define data directories based on common locations (adjust as needed)
  local exec_data_dir="/var/lib/ethereum/${execution_client}"
  local cons_data_dir="/var/lib/ethereum/${consensus_client}"
  
  # Backup and clean execution client data
  if [ -d "${exec_data_dir}" ]; then
    sudo cp -r "${exec_data_dir}" "${exec_data_dir}_backup_${datetime}"
    sudo rm -rf "${exec_data_dir}"/*
  fi
  
  # Backup and clean consensus client data
  if [ -d "${cons_data_dir}" ]; then
    sudo cp -r "${cons_data_dir}" "${cons_data_dir}_backup_${datetime}"
    sudo rm -rf "${cons_data_dir}"/*
  fi
  
  echo -e "${GREEN}Reset simulation completed${NC}"
  echo "Reset simulation completed" >> "${REPORT_FILE}"
}

# Function to trigger the reset detection and recovery
trigger_reset_recovery() {
  echo -e "${BLUE}Triggering reset detection and recovery...${NC}"
  echo "Triggering reset detection and recovery..." >> "${REPORT_FILE}"
  
  # Start the services
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)
  
  # Start execution client
  sudo systemctl start "${execution_client}.service"
  
  # Start consensus client
  sudo systemctl start "${consensus_client}.service"
  
  # Start validator if it exists
  if systemctl list-unit-files | grep -q "${consensus_client}-validator.service"; then
    sudo systemctl start "${consensus_client}-validator.service"
  fi
  
  # Trigger the retention script which should detect the reset
  if [ -f "${PROJECT_ROOT}/scripts/core/retention.sh" ]; then
    echo -e "${BLUE}Running retention script to trigger recovery...${NC}"
    echo "Running retention script to trigger recovery..." >> "${REPORT_FILE}"
    
    sudo bash "${PROJECT_ROOT}/scripts/core/retention.sh"
  else
    echo -e "${YELLOW}! Retention script not found at expected location${NC}"
    echo "! Retention script not found at expected location" >> "${REPORT_FILE}"
  fi
  
  echo -e "${GREEN}Recovery triggered${NC}"
  echo "Recovery triggered" >> "${REPORT_FILE}"
}

# Function to monitor recovery progress
monitor_recovery() {
  local max_wait=$1
  local check_interval=60  # Check every minute
  local waited=0
  
  echo -e "${BLUE}Monitoring recovery progress (max wait: ${max_wait}s)...${NC}"
  echo "Monitoring recovery progress (max wait: ${max_wait}s)..." >> "${REPORT_FILE}"
  
  while [ ${waited} -lt ${max_wait} ]; do
    echo -e "${YELLOW}Checking recovery status after ${waited}s...${NC}"
    echo "Checking recovery status after ${waited}s..." >> "${REPORT_FILE}"
    
    # Check if services are running
    if check_services_running; then
      # Check if clients are in sync
      if check_sync_status; then
        # Check if validator is active
        if check_validator_status; then
          echo -e "${GREEN}✓ Recovery complete after ${waited}s${NC}"
          echo "✓ Recovery complete after ${waited}s" >> "${REPORT_FILE}"
          return 0
        fi
      fi
    fi
    
    # Wait and increment counter
    sleep ${check_interval}
    waited=$((waited + check_interval))
  done
  
  echo -e "${RED}✗ Recovery did not complete within ${max_wait}s${NC}"
  echo "✗ Recovery did not complete within ${max_wait}s" >> "${REPORT_FILE}"
  return 1
}

# Function to run the reset recovery test
run_reset_recovery_test() {
  echo -e "${BLUE}Starting reset recovery test...${NC}"
  echo "Starting reset recovery test..." >> "${REPORT_FILE}"
  
  # Initial checks
  if ! check_services_running; then
    echo -e "${RED}✗ Initial service check failed. Cannot proceed with test.${NC}"
    echo "✗ Initial service check failed. Cannot proceed with test." >> "${REPORT_FILE}"
    return 1
  fi
  
  # Simulate network reset
  simulate_network_reset
  
  # Trigger recovery
  trigger_reset_recovery
  
  # Monitor recovery progress
  if monitor_recovery ${MAX_WAIT_TIME}; then
    echo -e "${GREEN}✓ Reset recovery test passed${NC}"
    echo "✓ PASSED: Reset recovery test" >> "${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}✗ Reset recovery test failed${NC}"
    echo "✗ FAILED: Reset recovery test" >> "${REPORT_FILE}"
    return 1
  fi
}

# Main function
main() {
  echo -e "${BLUE}Ephemery Reset Recovery Test${NC}"
  
  # Check prerequisites
  check_prerequisites
  
  # Run the test
  if run_reset_recovery_test; then
    echo -e "${GREEN}✓ Reset recovery test passed${NC}"
    return 0
  else
    echo -e "${RED}✗ Reset recovery test failed${NC}"
    return 1
  fi
}

# Run main function
main "$@" 
