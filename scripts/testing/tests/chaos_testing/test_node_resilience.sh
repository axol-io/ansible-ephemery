#!/bin/bash
# Version: 1.0.0
# test_node_resilience.sh - Chaos testing for Ephemery nodes
# This script tests the resilience of Ephemery nodes under adverse conditions
# such as network partitions, resource constraints, and unexpected failures.

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
CHAOS_DIR="${PROJECT_ROOT}/scripts/testing/fixtures/chaos_test"
RESULTS_FILE="${PROJECT_ROOT}/scripts/testing/reports/chaos_testing_$(date +%Y%m%d-%H%M%S).log"
TEST_DURATION=1800  # 30 minutes for each chaos test

# Create results directory
mkdir -p "$(dirname "${RESULTS_FILE}")"

# Client combination to test
DEFAULT_EXECUTION_CLIENT="geth"
DEFAULT_CONSENSUS_CLIENT="lighthouse"
EXECUTION_CLIENT=${1:-$DEFAULT_EXECUTION_CLIENT}
CONSENSUS_CLIENT=${2:-$DEFAULT_CONSENSUS_CLIENT}

# Create report header
{
  echo "Ephemery Node Chaos Testing Report"
  echo "=================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Client combination: ${EXECUTION_CLIENT} + ${CONSENSUS_CLIENT}"
  echo "Test duration per scenario: ${TEST_DURATION} seconds"
  echo "--------------------------------------------------------"
  echo ""
} > "${RESULTS_FILE}"

# Function to set up the test environment
setup_test_env() {
  echo -e "${BLUE}Setting up chaos testing environment${NC}"
  echo "Setting up chaos testing environment" >> "${RESULTS_FILE}"
  
  # Create test directory
  mkdir -p "${CHAOS_DIR}"
  
  # Create inventory file
  cat > "${CHAOS_DIR}/inventory.yaml" << EOF
all:
  hosts:
    ephemery_chaos_test:
      ansible_connection: local
      execution_client: ${EXECUTION_CLIENT}
      consensus_client: ${CONSENSUS_CLIENT}
      validator_client: ${CONSENSUS_CLIENT}
      network_name: ephemery
      setup_validator: true
      checkpoint_sync_url: https://beaconstate.info
      enable_metrics: true
      enable_watchtower: true
      data_dir: ./data
EOF

  # Deploy ephemery node
  if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${CHAOS_DIR}/inventory.yaml" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml"; then
    echo "✗ Deployment failed, cannot proceed with chaos tests" | tee -a "${RESULTS_FILE}"
    exit 1
  fi
  
  echo "✓ Test environment setup complete" >> "${RESULTS_FILE}"
  echo -e "${GREEN}✓ Test environment setup complete${NC}"
  
  # Wait for initial sync to begin
  sleep 30
  
  return 0
}

# Function to check if a container is healthy
check_container_health() {
  local container_name=$1
  local max_wait=$2
  local wait_count=0
  
  echo "Checking health of ${container_name}..." >> "${RESULTS_FILE}"
  
  while [ ${wait_count} -lt ${max_wait} ]; do
    if docker ps --format '{{.Names}}' | grep -q "${container_name}" && \
       docker inspect --format='{{.State.Running}}' "${container_name}" | grep -q "true"; then
      echo "✓ Container ${container_name} is running" >> "${RESULTS_FILE}"
      return 0
    fi
    
    wait_count=$((wait_count + 5))
    echo "Waiting for container ${container_name} to be healthy (${wait_count}/${max_wait} seconds)..." >> "${RESULTS_FILE}"
    sleep 5
  done
  
  echo "✗ Container ${container_name} failed to become healthy within ${max_wait} seconds" >> "${RESULTS_FILE}"
  return 1
}

# Function to check if consensus client is syncing
check_consensus_sync() {
  local container_name="ephemery_${CONSENSUS_CLIENT}"
  local api_port=5052
  local max_wait=60
  local wait_count=0
  
  echo "Checking sync status of ${container_name}..." >> "${RESULTS_FILE}"
  
  while [ ${wait_count} -lt ${max_wait} ]; do
    if docker exec "${container_name}" curl -s "http://localhost:${api_port}/eth/v1/node/syncing" &> /dev/null; then
      echo "✓ Consensus client ${CONSENSUS_CLIENT} is responding to API calls" >> "${RESULTS_FILE}"
      return 0
    fi
    
    wait_count=$((wait_count + 5))
    echo "Waiting for consensus client API (${wait_count}/${max_wait} seconds)..." >> "${RESULTS_FILE}"
    sleep 5
  done
  
  echo "✗ Consensus client ${CONSENSUS_CLIENT} is not responding to API calls" >> "${RESULTS_FILE}"
  return 1
}

# Test 1: High CPU Load Test
test_high_cpu_load() {
  echo -e "${BLUE}Running High CPU Load Test${NC}"
  
  {
    echo ""
    echo "Test 1: High CPU Load Test"
    echo "-------------------------"
    echo "Starting at: $(date)"
    echo "Duration: ${TEST_DURATION} seconds"
    echo ""
  } >> "${RESULTS_FILE}"
  
  # Container names
  local exec_container="ephemery_${EXECUTION_CLIENT}"
  local cons_container="ephemery_${CONSENSUS_CLIENT}"
  
  # Get initial sync status
  local initial_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Initial sync distance: ${initial_sync}" >> "${RESULTS_FILE}"
  
  # Start stress test in containers
  echo "Starting CPU stress test in ${exec_container}..." >> "${RESULTS_FILE}"
  docker exec -d "${exec_container}" sh -c "apt-get update && apt-get install -y stress && stress --cpu 2 --timeout ${TEST_DURATION}" || echo "Could not start stress in ${exec_container}" >> "${RESULTS_FILE}"
  
  echo "Starting CPU stress test in ${cons_container}..." >> "${RESULTS_FILE}"
  docker exec -d "${cons_container}" sh -c "apt-get update && apt-get install -y stress && stress --cpu 2 --timeout ${TEST_DURATION}" || echo "Could not start stress in ${cons_container}" >> "${RESULTS_FILE}"
  
  # Monitor during stress test
  local start_time=$(date +%s)
  local end_time=$((start_time + TEST_DURATION))
  local current_time=${start_time}
  
  echo "Monitoring during CPU stress test..." >> "${RESULTS_FILE}"
  
  while [ ${current_time} -lt ${end_time} ]; do
    # Log CPU usage
    local cpu_usage=$(docker stats --no-stream --format "{{.Name}}: {{.CPUPerc}}" "${exec_container}" "${cons_container}")
    echo "$(date): CPU Usage: ${cpu_usage}" >> "${RESULTS_FILE}"
    
    # Check if containers are still running
    if ! docker ps --format '{{.Names}}' | grep -q "${exec_container}"; then
      echo "⚠️ Execution client container ${exec_container} crashed during CPU stress" >> "${RESULTS_FILE}"
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "${cons_container}"; then
      echo "⚠️ Consensus client container ${cons_container} crashed during CPU stress" >> "${RESULTS_FILE}"
    fi
    
    # Sleep for a bit
    sleep 30
    current_time=$(date +%s)
  done
  
  # Get final sync status
  local final_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Final sync distance: ${final_sync}" >> "${RESULTS_FILE}"
  
  # Check for container health after stress test
  if check_container_health "${exec_container}" 60 && check_container_health "${cons_container}" 60; then
    echo "✓ PASSED: Both containers survived high CPU load" >> "${RESULTS_FILE}"
    echo -e "${GREEN}✓ PASSED: High CPU Load Test${NC}"
  else
    echo "✗ FAILED: One or more containers did not survive high CPU load" >> "${RESULTS_FILE}"
    echo -e "${RED}✗ FAILED: High CPU Load Test${NC}"
    
    # Restart containers if they crashed
    docker start "${exec_container}" "${cons_container}" || true
    sleep 30
  fi
  
  {
    echo ""
    echo "High CPU Load Test completed at: $(date)"
    echo "--------------------------------------------------------"
  } >> "${RESULTS_FILE}"
  
  return 0
}

# Test 2: Network Disruption Test
test_network_disruption() {
  echo -e "${BLUE}Running Network Disruption Test${NC}"
  
  {
    echo ""
    echo "Test 2: Network Disruption Test"
    echo "-----------------------------"
    echo "Starting at: $(date)"
    echo "Duration: ${TEST_DURATION} seconds"
    echo ""
  } >> "${RESULTS_FILE}"
  
  # Container names
  local exec_container="ephemery_${EXECUTION_CLIENT}"
  local cons_container="ephemery_${CONSENSUS_CLIENT}"
  
  # Get initial sync status
  local initial_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Initial sync distance: ${initial_sync}" >> "${RESULTS_FILE}"
  
  # Disrupt network connectivity
  echo "Disconnecting network for ${exec_container}..." >> "${RESULTS_FILE}"
  docker network disconnect bridge "${exec_container}" || echo "Could not disconnect network for ${exec_container}" >> "${RESULTS_FILE}"
  
  # Wait for some time
  echo "Waiting for 5 minutes with disrupted network..." >> "${RESULTS_FILE}"
  sleep 300
  
  # Check container health during disruption
  if ! check_container_health "${exec_container}" 30; then
    echo "⚠️ Execution client crashed during network disruption" >> "${RESULTS_FILE}"
  fi
  
  if ! check_container_health "${cons_container}" 30; then
    echo "⚠️ Consensus client crashed during network disruption" >> "${RESULTS_FILE}"
  fi
  
  # Reconnect network
  echo "Reconnecting network for ${exec_container}..." >> "${RESULTS_FILE}"
  docker network connect bridge "${exec_container}" || echo "Could not reconnect network for ${exec_container}" >> "${RESULTS_FILE}"
  
  # Wait for recovery
  echo "Waiting for recovery after network reconnection..." >> "${RESULTS_FILE}"
  sleep 300
  
  # Get final sync status
  local final_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Final sync distance: ${final_sync}" >> "${RESULTS_FILE}"
  
  # Check if clients recovered
  if check_container_health "${exec_container}" 60 && check_container_health "${cons_container}" 60 && check_consensus_sync; then
    echo "✓ PASSED: Clients recovered after network disruption" >> "${RESULTS_FILE}"
    echo -e "${GREEN}✓ PASSED: Network Disruption Test${NC}"
  else
    echo "✗ FAILED: Clients did not recover after network disruption" >> "${RESULTS_FILE}"
    echo -e "${RED}✗ FAILED: Network Disruption Test${NC}"
    
    # Restart containers if they crashed
    docker start "${exec_container}" "${cons_container}" || true
    sleep 30
  fi
  
  {
    echo ""
    echo "Network Disruption Test completed at: $(date)"
    echo "--------------------------------------------------------"
  } >> "${RESULTS_FILE}"
  
  return 0
}

# Test 3: Execution Client Crash Test
test_execution_crash() {
  echo -e "${BLUE}Running Execution Client Crash Test${NC}"
  
  {
    echo ""
    echo "Test 3: Execution Client Crash Test"
    echo "--------------------------------"
    echo "Starting at: $(date)"
    echo ""
  } >> "${RESULTS_FILE}"
  
  # Container names
  local exec_container="ephemery_${EXECUTION_CLIENT}"
  local cons_container="ephemery_${CONSENSUS_CLIENT}"
  
  # Get initial sync status
  local initial_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Initial sync distance: ${initial_sync}" >> "${RESULTS_FILE}"
  
  # Crash the execution client
  echo "Stopping execution client container ${exec_container}..." >> "${RESULTS_FILE}"
  docker stop "${exec_container}" || echo "Could not stop ${exec_container}" >> "${RESULTS_FILE}"
  
  # Wait for 5 minutes
  echo "Waiting for 5 minutes with execution client down..." >> "${RESULTS_FILE}"
  sleep 300
  
  # Check consensus client health
  if ! check_container_health "${cons_container}" 30; then
    echo "⚠️ Consensus client crashed when execution client was down" >> "${RESULTS_FILE}"
  else
    echo "✓ Consensus client remained operational without execution client" >> "${RESULTS_FILE}"
  fi
  
  # Restart execution client
  echo "Restarting execution client container ${exec_container}..." >> "${RESULTS_FILE}"
  docker start "${exec_container}" || echo "Could not restart ${exec_container}" >> "${RESULTS_FILE}"
  
  # Wait for recovery
  echo "Waiting for recovery after execution client restart..." >> "${RESULTS_FILE}"
  sleep 300
  
  # Get final sync status
  local final_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Final sync distance: ${final_sync}" >> "${RESULTS_FILE}"
  
  # Check if clients recovered
  if check_container_health "${exec_container}" 60 && check_container_health "${cons_container}" 60 && check_consensus_sync; then
    echo "✓ PASSED: System recovered after execution client crash" >> "${RESULTS_FILE}"
    echo -e "${GREEN}✓ PASSED: Execution Client Crash Test${NC}"
  else
    echo "✗ FAILED: System did not recover after execution client crash" >> "${RESULTS_FILE}"
    echo -e "${RED}✗ FAILED: Execution Client Crash Test${NC}"
    
    # Restart containers if they crashed
    docker start "${exec_container}" "${cons_container}" || true
    sleep 30
  fi
  
  {
    echo ""
    echo "Execution Client Crash Test completed at: $(date)"
    echo "--------------------------------------------------------"
  } >> "${RESULTS_FILE}"
  
  return 0
}

# Test 4: Memory Pressure Test
test_memory_pressure() {
  echo -e "${BLUE}Running Memory Pressure Test${NC}"
  
  {
    echo ""
    echo "Test 4: Memory Pressure Test"
    echo "-------------------------"
    echo "Starting at: $(date)"
    echo "Duration: ${TEST_DURATION} seconds"
    echo ""
  } >> "${RESULTS_FILE}"
  
  # Container names
  local exec_container="ephemery_${EXECUTION_CLIENT}"
  local cons_container="ephemery_${CONSENSUS_CLIENT}"
  
  # Get initial sync status
  local initial_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Initial sync distance: ${initial_sync}" >> "${RESULTS_FILE}"
  
  # Start memory pressure test in containers
  echo "Starting memory pressure test in ${exec_container}..." >> "${RESULTS_FILE}"
  docker exec -d "${exec_container}" sh -c "apt-get update && apt-get install -y stress && stress --vm 1 --vm-bytes 512M --timeout ${TEST_DURATION}" || echo "Could not start memory stress in ${exec_container}" >> "${RESULTS_FILE}"
  
  echo "Starting memory pressure test in ${cons_container}..." >> "${RESULTS_FILE}"
  docker exec -d "${cons_container}" sh -c "apt-get update && apt-get install -y stress && stress --vm 1 --vm-bytes 512M --timeout ${TEST_DURATION}" || echo "Could not start memory stress in ${cons_container}" >> "${RESULTS_FILE}"
  
  # Monitor during stress test
  local start_time=$(date +%s)
  local end_time=$((start_time + TEST_DURATION))
  local current_time=${start_time}
  
  echo "Monitoring during memory pressure test..." >> "${RESULTS_FILE}"
  
  while [ ${current_time} -lt ${end_time} ]; do
    # Log memory usage
    local memory_usage=$(docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}" "${exec_container}" "${cons_container}")
    echo "$(date): Memory Usage: ${memory_usage}" >> "${RESULTS_FILE}"
    
    # Check if containers are still running
    if ! docker ps --format '{{.Names}}' | grep -q "${exec_container}"; then
      echo "⚠️ Execution client container ${exec_container} crashed during memory pressure" >> "${RESULTS_FILE}"
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "${cons_container}"; then
      echo "⚠️ Consensus client container ${cons_container} crashed during memory pressure" >> "${RESULTS_FILE}"
    fi
    
    # Sleep for a bit
    sleep 30
    current_time=$(date +%s)
  done
  
  # Get final sync status
  local final_sync=$(docker exec "${cons_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Final sync distance: ${final_sync}" >> "${RESULTS_FILE}"
  
  # Check for container health after stress test
  if check_container_health "${exec_container}" 60 && check_container_health "${cons_container}" 60 && check_consensus_sync; then
    echo "✓ PASSED: Both containers survived memory pressure" >> "${RESULTS_FILE}"
    echo -e "${GREEN}✓ PASSED: Memory Pressure Test${NC}"
  else
    echo "✗ FAILED: One or more containers did not survive memory pressure" >> "${RESULTS_FILE}"
    echo -e "${RED}✗ FAILED: Memory Pressure Test${NC}"
    
    # Restart containers if they crashed
    docker start "${exec_container}" "${cons_container}" || true
    sleep 30
  fi
  
  {
    echo ""
    echo "Memory Pressure Test completed at: $(date)"
    echo "--------------------------------------------------------"
  } >> "${RESULTS_FILE}"
  
  return 0
}

# Clean up test environment
cleanup() {
  echo -e "${BLUE}Cleaning up chaos testing environment${NC}"
  echo "Cleaning up chaos testing environment" >> "${RESULTS_FILE}"
  
  # Stop and remove containers
  docker stop "ephemery_${EXECUTION_CLIENT}" "ephemery_${CONSENSUS_CLIENT}" || true
  docker rm "ephemery_${EXECUTION_CLIENT}" "ephemery_${CONSENSUS_CLIENT}" || true
  
  # Remove test directory
  rm -rf "${CHAOS_DIR}"
  
  echo "Cleanup complete" >> "${RESULTS_FILE}"
  
  return 0
}

# Main function to run all tests
main() {
  echo -e "${BLUE}Starting Ephemery node chaos testing${NC}"
  echo "Testing client combination: ${EXECUTION_CLIENT} + ${CONSENSUS_CLIENT}"
  
  # Setup test environment
  setup_test_env
  
  # Run all chaos tests
  test_high_cpu_load
  test_network_disruption
  test_execution_crash
  test_memory_pressure
  
  # Generate summary
  {
    echo ""
    echo "Chaos Testing Summary"
    echo "===================="
    echo "Client combination: ${EXECUTION_CLIENT} + ${CONSENSUS_CLIENT}"
    echo "Tests completed: 4"
    
    local pass_count=$(grep -c "✓ PASSED:" "${RESULTS_FILE}")
    local fail_count=$(grep -c "✗ FAILED:" "${RESULTS_FILE}")
    
    echo "Tests passed: ${pass_count}"
    echo "Tests failed: ${fail_count}"
    
    if [ "${fail_count}" -eq 0 ]; then
      echo "OVERALL RESULT: PASSED"
    else
      echo "OVERALL RESULT: FAILED"
    fi
  } | tee -a "${RESULTS_FILE}"
  
  # Cleanup
  cleanup
  
  echo -e "${GREEN}Chaos testing completed. Full report available at:${NC}"
  echo "${RESULTS_FILE}"
  
  if [ "$(grep -c "✗ FAILED:" "${RESULTS_FILE}")" -gt 0 ]; then
    return 1
  fi
  
  return 0
}

# Run main function
main "$@" 
