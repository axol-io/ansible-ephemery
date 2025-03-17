#!/bin/bash
# Version: 1.0.0
# test_network_disruption.sh - Tests node resilience under network disruption conditions
# This script simulates various network disruption scenarios and verifies node recovery

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../../" &> /dev/null && pwd)"

# Source core utilities
source "${PROJECT_ROOT}/scripts/core/path_config.sh"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
source "${PROJECT_ROOT}/scripts/core/common.sh"

# Setup error handling
setup_error_handling

# Test configuration
TEST_DURATION=300  # 5 minutes
REPORT_FILE="${PROJECT_ROOT}/scripts/testing/reports/network_disruption_$(date +%Y%m%d-%H%M%S).log"

# Create report file
{
  echo "Network Disruption Chaos Test Report"
  echo "===================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Test Duration: ${TEST_DURATION} seconds"
  echo "--------------------------------------------------------"
  echo ""
} > "${REPORT_FILE}"

# Function to check if required tools are installed
check_prerequisites() {
  local missing_tools=()
  
  for tool in tc ip iptables curl jq; do
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

# Function to check if node services are running
check_node_services() {
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)
  
  echo -e "${BLUE}Checking node services...${NC}"
  echo "Checking node services:" >> "${REPORT_FILE}"
  
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
  
  return 0
}

# Function to get current client from config
get_execution_client() {
  # Read from inventory or config
  echo "geth"  # Replace with actual detection logic
}

get_consensus_client() {
  # Read from inventory or config
  echo "lighthouse"  # Replace with actual detection logic
}

# Function to simulate network latency
simulate_network_latency() {
  local interface=$1
  local latency=$2  # in ms
  local duration=$3  # in seconds
  
  echo -e "${BLUE}Simulating network latency (${latency}ms) for ${duration} seconds...${NC}"
  echo "Simulating network latency (${latency}ms) for ${duration} seconds..." >> "${REPORT_FILE}"
  
  # Add latency to network interface
  sudo tc qdisc add dev "${interface}" root netem delay "${latency}ms" 20ms distribution normal
  
  # Sleep for the specified duration
  sleep "${duration}"
  
  # Remove the network constraints
  sudo tc qdisc del dev "${interface}" root
  
  echo -e "${GREEN}Network latency simulation ended${NC}"
  echo "Network latency simulation ended" >> "${REPORT_FILE}"
}

# Function to simulate packet loss
simulate_packet_loss() {
  local interface=$1
  local loss_percent=$2  # percentage
  local duration=$3  # in seconds
  
  echo -e "${BLUE}Simulating packet loss (${loss_percent}%) for ${duration} seconds...${NC}"
  echo "Simulating packet loss (${loss_percent}%) for ${duration} seconds..." >> "${REPORT_FILE}"
  
  # Add packet loss to network interface
  sudo tc qdisc add dev "${interface}" root netem loss "${loss_percent}%"
  
  # Sleep for the specified duration
  sleep "${duration}"
  
  # Remove the network constraints
  sudo tc qdisc del dev "${interface}" root
  
  echo -e "${GREEN}Packet loss simulation ended${NC}"
  echo "Packet loss simulation ended" >> "${REPORT_FILE}"
}

# Function to block p2p ports
block_p2p_ports() {
  local duration=$1  # in seconds
  
  echo -e "${BLUE}Blocking P2P ports for ${duration} seconds...${NC}"
  echo "Blocking P2P ports for ${duration} seconds..." >> "${REPORT_FILE}"
  
  # Block common Ethereum P2P ports
  sudo iptables -A INPUT -p tcp --dport 30303 -j DROP  # Execution client P2P
  sudo iptables -A INPUT -p udp --dport 30303 -j DROP
  sudo iptables -A INPUT -p tcp --dport 9000 -j DROP   # Consensus client P2P
  sudo iptables -A INPUT -p udp --dport 9000 -j DROP
  
  # Sleep for the specified duration
  sleep "${duration}"
  
  # Remove the blocks
  sudo iptables -D INPUT -p tcp --dport 30303 -j DROP
  sudo iptables -D INPUT -p udp --dport 30303 -j DROP
  sudo iptables -D INPUT -p tcp --dport 9000 -j DROP
  sudo iptables -D INPUT -p udp --dport 9000 -j DROP
  
  echo -e "${GREEN}P2P port blocking ended${NC}"
  echo "P2P port blocking ended" >> "${REPORT_FILE}"
}

# Function to check execution client sync status
check_execution_sync() {
  local execution_client=$(get_execution_client)
  local eth_syncing
  
  # Check sync status via RPC
  eth_syncing=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545 | jq '.result')
  
  if [[ "${eth_syncing}" == "false" ]]; then
    echo -e "${GREEN}✓ Execution client synchronized${NC}"
    echo "✓ Execution client synchronized" >> "${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}✗ Execution client not synchronized${NC}"
    echo "✗ Execution client not synchronized" >> "${REPORT_FILE}"
    return 1
  fi
}

# Function to check consensus client sync status
check_consensus_sync() {
  local consensus_client=$(get_consensus_client)
  local sync_status
  
  # Check sync status via API (specific to client)
  # Example for Lighthouse
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    sync_status=$(curl -s http://localhost:5052/lighthouse/syncing | jq '.is_syncing')
    
    if [[ "${sync_status}" == "false" ]]; then
      echo -e "${GREEN}✓ Consensus client synchronized${NC}"
      echo "✓ Consensus client synchronized" >> "${REPORT_FILE}"
      return 0
    else
      echo -e "${RED}✗ Consensus client not synchronized${NC}"
      echo "✗ Consensus client not synchronized" >> "${REPORT_FILE}"
      return 1
    fi
  fi
  
  # Add checks for other consensus clients as needed
  
  # Default fallback for unknown clients
  echo -e "${YELLOW}! Could not determine consensus sync status for ${consensus_client}${NC}"
  echo "! Could not determine consensus sync status for ${consensus_client}" >> "${REPORT_FILE}"
  return 0
}

# Function to wait for node recovery
wait_for_recovery() {
  local max_wait=$1  # maximum wait time in seconds
  local wait_interval=5  # check every 5 seconds
  local waited=0
  
  echo -e "${BLUE}Waiting for node recovery (max ${max_wait}s)...${NC}"
  echo "Waiting for node recovery (max ${max_wait}s)..." >> "${REPORT_FILE}"
  
  while [ ${waited} -lt ${max_wait} ]; do
    # Check if services are running
    if check_node_services; then
      # Check sync status
      if check_execution_sync && check_consensus_sync; then
        echo -e "${GREEN}✓ Node recovered successfully after ${waited} seconds${NC}"
        echo "✓ Node recovered successfully after ${waited} seconds" >> "${REPORT_FILE}"
        return 0
      fi
    fi
    
    # Wait and increment counter
    sleep ${wait_interval}
    waited=$((waited + wait_interval))
    echo -e "${YELLOW}Still waiting... (${waited}/${max_wait} seconds)${NC}"
  done
  
  echo -e "${RED}✗ Node failed to recover within ${max_wait} seconds${NC}"
  echo "✗ Node failed to recover within ${max_wait} seconds" >> "${REPORT_FILE}"
  return 1
}

# Main test function
run_network_disruption_tests() {
  echo -e "${BLUE}Starting network disruption chaos tests${NC}"
  echo "Starting network disruption chaos tests" >> "${REPORT_FILE}"
  
  # Get primary network interface
  local interface=$(ip route | grep default | awk '{print $5}')
  echo "Using network interface: ${interface}" >> "${REPORT_FILE}"
  
  # Initial check
  if ! check_node_services; then
    echo -e "${RED}✗ Initial node check failed. Cannot proceed with tests.${NC}"
    echo "✗ Initial node check failed. Cannot proceed with tests." >> "${REPORT_FILE}"
    return 1
  fi
  
  # Test 1: High latency
  echo -e "${BLUE}Test 1: High network latency${NC}"
  echo "Test 1: High network latency" >> "${REPORT_FILE}"
  simulate_network_latency "${interface}" 500 60
  wait_for_recovery 120
  
  # Test 2: Packet loss
  echo -e "${BLUE}Test 2: Packet loss${NC}"
  echo "Test 2: Packet loss" >> "${REPORT_FILE}"
  simulate_packet_loss "${interface}" 20 60
  wait_for_recovery 120
  
  # Test 3: P2P port blocking
  echo -e "${BLUE}Test 3: P2P port blocking${NC}"
  echo "Test 3: P2P port blocking" >> "${REPORT_FILE}"
  block_p2p_ports 60
  wait_for_recovery 180
  
  # Final check
  if check_node_services && check_execution_sync && check_consensus_sync; then
    echo -e "${GREEN}✓ All chaos tests completed successfully. Node is resilient.${NC}"
    echo "✓ All chaos tests completed successfully. Node is resilient." >> "${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}✗ Node failed to fully recover after chaos tests.${NC}"
    echo "✗ Node failed to fully recover after chaos tests." >> "${REPORT_FILE}"
    return 1
  fi
}

# Main execution
main() {
  echo -e "${BLUE}Network Disruption Chaos Test${NC}"
  
  # Check prerequisites
  check_prerequisites
  
  # Run the tests
  if run_network_disruption_tests; then
    echo -e "${GREEN}✓ Network disruption tests passed${NC}"
    echo "✓ PASSED: Network disruption tests" >> "${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}✗ Network disruption tests failed${NC}"
    echo "✗ FAILED: Network disruption tests" >> "${REPORT_FILE}"
    return 1
  fi
}

# Run main function
main "$@" 