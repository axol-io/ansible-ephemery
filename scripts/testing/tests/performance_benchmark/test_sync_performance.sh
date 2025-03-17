#!/bin/bash
# Version: 1.0.0
# test_sync_performance.sh - Performance benchmarking tests for Ephemery nodes
# This script measures sync times, resource usage, and throughput of different client combinations
# to provide performance metrics for optimization and comparison.

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
BENCHMARK_DIR="${PROJECT_ROOT}/scripts/testing/reports/benchmarks"
RESULTS_FILE="${BENCHMARK_DIR}/sync_performance_$(date +%Y%m%d-%H%M%S).log"
METRICS_FILE="${BENCHMARK_DIR}/metrics_$(date +%Y%m%d-%H%M%S).csv"
TEST_DURATION=1800  # 30 minutes for sync test
SAMPLE_INTERVAL=60  # 1 minute between resource samples

# Make sure benchmark directory exists
mkdir -p "${BENCHMARK_DIR}"

# Create report header
{
  echo "Ephemery Node Performance Benchmark Report"
  echo "=========================================="
  echo "Date: $(date)"
  echo "Environment: $(hostname)"
  echo "Test duration: ${TEST_DURATION} seconds"
  echo "--------------------------------------------------------"
  echo ""
} > "${RESULTS_FILE}"

# Create metrics CSV header
{
  echo "timestamp,client_combination,cpu_usage,memory_usage,disk_usage,sync_progress,network_in,network_out"
} > "${METRICS_FILE}"

# Function to prepare benchmark environment
prepare_benchmark() {
  local execution_client=$1
  local consensus_client=$2
  
  echo -e "${BLUE}Preparing benchmark for ${execution_client}+${consensus_client}${NC}"
  echo "Preparing benchmark for ${execution_client}+${consensus_client}" >> "${RESULTS_FILE}"
  
  # Create temporary benchmark directory
  local benchmark_instance="${BENCHMARK_DIR}/${execution_client}_${consensus_client}"
  mkdir -p "${benchmark_instance}"
  
  # Create inventory file
  cat > "${benchmark_instance}/inventory.yaml" << EOF
all:
  hosts:
    ephemery_benchmark:
      ansible_connection: local
      execution_client: ${execution_client}
      consensus_client: ${consensus_client}
      validator_client: ${consensus_client}
      network_name: ephemery
      setup_validator: false
      checkpoint_sync_url: https://beaconstate.info
      enable_metrics: true
      enable_watchtower: false
      data_dir: ./data
EOF

  return 0
}

# Function to deploy clients for benchmarking
deploy_clients() {
  local benchmark_instance=$1
  local execution_client=$2
  local consensus_client=$3
  
  echo -e "${BLUE}Deploying ${execution_client}+${consensus_client} for benchmarking${NC}"
  echo "Deploying ${execution_client}+${consensus_client} for benchmarking" >> "${RESULTS_FILE}"
  
  # Run ansible in check mode first
  if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${benchmark_instance}/inventory.yaml" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml" --check; then
    echo "✗ Deployment check failed, skipping benchmark" >> "${RESULTS_FILE}"
    return 1
  fi
  
  # Run actual deployment
  if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${benchmark_instance}/inventory.yaml" "${PROJECT_ROOT}/ansible/playbooks/deploy_ephemery.yaml"; then
    echo "✗ Deployment failed, skipping benchmark" >> "${RESULTS_FILE}"
    return 1
  fi
  
  echo "✓ Deployment successful" >> "${RESULTS_FILE}"
  return 0
}

# Function to collect resource metrics
collect_metrics() {
  local benchmark_instance=$1
  local execution_client=$2
  local consensus_client=$3
  local client_combination="${execution_client}_${consensus_client}"
  
  echo -e "${BLUE}Collecting metrics for ${client_combination}${NC}"
  echo "Collecting metrics for ${client_combination}" >> "${RESULTS_FILE}"
  
  # Get container names
  local execution_container="ephemery_${execution_client}"
  local consensus_container="ephemery_${consensus_client}"
  
  local start_time=$(date +%s)
  local end_time=$((start_time + TEST_DURATION))
  local current_time=${start_time}
  
  echo "Starting metrics collection at $(date)" >> "${RESULTS_FILE}"
  echo "Will run for ${TEST_DURATION} seconds (until $(date -r ${end_time}))" >> "${RESULTS_FILE}"
  
  # Initial sync progress
  local initial_sync_progress=$(docker exec "${consensus_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  echo "Initial sync distance: ${initial_sync_progress}" >> "${RESULTS_FILE}"
  
  # Collect metrics at intervals
  while [ ${current_time} -lt ${end_time} ]; do
    # CPU usage (percentage)
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "${execution_container}" "${consensus_container}" | awk '{s+=$1} END {print s}' | sed 's/%//')
    
    # Memory usage (MB)
    local memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "${execution_container}" "${consensus_container}" | awk '{split($1,a,"/"); s+=a[1]} END {print s}' | sed 's/MiB//')
    
    # Disk usage (GB)
    local disk_usage=$(du -sh "${benchmark_instance}/data" | awk '{print $1}' | sed 's/G//')
    
    # Network I/O (MB)
    local network_in=$(docker stats --no-stream --format "{{.NetIO}}" "${execution_container}" "${consensus_container}" | awk '{split($1,a,"/"); s+=a[1]} END {print s}' | sed 's/MB//')
    local network_out=$(docker stats --no-stream --format "{{.NetIO}}" "${execution_container}" "${consensus_container}" | awk '{split($3,a,"/"); s+=a[1]} END {print s}' | sed 's/MB//')
    
    # Sync progress
    local sync_progress=$(docker exec "${consensus_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
    
    # Log metrics
    echo "$(date +%s),${client_combination},${cpu_usage},${memory_usage},${disk_usage},${sync_progress},${network_in},${network_out}" >> "${METRICS_FILE}"
    
    echo "$(date): CPU: ${cpu_usage}%, Memory: ${memory_usage}MB, Sync: ${sync_progress}" >> "${RESULTS_FILE}"
    
    # Wait for next interval
    sleep ${SAMPLE_INTERVAL}
    current_time=$(date +%s)
  done
  
  # Final sync progress
  local final_sync_progress=$(docker exec "${consensus_container}" curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq -r '.data.sync_distance' 2>/dev/null || echo "N/A")
  
  echo "Final sync distance: ${final_sync_progress}" >> "${RESULTS_FILE}"
  
  # Calculate sync rate if possible
  if [[ ${initial_sync_progress} =~ ^[0-9]+$ ]] && [[ ${final_sync_progress} =~ ^[0-9]+$ ]]; then
    local sync_progress=$((initial_sync_progress - final_sync_progress))
    local sync_rate=$(echo "scale=2; ${sync_progress} / (${TEST_DURATION} / 60)" | bc)
    echo "Sync rate: ${sync_rate} slots per minute" >> "${RESULTS_FILE}"
    
    {
      echo ""
      echo "Performance Summary for ${client_combination}"
      echo "----------------------------------------"
      echo "Sync progress: ${sync_progress} slots in ${TEST_DURATION} seconds"
      echo "Sync rate: ${sync_rate} slots per minute"
      echo "Average CPU usage: $(awk -F, 'BEGIN{s=0;c=0} $2=="'${client_combination}'"{s+=$3;c++} END{print s/c"%"}' "${METRICS_FILE}")"
      echo "Average memory usage: $(awk -F, 'BEGIN{s=0;c=0} $2=="'${client_combination}'"{s+=$4;c++} END{print s/c" MB"}' "${METRICS_FILE}")"
      echo "Final disk usage: ${disk_usage} GB"
      echo ""
    } >> "${RESULTS_FILE}"
  else
    echo "Could not calculate sync rate due to invalid measurements" >> "${RESULTS_FILE}"
  fi
  
  return 0
}

# Function to clean up after benchmark
cleanup_benchmark() {
  local benchmark_instance=$1
  local execution_client=$2
  local consensus_client=$3
  
  echo -e "${BLUE}Cleaning up after benchmark${NC}"
  echo "Cleaning up after benchmark" >> "${RESULTS_FILE}"
  
  # Stop and remove containers
  docker stop "ephemery_${execution_client}" "ephemery_${consensus_client}" || true
  docker rm "ephemery_${execution_client}" "ephemery_${consensus_client}" || true
  
  # Clean up data directory (optional - keep for further analysis)
  # rm -rf "${benchmark_instance}/data"
  
  return 0
}

# Function to benchmark a specific client combination
benchmark_client_combination() {
  local execution_client=$1
  local consensus_client=$2
  
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}Benchmarking: ${execution_client} + ${consensus_client}${NC}"
  echo -e "${BLUE}============================================${NC}"
  
  {
    echo ""
    echo "============================================"
    echo "Benchmarking: ${execution_client} + ${consensus_client}"
    echo "============================================"
    echo ""
  } >> "${RESULTS_FILE}"
  
  # Benchmark instance directory
  local benchmark_instance="${BENCHMARK_DIR}/${execution_client}_${consensus_client}"
  
  # Prepare benchmark environment
  prepare_benchmark "${execution_client}" "${consensus_client}"
  
  # Deploy clients
  if ! deploy_clients "${benchmark_instance}" "${execution_client}" "${consensus_client}"; then
    echo "✗ Deployment failed, skipping benchmark for ${execution_client}+${consensus_client}" | tee -a "${RESULTS_FILE}"
    return 1
  fi
  
  # Collect metrics
  collect_metrics "${benchmark_instance}" "${execution_client}" "${consensus_client}"
  
  # Clean up
  cleanup_benchmark "${benchmark_instance}" "${execution_client}" "${consensus_client}"
  
  echo -e "${GREEN}✓ Benchmark completed for ${execution_client}+${consensus_client}${NC}"
  echo "✓ Benchmark completed for ${execution_client}+${consensus_client}" >> "${RESULTS_FILE}"
  
  return 0
}

# Function to generate performance charts
generate_charts() {
  echo -e "${BLUE}Generating performance charts${NC}"
  echo "Generating performance charts" >> "${RESULTS_FILE}"
  
  # Check if gnuplot is installed
  if ! command -v gnuplot &> /dev/null; then
    echo "⚠️ gnuplot not installed, skipping chart generation" | tee -a "${RESULTS_FILE}"
    return 0
  fi
  
  # Generate CPU usage chart
  cat > "${BENCHMARK_DIR}/cpu_chart.gnuplot" << 'EOF'
set terminal png size 800,600
set output 'cpu_chart.png'
set title 'CPU Usage Over Time'
set xlabel 'Time (minutes)'
set ylabel 'CPU Usage (%)'
set grid
set key outside
plot for [i=0:*] 'metrics.csv' using ($1-STATS_min_x)/60:3 every ::0::0 with lines title columnheader(2)
EOF

  # Generate Memory usage chart
  cat > "${BENCHMARK_DIR}/memory_chart.gnuplot" << 'EOF'
set terminal png size 800,600
set output 'memory_chart.png'
set title 'Memory Usage Over Time'
set xlabel 'Time (minutes)'
set ylabel 'Memory Usage (MB)'
set grid
set key outside
plot for [i=0:*] 'metrics.csv' using ($1-STATS_min_x)/60:4 every ::0::0 with lines title columnheader(2)
EOF

  # Generate Sync progress chart
  cat > "${BENCHMARK_DIR}/sync_chart.gnuplot" << 'EOF'
set terminal png size 800,600
set output 'sync_chart.png'
set title 'Sync Progress Over Time'
set xlabel 'Time (minutes)'
set ylabel 'Sync Distance (slots)'
set grid
set key outside
plot for [i=0:*] 'metrics.csv' using ($1-STATS_min_x)/60:6 every ::0::0 with lines title columnheader(2)
EOF

  # Run gnuplot to generate charts
  cd "${BENCHMARK_DIR}" || return 1
  cp "${METRICS_FILE}" metrics.csv
  
  gnuplot cpu_chart.gnuplot
  gnuplot memory_chart.gnuplot
  gnuplot sync_chart.gnuplot
  
  echo "✓ Performance charts generated in ${BENCHMARK_DIR}" | tee -a "${RESULTS_FILE}"
  
  return 0
}

# Main function
main() {
  echo -e "${BLUE}Starting Ephemery node performance benchmarks${NC}"
  
  # Define client combinations to test
  # For a quick test, we'll use a minimal set of combinations
  COMBINATIONS=(
    "geth lighthouse"
    "nethermind prysm"
    "besu teku"
  )
  
  # Run benchmarks for each combination
  for combination in "${COMBINATIONS[@]}"; do
    read -r exec_client cons_client <<< "${combination}"
    benchmark_client_combination "${exec_client}" "${cons_client}"
  done
  
  # Generate performance comparison charts
  generate_charts
  
  echo -e "${GREEN}All performance benchmarks completed${NC}"
  echo "Complete benchmark results available at: ${RESULTS_FILE}"
  echo "Complete metrics available at: ${METRICS_FILE}"
  
  return 0
}

# Run main function
main "$@" 