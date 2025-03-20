#!/bin/bash
# Version: 1.0.0
# test_client_performance.sh - Performance benchmarking for Ethereum clients
# This script benchmarks performance metrics for different client combinations

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Source core utilities
source "${PROJECT_ROOT}/scripts/core/path_config.sh"
source "${PROJECT_ROOT}/scripts/core/error_handling.sh"
source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"

# Setup error handling
setup_error_handling

# Test configuration
BENCHMARK_DURATION=900 # 15 minutes
REPORT_FILE="${PROJECT_ROOT}/scripts/testing/reports/performance_benchmark_$(date +%Y%m%d-%H%M%S).log"
METRICS_FILE="${PROJECT_ROOT}/scripts/testing/reports/performance_metrics_$(date +%Y%m%d-%H%M%S).json"

# Create report file
{
  echo "Ethereum Client Performance Benchmark Report"
  echo "==========================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Benchmark Duration: ${BENCHMARK_DURATION} seconds"
  echo "--------------------------------------------------------"
  echo ""
} >"${REPORT_FILE}"

# Function to check prerequisites
check_prerequisites() {
  local missing_tools=()

  for tool in curl jq bc awk grep; do
    if ! command -v "${tool}" &>/dev/null; then
      missing_tools+=("${tool}")
    fi
  done

  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
    echo "Please install these tools before running this test."
    echo "Missing tools: ${missing_tools[*]}" >>"${REPORT_FILE}"
    exit 1
  fi
}

# Function to get system specifications
get_system_specs() {
  echo -e "${BLUE}Gathering system specifications...${NC}"
  echo "System Specifications:" >>"${REPORT_FILE}"

  # CPU information
  local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2 | xargs)
  local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
  echo "CPU: ${cpu_model} (${cpu_cores} cores)" >>"${REPORT_FILE}"

  # Memory information
  local mem_total=$(free -h | grep "Mem:" | awk '{print $2}')
  echo "Memory: ${mem_total}" >>"${REPORT_FILE}"

  # Disk information
  local disk_info=$(df -h / | tail -1 | awk '{print $2 " total, " $4 " available"}')
  echo "Disk: ${disk_info}" >>"${REPORT_FILE}"

  # OS information
  local os_info=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d "=" -f2 | tr -d '"')
  echo "OS: ${os_info}" >>"${REPORT_FILE}"

  # Client versions
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)

  # Get execution client version (example for Geth)
  if [[ "${execution_client}" == "geth" ]]; then
    local exec_version=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' http://localhost:8545 | jq -r '.result')
    echo "Execution Client: ${exec_version}" >>"${REPORT_FILE}"
  fi

  # Get consensus client version (example for Lighthouse)
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    local cons_version=$(curl -s http://localhost:5052/lighthouse/version | jq -r '.version')
    echo "Consensus Client: Lighthouse ${cons_version}" >>"${REPORT_FILE}"
  fi

  echo "" >>"${REPORT_FILE}"
}

# Function to get current client from config
get_execution_client() {
  # Read from inventory or config
  echo "geth" # Replace with actual detection logic
}

get_consensus_client() {
  # Read from inventory or config
  echo "lighthouse" # Replace with actual detection logic
}

# Function to collect CPU usage
collect_cpu_usage() {
  local execution_client=$1
  local consensus_client=$2

  # Get PIDs
  local exec_pid=$(pgrep -f "${execution_client}" | head -1)
  local cons_pid=$(pgrep -f "${consensus_client}" | head -1)

  # Sample CPU usage
  local exec_cpu=$(ps -p "${exec_pid}" -o %cpu | tail -1 | xargs)
  local cons_cpu=$(ps -p "${cons_pid}" -o %cpu | tail -1 | xargs)

  echo "${exec_cpu},${cons_cpu}"
}

# Function to collect memory usage
collect_memory_usage() {
  local execution_client=$1
  local consensus_client=$2

  # Get PIDs
  local exec_pid=$(pgrep -f "${execution_client}" | head -1)
  local cons_pid=$(pgrep -f "${consensus_client}" | head -1)

  # Sample memory usage in MB
  local exec_mem=$(ps -p "${exec_pid}" -o rss | tail -1 | xargs | awk '{print $1/1024}')
  local cons_mem=$(ps -p "${cons_pid}" -o rss | tail -1 | xargs | awk '{print $1/1024}')

  echo "${exec_mem},${cons_mem}"
}

# Function to collect disk I/O
collect_disk_io() {
  local execution_client=$1
  local consensus_client=$2

  # Get PIDs
  local exec_pid=$(pgrep -f "${execution_client}" | head -1)
  local cons_pid=$(pgrep -f "${consensus_client}" | head -1)

  # Sample disk I/O (note: this is very system-specific and may need adjustment)
  local exec_io=$(ionice -p "${exec_pid}" 2>&1 | grep -o "class.*" || echo "unknown")
  local cons_io=$(ionice -p "${cons_pid}" 2>&1 | grep -o "class.*" || echo "unknown")

  echo "${exec_io},${cons_io}"
}

# Function to collect network metrics
collect_network_metrics() {
  local execution_client=$1
  local consensus_client=$2

  # Get peers (example for Geth)
  local exec_peers=0
  if [[ "${execution_client}" == "geth" ]]; then
    exec_peers=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545 | jq -r '.result' | sed 's/0x//')
    exec_peers=$((16#${exec_peers})) # Convert hex to decimal
  fi

  # Get peers (example for Lighthouse)
  local cons_peers=0
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    cons_peers=$(curl -s http://localhost:5052/eth/v1/node/peers | jq '.data | length')
  fi

  echo "${exec_peers},${cons_peers}"
}

# Function to collect RPC response times
collect_rpc_response_times() {
  local start_time
  local end_time
  local total_time

  # Execution client RPC response time
  start_time=$(date +%s.%N)
  curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 >/dev/null
  end_time=$(date +%s.%N)
  local exec_time=$(echo "${end_time} - ${start_time}" | bc)

  # Consensus client API response time
  start_time=$(date +%s.%N)
  curl -s http://localhost:5052/eth/v1/node/identity >/dev/null
  end_time=$(date +%s.%N)
  local cons_time=$(echo "${end_time} - ${start_time}" | bc)

  echo "${exec_time},${cons_time}"
}

# Function to collect sync speed metrics
collect_sync_metrics() {
  local execution_client=$1
  local consensus_client=$2

  # Get current block (example for Geth)
  local current_block=0
  if [[ "${execution_client}" == "geth" ]]; then
    current_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | jq -r '.result' | sed 's/0x//')
    current_block=$((16#${current_block})) # Convert hex to decimal
  fi

  # Get current slot (example for Lighthouse)
  local current_slot=0
  if [[ "${consensus_client}" == "lighthouse" ]]; then
    current_slot=$(curl -s http://localhost:5052/eth/v1/beacon/headers/head | jq '.data.header.message.slot')
  fi

  echo "${current_block},${current_slot}"
}

# Function to run the benchmark
run_benchmark() {
  local execution_client=$(get_execution_client)
  local consensus_client=$(get_consensus_client)

  echo -e "${BLUE}Starting performance benchmark...${NC}"
  echo "Starting performance benchmark with ${execution_client} + ${consensus_client}" >>"${REPORT_FILE}"

  # Initialize metrics arrays
  local cpu_metrics=()
  local memory_metrics=()
  local network_metrics=()
  local response_metrics=()
  local sync_metrics=()

  # Record start sync metrics
  local start_sync=$(collect_sync_metrics "${execution_client}" "${consensus_client}")
  local start_block=$(echo "${start_sync}" | cut -d "," -f1)
  local start_slot=$(echo "${start_sync}" | cut -d "," -f2)

  # Sample metrics every 30 seconds
  local sample_interval=30
  local samples=$((BENCHMARK_DURATION / sample_interval))
  local completed_samples=0

  echo "Taking ${samples} samples at ${sample_interval} second intervals" >>"${REPORT_FILE}"
  echo -e "${BLUE}Taking ${samples} samples at ${sample_interval} second intervals...${NC}"

  for ((i = 1; i <= samples; i++)); do
    echo -e "${YELLOW}Sample ${i}/${samples}...${NC}"

    # Collect metrics
    local cpu=$(collect_cpu_usage "${execution_client}" "${consensus_client}")
    local memory=$(collect_memory_usage "${execution_client}" "${consensus_client}")
    local network=$(collect_network_metrics "${execution_client}" "${consensus_client}")
    local response=$(collect_rpc_response_times)
    local sync=$(collect_sync_metrics "${execution_client}" "${consensus_client}")

    # Store metrics
    cpu_metrics+=("${cpu}")
    memory_metrics+=("${memory}")
    network_metrics+=("${network}")
    response_metrics+=("${response}")
    sync_metrics+=("${sync}")

    completed_samples=$i

    # Wait for next sample
    sleep ${sample_interval}
  done

  # Record end sync metrics
  local end_sync=$(collect_sync_metrics "${execution_client}" "${consensus_client}")
  local end_block=$(echo "${end_sync}" | cut -d "," -f1)
  local end_slot=$(echo "${end_sync}" | cut -d "," -f2)

  # Calculate sync speed
  local block_progress=$((end_block - start_block))
  local slot_progress=$((end_slot - start_slot))
  local elapsed_time=$((completed_samples * sample_interval))

  local blocks_per_minute=$(echo "scale=2; ${block_progress} * 60 / ${elapsed_time}" | bc)
  local slots_per_minute=$(echo "scale=2; ${slot_progress} * 60 / ${elapsed_time}" | bc)

  # Calculate averages
  local avg_exec_cpu=0
  local avg_cons_cpu=0
  local avg_exec_mem=0
  local avg_cons_mem=0
  local avg_exec_peers=0
  local avg_cons_peers=0
  local avg_exec_response=0
  local avg_cons_response=0

  for cpu in "${cpu_metrics[@]}"; do
    avg_exec_cpu=$(echo "${avg_exec_cpu} + $(echo "${cpu}" | cut -d "," -f1)" | bc)
    avg_cons_cpu=$(echo "${avg_cons_cpu} + $(echo "${cpu}" | cut -d "," -f2)" | bc)
  done

  for mem in "${memory_metrics[@]}"; do
    avg_exec_mem=$(echo "${avg_exec_mem} + $(echo "${mem}" | cut -d "," -f1)" | bc)
    avg_cons_mem=$(echo "${avg_cons_mem} + $(echo "${mem}" | cut -d "," -f2)" | bc)
  done

  for net in "${network_metrics[@]}"; do
    avg_exec_peers=$(echo "${avg_exec_peers} + $(echo "${net}" | cut -d "," -f1)" | bc)
    avg_cons_peers=$(echo "${avg_cons_peers} + $(echo "${net}" | cut -d "," -f2)" | bc)
  done

  for resp in "${response_metrics[@]}"; do
    avg_exec_response=$(echo "${avg_exec_response} + $(echo "${resp}" | cut -d "," -f1)" | bc)
    avg_cons_response=$(echo "${avg_cons_response} + $(echo "${resp}" | cut -d "," -f2)" | bc)
  done

  avg_exec_cpu=$(echo "scale=2; ${avg_exec_cpu} / ${completed_samples}" | bc)
  avg_cons_cpu=$(echo "scale=2; ${avg_cons_cpu} / ${completed_samples}" | bc)
  avg_exec_mem=$(echo "scale=2; ${avg_exec_mem} / ${completed_samples}" | bc)
  avg_cons_mem=$(echo "scale=2; ${avg_cons_mem} / ${completed_samples}" | bc)
  avg_exec_peers=$(echo "scale=2; ${avg_exec_peers} / ${completed_samples}" | bc)
  avg_cons_peers=$(echo "scale=2; ${avg_cons_peers} / ${completed_samples}" | bc)
  avg_exec_response=$(echo "scale=4; ${avg_exec_response} / ${completed_samples}" | bc)
  avg_cons_response=$(echo "scale=4; ${avg_cons_response} / ${completed_samples}" | bc)

  # Write results to report
  {
    echo "Performance Results:"
    echo "-------------------"
    echo "Execution Client (${execution_client}):"
    echo "  Average CPU Usage: ${avg_exec_cpu}%"
    echo "  Average Memory Usage: ${avg_exec_mem} MB"
    echo "  Average Peer Count: ${avg_exec_peers}"
    echo "  Average RPC Response Time: ${avg_exec_response} seconds"
    echo "  Block Progress: ${block_progress} blocks"
    echo "  Blocks Per Minute: ${blocks_per_minute}"
    echo ""
    echo "Consensus Client (${consensus_client}):"
    echo "  Average CPU Usage: ${avg_cons_cpu}%"
    echo "  Average Memory Usage: ${avg_cons_mem} MB"
    echo "  Average Peer Count: ${avg_cons_peers}"
    echo "  Average API Response Time: ${avg_cons_response} seconds"
    echo "  Slot Progress: ${slot_progress} slots"
    echo "  Slots Per Minute: ${slots_per_minute}"
    echo ""
    echo "Benchmark Duration: ${elapsed_time} seconds"
  } >>"${REPORT_FILE}"

  # Create JSON metrics file for later analysis
  cat >"${METRICS_FILE}" <<EOF
{
  "benchmark": {
    "date": "$(date)",
    "duration": ${elapsed_time},
    "execution_client": "${execution_client}",
    "consensus_client": "${consensus_client}"
  },
  "execution_metrics": {
    "avg_cpu": ${avg_exec_cpu},
    "avg_memory": ${avg_exec_mem},
    "avg_peers": ${avg_exec_peers},
    "avg_response_time": ${avg_exec_response},
    "block_progress": ${block_progress},
    "blocks_per_minute": ${blocks_per_minute}
  },
  "consensus_metrics": {
    "avg_cpu": ${avg_cons_cpu},
    "avg_memory": ${avg_cons_mem},
    "avg_peers": ${avg_cons_peers},
    "avg_response_time": ${avg_cons_response},
    "slot_progress": ${slot_progress},
    "slots_per_minute": ${slots_per_minute}
  }
}
EOF

  echo -e "${GREEN}Benchmark completed. Results saved to ${REPORT_FILE}${NC}"
  echo -e "${GREEN}Metrics saved to ${METRICS_FILE}${NC}"

  return 0
}

# Main function
main() {
  echo -e "${BLUE}Ethereum Client Performance Benchmark${NC}"

  # Check prerequisites
  check_prerequisites

  # Get system specs
  get_system_specs

  # Run the benchmark
  if run_benchmark; then
    echo -e "${GREEN}✓ Performance benchmark completed successfully${NC}"
    echo "✓ PASSED: Performance benchmark" >>"${REPORT_FILE}"
    return 0
  else
    echo -e "${RED}✗ Performance benchmark failed${NC}"
    echo "✗ FAILED: Performance benchmark" >>"${REPORT_FILE}"
    return 1
  fi
}

# Run main function
main "$@"
