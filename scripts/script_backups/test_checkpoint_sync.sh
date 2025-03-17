#!/bin/bash
# Version: 1.0.0
# test_checkpoint_sync.sh - Script to test checkpoint sync performance
# This implements Phase 5 of the Fix Checkpoint Sync Roadmap

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
TEST_RESULTS_DIR="${PROJECT_ROOT}/test_results"

# Create test results directory if it doesn't exist
mkdir -p "${TEST_RESULTS_DIR}"

# Test configurations
declare -A TEST_CONFIGS=(
  ["checkpoint_sync"]="use_checkpoint_sync: true; clear_database: true; cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=10 --disable-backfill-rate-limiting'; el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'"
  ["genesis_optimized"]="use_checkpoint_sync: false; clear_database: true; cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting'; el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'"
  ["genesis_default"]="use_checkpoint_sync: false; clear_database: true; cl_extra_opts: ''; el_extra_opts: ''"
)

# Function to display banner
show_banner() {
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${BLUE}    Ephemery Checkpoint Sync Testing Tool    ${NC}"
  echo -e "${BLUE}======================================================${NC}"
  echo ""
  echo -e "This script tests different sync methods for Ephemery"
  echo -e "and provides detailed performance metrics."
  echo ""
}

# Function to run tests
run_test() {
  local config_name="$1"
  local config="${TEST_CONFIGS[${config_name}]}"

  echo -e "${BLUE}Running test for: ${config_name}${NC}"
  echo -e "Configuration: ${config}"

  # Create test results file
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local results_file="${TEST_RESULTS_DIR}/${config_name}_${timestamp}.log"

  echo "Test started at: $(date)" >"${results_file}"
  echo "Configuration: ${config}" >>"${results_file}"
  echo "" >>"${results_file}"

  # Apply configuration to inventory
  echo -e "${YELLOW}Applying configuration to inventory...${NC}"

  # Extract configuration parameters
  local use_checkpoint_sync=$(echo "${config}" | grep -o "use_checkpoint_sync: [^;]*" | cut -d' ' -f2)
  local clear_database=$(echo "${config}" | grep -o "clear_database: [^;]*" | cut -d' ' -f2)
  local cl_extra_opts=$(echo "${config}" | grep -o "cl_extra_opts: '[^']*'" | cut -d\' -f2)
  local el_extra_opts=$(echo "${config}" | grep -o "el_extra_opts: '[^']*'" | cut -d\' -f2)

  # Backup inventory file
  cp "${PROJECT_ROOT}/inventory.yaml" "${PROJECT_ROOT}/inventory.yaml.bak"

  # Update inventory file with test configuration
  sed -i.bak "s/use_checkpoint_sync: .*/use_checkpoint_sync: ${use_checkpoint_sync}/" "${PROJECT_ROOT}/inventory.yaml"
  sed -i.bak "s/clear_database: .*/clear_database: ${clear_database}/" "${PROJECT_ROOT}/inventory.yaml"
  sed -i.bak "s/cl_extra_opts: .*/cl_extra_opts: '${cl_extra_opts}'/" "${PROJECT_ROOT}/inventory.yaml"
  sed -i.bak "s/el_extra_opts: .*/el_extra_opts: '${el_extra_opts}'/" "${PROJECT_ROOT}/inventory.yaml"

  # Start timer
  local start_time=$(date +%s)

  # Run Ansible playbook
  echo -e "${YELLOW}Running Ansible playbook...${NC}"
  cd "${PROJECT_ROOT}" || {
    echo "Error: Failed to change directory to ${PROJECT_ROOT}"
    exit 1
  }
  ansible-playbook -i inventory.yaml main.yaml -l test | tee -a "${results_file}"

  # Measure initial sync status
  echo -e "${YELLOW}Measuring initial sync status...${NC}"
  echo "Initial sync status at $(date):" >>"${results_file}"

  # Wait for Lighthouse to start
  sleep 30

  # Check Lighthouse sync status
  curl -s http://localhost:5052/eth/v1/node/syncing | tee -a "${results_file}"
  echo "" >>"${results_file}"

  # Check Geth sync status
  curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 | tee -a "${results_file}"
  echo "" >>"${results_file}"

  # Monitor sync progress every 5 minutes for up to 2 hours
  echo -e "${YELLOW}Monitoring sync progress for 2 hours...${NC}"

  local max_iterations=24 # 2 hours at 5-minute intervals
  local iteration=0

  while [ "${iteration}" -lt "${max_iterations}" ]; do
    sleep 300 # 5 minutes

    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    local elapsed_minutes=$((elapsed_time / 60))

    echo "Sync status after ${elapsed_minutes} minutes:" >>"${results_file}"

    # Check Lighthouse sync status
    local lighthouse_status=$(curl -s http://localhost:5052/eth/v1/node/syncing)
    echo "${lighthouse_status}" | tee -a "${results_file}"
    echo "" >>"${results_file}"

    # Extract sync metrics
    local is_syncing=$(echo "${lighthouse_status}" | grep -o '"is_syncing":[^,]*' | cut -d':' -f2 | tr -d ' "')
    local head_slot=$(echo "${lighthouse_status}" | grep -o '"head_slot":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    local sync_distance=$(echo "${lighthouse_status}" | grep -o '"sync_distance":"[^"]*"' | cut -d':' -f2 | tr -d '"')

    # Check Geth sync status
    local geth_status=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)
    echo "${geth_status}" | tee -a "${results_file}"
    echo "" >>"${results_file}"

    # Check if sync is complete or close enough
    if [[ "${is_syncing}" == "false" || "${sync_distance}" == "0" ]]; then
      echo -e "${GREEN}Sync completed after ${elapsed_minutes} minutes!${NC}"
      break
    fi

    # Get system resource usage
    echo "System resource usage:" >>"${results_file}"
    top -b -n 1 | head -n 20 >>"${results_file}"
    echo "" >>"${results_file}"

    ((iteration++))
  done

  # Calculate final stats
  local end_time=$(date +%s)
  local total_elapsed_time=$((end_time - start_time))
  local total_elapsed_minutes=$((total_elapsed_time / 60))

  echo "Test completed at: $(date)" >>"${results_file}"
  echo "Total test duration: ${total_elapsed_minutes} minutes" >>"${results_file}"

  # Restore original inventory
  mv "${PROJECT_ROOT}/inventory.yaml.bak" "${PROJECT_ROOT}/inventory.yaml"

  echo -e "${GREEN}Test completed for ${config_name}${NC}"
  echo -e "Results saved to: ${results_file}"
  echo ""
}

# Function to compare test results
compare_results() {
  echo -e "${BLUE}Comparing test results...${NC}"

  # Find the latest result file for each configuration
  local checkpoint_file=$(ls -t "${TEST_RESULTS_DIR}/checkpoint_sync_"*.log 2>/dev/null | head -n 1)
  local optimized_file=$(ls -t "${TEST_RESULTS_DIR}/genesis_optimized_"*.log 2>/dev/null | head -n 1)
  local default_file=$(ls -t "${TEST_RESULTS_DIR}/genesis_default_"*.log 2>/dev/null | head -n 1)

  # Create comparison file
  local comparison_file="${TEST_RESULTS_DIR}/comparison_$(date +"%Y%m%d_%H%M%S").md"

  echo "# Ephemery Sync Method Comparison" >"${comparison_file}"
  echo "" >>"${comparison_file}"
  echo "## Summary" >>"${comparison_file}"
  echo "" >>"${comparison_file}"
  echo "| Sync Method | Duration | Final Sync Distance | Final Head Slot |" >>"${comparison_file}"
  echo "|-------------|----------|---------------------|----------------|" >>"${comparison_file}"

  # Extract metrics from each file if it exists
  if [ -n "${checkpoint_file}" ]; then
    local checkpoint_duration=$(grep "Total test duration:" "${checkpoint_file}" | awk '{print $4}')
    local checkpoint_distance=$(grep -A 10 "Sync status after" "${checkpoint_file}" | grep -o '"sync_distance":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')
    local checkpoint_head_slot=$(grep -A 10 "Sync status after" "${checkpoint_file}" | grep -o '"head_slot":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')

    echo "| Checkpoint Sync | ${checkpoint_duration} min | ${checkpoint_distance} | ${checkpoint_head_slot} |" >>"${comparison_file}"
  else
    echo "| Checkpoint Sync | No data | No data | No data |" >>"${comparison_file}"
  fi

  if [ -n "${optimized_file}" ]; then
    local optimized_duration=$(grep "Total test duration:" "${optimized_file}" | awk '{print $4}')
    local optimized_distance=$(grep -A 10 "Sync status after" "${optimized_file}" | grep -o '"sync_distance":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')
    local optimized_head_slot=$(grep -A 10 "Sync status after" "${optimized_file}" | grep -o '"head_slot":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')

    echo "| Genesis Optimized | ${optimized_duration} min | ${optimized_distance} | ${optimized_head_slot} |" >>"${comparison_file}"
  else
    echo "| Genesis Optimized | No data | No data | No data |" >>"${comparison_file}"
  fi

  if [ -n "${default_file}" ]; then
    local default_duration=$(grep "Total test duration:" "${default_file}" | awk '{print $4}')
    local default_distance=$(grep -A 10 "Sync status after" "${default_file}" | grep -o '"sync_distance":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')
    local default_head_slot=$(grep -A 10 "Sync status after" "${default_file}" | grep -o '"head_slot":"[^"]*"' | tail -n 1 | cut -d':' -f2 | tr -d '"')

    echo "| Genesis Default | ${default_duration} min | ${default_distance} | ${default_head_slot} |" >>"${comparison_file}"
  else
    echo "| Genesis Default | No data | No data | No data |" >>"${comparison_file}"
  fi

  echo "" >>"${comparison_file}"
  echo "## Detailed Analysis" >>"${comparison_file}"
  echo "" >>"${comparison_file}"
  echo "### Checkpoint Sync" >>"${comparison_file}"
  echo "" >>"${comparison_file}"
  if [ -n "${checkpoint_file}" ]; then
    echo "Duration: ${checkpoint_duration} minutes" >>"${comparison_file}"
    echo "" >>"${comparison_file}"
    echo "Configuration:" >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
    grep "Configuration:" "${checkpoint_file}" | head -n 1 | cut -d':' -f2- >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
  else
    echo "No data available" >>"${comparison_file}"
  fi

  echo "" >>"${comparison_file}"
  echo "### Genesis Optimized" >>"${comparison_file}"
  echo "" >>"${comparison_file}"
  if [ -n "${optimized_file}" ]; then
    echo "Duration: ${optimized_duration} minutes" >>"${comparison_file}"
    echo "" >>"${comparison_file}"
    echo "Configuration:" >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
    grep "Configuration:" "${optimized_file}" | head -n 1 | cut -d':' -f2- >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
  else
    echo "No data available" >>"${comparison_file}"
  fi

  echo "" >>"${comparison_file}"
  echo "### Genesis Default" >>"${comparison_file}"
  echo "" >>"${comparison_file}"
  if [ -n "${default_file}" ]; then
    echo "Duration: ${default_duration} minutes" >>"${comparison_file}"
    echo "" >>"${comparison_file}"
    echo "Configuration:" >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
    grep "Configuration:" "${default_file}" | head -n 1 | cut -d':' -f2- >>"${comparison_file}"
    echo "\`\`\`" >>"${comparison_file}"
  else
    echo "No data available" >>"${comparison_file}"
  fi

  echo -e "${GREEN}Comparison report generated: ${comparison_file}${NC}"
}

# Function to show usage
usage() {
  echo -e "Usage: $0 [command]"
  echo -e ""
  echo -e "Commands:"
  echo -e "  all                Run all tests sequentially"
  echo -e "  checkpoint         Test checkpoint sync only"
  echo -e "  genesis-optimized  Test optimized genesis sync only"
  echo -e "  genesis-default    Test default genesis sync only"
  echo -e "  compare            Compare test results"
  echo -e "  help               Show this help message"
  echo -e ""
}

# Main function
main() {
  show_banner

  # Process command
  case "$1" in
    all)
      run_test "checkpoint_sync"
      run_test "genesis_optimized"
      run_test "genesis_default"
      compare_results
      ;;
    checkpoint)
      run_test "checkpoint_sync"
      ;;
    genesis-optimized)
      run_test "genesis_optimized"
      ;;
    genesis-default)
      run_test "genesis_default"
      ;;
    compare)
      compare_results
      ;;
    help)
      usage
      ;;
    *)
      echo -e "${YELLOW}No command specified. Using default command: help${NC}"
      usage
      ;;
  esac
}

# Execute main function with all args
main "$@"
