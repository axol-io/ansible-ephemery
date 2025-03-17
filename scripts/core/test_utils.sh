#!/bin/bash
# Version: 1.0.0
# test_utils.sh - Common utilities for Ephemery test scripts
# This library provides shared functions for all test categories

# Define colors for output
export RED=${RED:-'\033[0;31m'}
export GREEN=${GREEN:-'\033[0;32m'}
export YELLOW=${YELLOW:-'\033[0;33m'}
export BLUE=${BLUE:-'\033[0;34m'}
export PURPLE=${PURPLE:-'\033[0;35m'}
export CYAN=${CYAN:-'\033[0;36m'}
export WHITE=${WHITE:-'\033[0;37m'}
export NC=${NC:-'\033[0m'} # No Color

# Function to validate if required tools are installed
# Usage: check_tools "tool1 tool2 tool3"
check_tools() {
  local required_tools=($1)
  local missing_tools=()
  
  for tool in "${required_tools[@]}"; do
    if ! command -v "${tool}" &> /dev/null; then
      missing_tools+=("${tool}")
    fi
  done
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
    echo "Please install these tools before running this test."
    return 1
  fi
  
  return 0
}

# Function to create a test report file
# Usage: create_report_file "/path/to/file.log" "Test Name"
create_report_file() {
  local report_file=$1
  local test_name=$2
  
  # Create directories if they don't exist
  mkdir -p "$(dirname "${report_file}")"
  
  {
    echo "${test_name} Report"
    echo "$(printf '=%.0s' $(seq 1 ${#test_name}))===="
    echo "Date: $(date)"
    echo "Environment: $(hostname)"
    echo "--------------------------------------------------------"
    echo ""
  } > "${report_file}"
  
  echo "${report_file}"
}

# Function to append a message to a report file
# Usage: report "message" "/path/to/file.log"
report() {
  local message=$1
  local report_file=$2
  
  echo "${message}" >> "${report_file}"
}

# Function to append a test result to a report file
# Usage: report_result "passed" "Test description" "/path/to/file.log"
report_result() {
  local result=$1
  local description=$2
  local report_file=$3
  
  if [[ "${result}" == "passed" ]]; then
    echo "✓ PASSED: ${description}" >> "${report_file}"
  else
    echo "✗ FAILED: ${description}" >> "${report_file}"
  fi
}

# Function to get the current execution client
# Usage: get_execution_client
get_execution_client() {
  # First try to read from inventory or configuration
  if [ -f "/etc/ephemery/config.env" ]; then
    source "/etc/ephemery/config.env"
    if [ -n "${EXECUTION_CLIENT}" ]; then
      echo "${EXECUTION_CLIENT}"
      return 0
    fi
  fi
  
  # Try to detect from running services
  for client in geth besu nethermind erigon; do
    if systemctl is-active --quiet "${client}.service" 2>/dev/null; then
      echo "${client}"
      return 0
    fi
  done
  
  # Default to geth if we can't detect
  echo "geth"
  return 0
}

# Function to get the current consensus client
# Usage: get_consensus_client
get_consensus_client() {
  # First try to read from inventory or configuration
  if [ -f "/etc/ephemery/config.env" ]; then
    source "/etc/ephemery/config.env"
    if [ -n "${CONSENSUS_CLIENT}" ]; then
      echo "${CONSENSUS_CLIENT}"
      return 0
    fi
  fi
  
  # Try to detect from running services
  for client in lighthouse prysm teku nimbus lodestar; do
    if systemctl is-active --quiet "${client}.service" 2>/dev/null; then
      echo "${client}"
      return 0
    fi
  done
  
  # Default to lighthouse if we can't detect
  echo "lighthouse"
  return 0
}

# Function to check if a service is running
# Usage: is_service_running "service_name"
is_service_running() {
  local service_name=$1
  
  if systemctl is-active --quiet "${service_name}.service"; then
    return 0
  else
    return 1
  fi
}

# Function to wait for a condition with timeout
# Usage: wait_for condition_function timeout [check_interval] [description]
wait_for() {
  local condition_func=$1
  local timeout=$2
  local check_interval=${3:-5}  # Default to 5 seconds
  local description=${4:-"condition"}
  local waited=0
  
  echo -e "${BLUE}Waiting for ${description} (timeout: ${timeout}s)...${NC}"
  
  while [ ${waited} -lt ${timeout} ]; do
    if ${condition_func}; then
      echo -e "${GREEN}✓ ${description} met after ${waited}s${NC}"
      return 0
    fi
    
    sleep ${check_interval}
    waited=$((waited + check_interval))
    echo -e "${YELLOW}Still waiting for ${description}... (${waited}/${timeout}s)${NC}"
  done
  
  echo -e "${RED}✗ Timeout waiting for ${description} after ${timeout}s${NC}"
  return 1
}

# Function to check execution client sync status
# Usage: is_execution_synced
is_execution_synced() {
  local execution_client=$(get_execution_client)
  local response
  
  # Check sync status based on client
  case "${execution_client}" in
    geth)
      response=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)
      if [[ "$(echo "${response}" | jq -r '.result')" == "false" ]]; then
        return 0
      fi
      ;;
    besu)
      response=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)
      if [[ "$(echo "${response}" | jq -r '.result')" == "false" ]]; then
        return 0
      fi
      ;;
    nethermind)
      response=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)
      if [[ "$(echo "${response}" | jq -r '.result')" == "false" ]]; then
        return 0
      fi
      ;;
    erigon)
      response=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545)
      if [[ "$(echo "${response}" | jq -r '.result')" == "false" ]]; then
        return 0
      fi
      ;;
  esac
  
  return 1
}

# Function to check consensus client sync status
# Usage: is_consensus_synced
is_consensus_synced() {
  local consensus_client=$(get_consensus_client)
  local response
  
  # Check sync status based on client
  case "${consensus_client}" in
    lighthouse)
      response=$(curl -s http://localhost:5052/lighthouse/syncing)
      if [[ "$(echo "${response}" | jq -r '.is_syncing')" == "false" ]]; then
        return 0
      fi
      ;;
    prysm)
      response=$(curl -s http://localhost:3500/eth/v1alpha1/node/syncing)
      if [[ "$(echo "${response}" | jq -r '.syncing')" == "false" ]]; then
        return 0
      fi
      ;;
    teku)
      response=$(curl -s http://localhost:5051/eth/v1/node/syncing)
      if [[ "$(echo "${response}" | jq -r '.data.is_syncing')" == "false" ]]; then
        return 0
      fi
      ;;
    nimbus)
      response=$(curl -s http://localhost:5052/eth/v1/node/syncing)
      if [[ "$(echo "${response}" | jq -r '.data.is_syncing')" == "false" ]]; then
        return 0
      fi
      ;;
    lodestar)
      response=$(curl -s http://localhost:9596/eth/v1/node/syncing)
      if [[ "$(echo "${response}" | jq -r '.data.is_syncing')" == "false" ]]; then
        return 0
      fi
      ;;
  esac
  
  return 1
}

# Function to get current epoch
# Usage: get_current_epoch
get_current_epoch() {
  local consensus_client=$(get_consensus_client)
  local response
  local slot
  
  # Get epoch based on client
  case "${consensus_client}" in
    lighthouse)
      response=$(curl -s http://localhost:5052/eth/v1/beacon/headers/head)
      slot=$(echo "${response}" | jq -r '.data.header.message.slot')
      ;;
    prysm)
      response=$(curl -s http://localhost:3500/eth/v1alpha1/beacon/chainhead)
      slot=$(echo "${response}" | jq -r '.headSlot')
      ;;
    teku)
      response=$(curl -s http://localhost:5051/eth/v1/beacon/headers/head)
      slot=$(echo "${response}" | jq -r '.data.header.message.slot')
      ;;
    nimbus)
      response=$(curl -s http://localhost:5052/eth/v1/beacon/headers/head)
      slot=$(echo "${response}" | jq -r '.data.header.message.slot')
      ;;
    lodestar)
      response=$(curl -s http://localhost:9596/eth/v1/beacon/headers/head)
      slot=$(echo "${response}" | jq -r '.data.header.message.slot')
      ;;
    *)
      # Default fallback if client is unknown
      echo "0"
      return 0
      ;;
  esac
  
  # Calculate epoch from slot (slot / 32)
  if [[ -n "${slot}" && "${slot}" != "null" ]]; then
    echo $((slot / 32))
  else
    echo "0"
  fi
}

# Function to count active validators
# Usage: count_active_validators
count_active_validators() {
  local consensus_client=$(get_consensus_client)
  local count=0
  
  # Get validator count based on client
  case "${consensus_client}" in
    lighthouse)
      if is_service_running "${consensus_client}-validator"; then
        count=$(curl -s http://localhost:5064/metrics | grep "^process_validator_count" | awk '{print $2}')
      fi
      ;;
    prysm)
      if is_service_running "${consensus_client}-validator"; then
        count=$(curl -s http://localhost:7500/metrics | grep "^validator_count" | awk '{print $2}')
      fi
      ;;
    teku)
      # Teku includes validator in the same process
      count=$(curl -s http://localhost:8008/metrics | grep "^validator_local_validator_count" | awk '{print $2}')
      ;;
    nimbus)
      # Nimbus includes validator in the same process
      count=$(curl -s http://localhost:8008/metrics | grep "^validator_count" | awk '{print $2}')
      ;;
    lodestar)
      if is_service_running "${consensus_client}-validator"; then
        count=$(curl -s http://localhost:5064/metrics | grep "^lodestar_validator_active_total" | awk '{print $2}')
      fi
      ;;
  esac
  
  # Return count or 0 if not found
  if [[ -n "${count}" && "${count}" != "null" ]]; then
    echo "${count}"
  else
    echo "0"
  fi
}

# Function to restart a service
# Usage: restart_service "service_name"
restart_service() {
  local service_name=$1
  
  echo -e "${BLUE}Restarting ${service_name} service...${NC}"
  
  if systemctl is-active --quiet "${service_name}.service"; then
    sudo systemctl restart "${service_name}.service"
    sleep 2
    
    if systemctl is-active --quiet "${service_name}.service"; then
      echo -e "${GREEN}✓ Service ${service_name} restarted successfully${NC}"
      return 0
    else
      echo -e "${RED}✗ Failed to restart service ${service_name}${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}! Service ${service_name} is not running, trying to start it${NC}"
    sudo systemctl start "${service_name}.service"
    sleep 2
    
    if systemctl is-active --quiet "${service_name}.service"; then
      echo -e "${GREEN}✓ Service ${service_name} started successfully${NC}"
      return 0
    else
      echo -e "${RED}✗ Failed to start service ${service_name}${NC}"
      return 1
    fi
  fi
}

# Function to get CPU usage of a process
# Usage: get_cpu_usage "process_name"
get_cpu_usage() {
  local process_name=$1
  local pid
  
  pid=$(pgrep -f "${process_name}" | head -1)
  
  if [[ -n "${pid}" ]]; then
    ps -p "${pid}" -o %cpu | tail -1 | xargs
  else
    echo "0.0"
  fi
}

# Function to get memory usage of a process in MB
# Usage: get_memory_usage "process_name"
get_memory_usage() {
  local process_name=$1
  local pid
  
  pid=$(pgrep -f "${process_name}" | head -1)
  
  if [[ -n "${pid}" ]]; then
    ps -p "${pid}" -o rss | tail -1 | xargs | awk '{print $1/1024}'
  else
    echo "0.0"
  fi
}

# Function to check if a TCP port is open
# Usage: is_port_open "host" "port"
is_port_open() {
  local host=$1
  local port=$2
  
  (echo > /dev/tcp/${host}/${port}) &>/dev/null
  return $?
}

# Function to generate a random string
# Usage: random_string [length]
random_string() {
  local length=${1:-10}
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Function to compare client performance by running a client and tracking metrics
# Usage: benchmark_client "client_name" "duration_seconds"
benchmark_client() {
  local client_name=$1
  local duration=$2
  local sample_interval=5
  local samples=$((duration / sample_interval))
  local cpu_total=0
  local mem_total=0
  
  echo -e "${BLUE}Benchmarking ${client_name} for ${duration} seconds...${NC}"
  
  for ((i=1; i<=samples; i++)); do
    local cpu=$(get_cpu_usage "${client_name}")
    local mem=$(get_memory_usage "${client_name}")
    
    cpu_total=$(echo "${cpu_total} + ${cpu}" | bc)
    mem_total=$(echo "${mem_total} + ${mem}" | bc)
    
    echo -e "${YELLOW}Sample ${i}/${samples}: CPU ${cpu}%, Memory ${mem}MB${NC}"
    sleep ${sample_interval}
  done
  
  local cpu_avg=$(echo "scale=2; ${cpu_total} / ${samples}" | bc)
  local mem_avg=$(echo "scale=2; ${mem_total} / ${samples}" | bc)
  
  echo -e "${GREEN}Benchmark results for ${client_name}:${NC}"
  echo -e "${GREEN}Average CPU: ${cpu_avg}%${NC}"
  echo -e "${GREEN}Average Memory: ${mem_avg}MB${NC}"
  
  # Return results as a comma-separated string
  echo "${cpu_avg},${mem_avg}"
}

# Export functions
export -f check_tools
export -f create_report_file
export -f report
export -f report_result
export -f get_execution_client
export -f get_consensus_client
export -f is_service_running
export -f wait_for
export -f is_execution_synced
export -f is_consensus_synced
export -f get_current_epoch
export -f count_active_validators
export -f restart_service
export -f get_cpu_usage
export -f get_memory_usage
export -f is_port_open
export -f random_string
export -f benchmark_client 