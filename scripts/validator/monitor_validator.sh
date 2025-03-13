#!/bin/bash
#
# Validator Monitoring Integration Script for Ephemery
# ===================================================
#
# This script provides a unified interface for monitoring validators in Ephemery nodes.
# It integrates with the existing monitoring scripts and provides a simple interface
# for checking validator status, performance, and health.
#

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default paths
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR:-${HOME}/ephemery}"
MONITORING_DIR="${EPHEMERY_BASE_DIR}/data/monitoring"
VALIDATOR_METRICS_DIR="${MONITORING_DIR}/validator"
LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"

# Default settings
BEACON_API="http://localhost:5052"
VALIDATOR_API="http://localhost:5062"
VALIDATOR_METRICS_API="http://localhost:5064/metrics"
DASHBOARD=false
VERBOSE=false
CONTINUOUS=false
INTERVAL=60
ALERT_THRESHOLD=90
OPERATION="status"

# Help function
function show_help {
  echo -e "${BLUE}Validator Monitoring Integration for Ephemery${NC}"
  echo ""
  echo "This script provides a unified interface for monitoring validators in Ephemery nodes."
  echo ""
  echo "Usage: $0 [operation] [options]"
  echo ""
  echo "Operations:"
  echo "  status       Show current validator status (default)"
  echo "  performance  Show validator performance metrics"
  echo "  health       Check validator health"
  echo "  dashboard    Show live dashboard"
  echo ""
  echo "Options:"
  echo "  -b, --beacon-api URL     Beacon API URL (default: ${BEACON_API})"
  echo "  -v, --validator-api URL  Validator API URL (default: ${VALIDATOR_API})"
  echo "  -m, --metrics-api URL    Validator metrics API URL (default: ${VALIDATOR_METRICS_API})"
  echo "  -c, --continuous         Enable continuous monitoring"
  echo "  -i, --interval SEC       Monitoring interval in seconds (default: ${INTERVAL})"
  echo "  -t, --threshold NUM      Alert threshold percentage (default: ${ALERT_THRESHOLD})"
  echo "  --verbose                Enable verbose output"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 status"
  echo "  $0 performance --verbose"
  echo "  $0 health --threshold 95"
  echo "  $0 dashboard --continuous --interval 30"
}

# Parse command line arguments
function parse_args {
  if [[ $# -gt 0 ]]; then
    # First argument might be an operation
    case "$1" in
      status|performance|health|dashboard)
        OPERATION="$1"
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
    esac
  fi

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--beacon-api)
        BEACON_API="$2"
        shift 2
        ;;
      -v|--validator-api)
        VALIDATOR_API="$2"
        shift 2
        ;;
      -m|--metrics-api)
        VALIDATOR_METRICS_API="$2"
        shift 2
        ;;
      -c|--continuous)
        CONTINUOUS=true
        shift
        ;;
      -i|--interval)
        INTERVAL="$2"
        shift 2
        ;;
      -t|--threshold)
        ALERT_THRESHOLD="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Ensure required directories exist
function ensure_directories {
  mkdir -p "${MONITORING_DIR}"
  mkdir -p "${VALIDATOR_METRICS_DIR}"
  mkdir -p "${LOGS_DIR}"
}

# Check if validator container is running
function check_validator_container {
  if docker ps | grep -q "ephemery-validator"; then
    echo -e "${GREEN}✓ Validator container is running${NC}"
    return 0
  else
    echo -e "${RED}✗ Validator container is not running${NC}"
    return 1
  fi
}

# Get validator status
function get_validator_status {
  echo -e "${BLUE}Checking validator status...${NC}"
  
  # Check if validator container is running
  check_validator_container
  
  # Get validator metrics
  echo -e "${BLUE}Validator metrics:${NC}"
  if curl -s "${VALIDATOR_METRICS_API}" > /dev/null; then
    # Extract key metrics
    ACTIVE_VALIDATORS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_active | grep -v process | awk '{print $2}')
    TOTAL_VALIDATORS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_total | grep -v process | awk '{print $2}')
    
    if [[ -n "${ACTIVE_VALIDATORS}" && -n "${TOTAL_VALIDATORS}" ]]; then
      echo -e "${GREEN}Active validators: ${ACTIVE_VALIDATORS}${NC}"
      echo -e "${GREEN}Total validators: ${TOTAL_VALIDATORS}${NC}"
      
      # Calculate percentage
      if [[ "${TOTAL_VALIDATORS}" -gt 0 ]]; then
        PERCENTAGE=$(echo "scale=2; ${ACTIVE_VALIDATORS} * 100 / ${TOTAL_VALIDATORS}" | bc)
        echo -e "${GREEN}Active percentage: ${PERCENTAGE}%${NC}"
      fi
    else
      echo -e "${YELLOW}Could not extract validator counts from metrics${NC}"
    fi
    
    # Show more detailed metrics if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
      echo -e "${BLUE}Detailed metrics:${NC}"
      curl -s "${VALIDATOR_METRICS_API}" | grep -i validator | sort
    fi
  else
    echo -e "${RED}Could not connect to validator metrics API at ${VALIDATOR_METRICS_API}${NC}"
  fi
  
  # Check beacon node sync status
  echo -e "\n${BLUE}Beacon node sync status:${NC}"
  if curl -s "${BEACON_API}/eth/v1/node/syncing" > /dev/null; then
    SYNC_STATUS=$(curl -s "${BEACON_API}/eth/v1/node/syncing")
    IS_SYNCING=$(echo "${SYNC_STATUS}" | jq -r '.data.is_syncing')
    
    if [[ "${IS_SYNCING}" == "false" ]]; then
      echo -e "${GREEN}Beacon node is fully synced${NC}"
    else
      SYNC_DISTANCE=$(echo "${SYNC_STATUS}" | jq -r '.data.sync_distance')
      echo -e "${YELLOW}Beacon node is syncing (${SYNC_DISTANCE} slots behind)${NC}"
    fi
  else
    echo -e "${RED}Could not connect to beacon API at ${BEACON_API}${NC}"
  fi
}

# Get validator performance
function get_validator_performance {
  echo -e "${BLUE}Checking validator performance...${NC}"
  
  # Use advanced_validator_monitoring.sh if available
  ADVANCED_MONITORING="${REPO_ROOT}/scripts/monitoring/advanced_validator_monitoring.sh"
  if [[ -f "${ADVANCED_MONITORING}" && -x "${ADVANCED_MONITORING}" ]]; then
    echo -e "${BLUE}Using advanced validator monitoring...${NC}"
    
    # Build command
    CMD="${ADVANCED_MONITORING} --validator-api ${VALIDATOR_API} --beacon-api ${BEACON_API}"
    
    if [[ "${VERBOSE}" == "true" ]]; then
      CMD="${CMD} --verbose"
    fi
    
    # Execute command
    eval "${CMD}"
  else
    echo -e "${YELLOW}Advanced validator monitoring script not found at ${ADVANCED_MONITORING}${NC}"
    echo -e "${YELLOW}Using basic performance monitoring...${NC}"
    
    # Basic performance monitoring
    if curl -s "${VALIDATOR_METRICS_API}" > /dev/null; then
      # Extract performance metrics
      ATTESTATION_HITS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_attestation_hits | awk '{print $2}')
      ATTESTATION_MISSES=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_attestation_misses | awk '{print $2}')
      
      if [[ -n "${ATTESTATION_HITS}" && -n "${ATTESTATION_MISSES}" ]]; then
        TOTAL_ATTESTATIONS=$((ATTESTATION_HITS + ATTESTATION_MISSES))
        
        echo -e "${GREEN}Attestation hits: ${ATTESTATION_HITS}${NC}"
        echo -e "${GREEN}Attestation misses: ${ATTESTATION_MISSES}${NC}"
        echo -e "${GREEN}Total attestations: ${TOTAL_ATTESTATIONS}${NC}"
        
        # Calculate percentage
        if [[ "${TOTAL_ATTESTATIONS}" -gt 0 ]]; then
          PERCENTAGE=$(echo "scale=2; ${ATTESTATION_HITS} * 100 / ${TOTAL_ATTESTATIONS}" | bc)
          echo -e "${GREEN}Attestation effectiveness: ${PERCENTAGE}%${NC}"
          
          # Check against threshold
          if (( $(echo "${PERCENTAGE} < ${ALERT_THRESHOLD}" | bc -l) )); then
            echo -e "${RED}⚠ Attestation effectiveness below threshold (${ALERT_THRESHOLD}%)${NC}"
          fi
        fi
      else
        echo -e "${YELLOW}Could not extract attestation metrics${NC}"
      fi
    else
      echo -e "${RED}Could not connect to validator metrics API at ${VALIDATOR_METRICS_API}${NC}"
    fi
  fi
}

# Check validator health
function check_validator_health {
  echo -e "${BLUE}Checking validator health...${NC}"
  
  # Check if validator container is running
  if ! check_validator_container; then
    echo -e "${RED}Validator container is not running. Health check failed.${NC}"
    return 1
  fi
  
  # Check if validator is connected to beacon node
  echo -e "${BLUE}Checking connection to beacon node...${NC}"
  if curl -s "${VALIDATOR_API}/lighthouse/health" > /dev/null; then
    HEALTH_STATUS=$(curl -s "${VALIDATOR_API}/lighthouse/health")
    if [[ "${HEALTH_STATUS}" == "OK" ]]; then
      echo -e "${GREEN}✓ Validator is healthy${NC}"
    else
      echo -e "${RED}✗ Validator health check failed: ${HEALTH_STATUS}${NC}"
    fi
  else
    echo -e "${RED}✗ Could not connect to validator API at ${VALIDATOR_API}${NC}"
  fi
  
  # Check validator logs for errors
  echo -e "${BLUE}Checking validator logs for errors...${NC}"
  if docker logs ephemery-validator 2>&1 | grep -i error | tail -5 > /dev/null; then
    echo -e "${YELLOW}⚠ Recent errors found in validator logs:${NC}"
    docker logs ephemery-validator 2>&1 | grep -i error | tail -5
  else
    echo -e "${GREEN}✓ No recent errors found in validator logs${NC}"
  fi
  
  # Check validator metrics for warnings
  echo -e "${BLUE}Checking validator metrics for warnings...${NC}"
  if curl -s "${VALIDATOR_METRICS_API}" | grep -i warning > /dev/null; then
    echo -e "${YELLOW}⚠ Warnings found in validator metrics:${NC}"
    curl -s "${VALIDATOR_METRICS_API}" | grep -i warning
  else
    echo -e "${GREEN}✓ No warnings found in validator metrics${NC}"
  fi
}

# Show dashboard
function show_dashboard {
  echo -e "${BLUE}Validator Dashboard${NC}"
  echo -e "${BLUE}==================${NC}"
  
  # Check if validator container is running
  check_validator_container
  
  # Get validator status
  echo -e "\n${BLUE}Validator Status:${NC}"
  ACTIVE_VALIDATORS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_active | grep -v process | awk '{print $2}')
  TOTAL_VALIDATORS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_total | grep -v process | awk '{print $2}')
  
  if [[ -n "${ACTIVE_VALIDATORS}" && -n "${TOTAL_VALIDATORS}" ]]; then
    echo -e "${GREEN}Active validators: ${ACTIVE_VALIDATORS}/${TOTAL_VALIDATORS}${NC}"
    
    # Calculate percentage
    if [[ "${TOTAL_VALIDATORS}" -gt 0 ]]; then
      PERCENTAGE=$(echo "scale=2; ${ACTIVE_VALIDATORS} * 100 / ${TOTAL_VALIDATORS}" | bc)
      echo -e "${GREEN}Active percentage: ${PERCENTAGE}%${NC}"
    fi
  else
    echo -e "${YELLOW}Could not extract validator counts from metrics${NC}"
  fi
  
  # Get performance metrics
  echo -e "\n${BLUE}Performance Metrics:${NC}"
  ATTESTATION_HITS=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_attestation_hits | awk '{print $2}')
  ATTESTATION_MISSES=$(curl -s "${VALIDATOR_METRICS_API}" | grep -i validator_attestation_misses | awk '{print $2}')
  
  if [[ -n "${ATTESTATION_HITS}" && -n "${ATTESTATION_MISSES}" ]]; then
    TOTAL_ATTESTATIONS=$((ATTESTATION_HITS + ATTESTATION_MISSES))
    
    echo -e "${GREEN}Attestation hits: ${ATTESTATION_HITS}${NC}"
    echo -e "${GREEN}Attestation misses: ${ATTESTATION_MISSES}${NC}"
    
    # Calculate percentage
    if [[ "${TOTAL_ATTESTATIONS}" -gt 0 ]]; then
      PERCENTAGE=$(echo "scale=2; ${ATTESTATION_HITS} * 100 / ${TOTAL_ATTESTATIONS}" | bc)
      echo -e "${GREEN}Attestation effectiveness: ${PERCENTAGE}%${NC}"
      
      # Check against threshold
      if (( $(echo "${PERCENTAGE} < ${ALERT_THRESHOLD}" | bc -l) )); then
        echo -e "${RED}⚠ Attestation effectiveness below threshold (${ALERT_THRESHOLD}%)${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}Could not extract attestation metrics${NC}"
  fi
  
  # Get beacon node sync status
  echo -e "\n${BLUE}Beacon Node Status:${NC}"
  SYNC_STATUS=$(curl -s "${BEACON_API}/eth/v1/node/syncing")
  IS_SYNCING=$(echo "${SYNC_STATUS}" | jq -r '.data.is_syncing')
  
  if [[ "${IS_SYNCING}" == "false" ]]; then
    echo -e "${GREEN}Beacon node is fully synced${NC}"
  else
    SYNC_DISTANCE=$(echo "${SYNC_STATUS}" | jq -r '.data.sync_distance')
    echo -e "${YELLOW}Beacon node is syncing (${SYNC_DISTANCE} slots behind)${NC}"
  fi
  
  # Get system resources
  echo -e "\n${BLUE}System Resources:${NC}"
  VALIDATOR_CPU=$(docker stats ephemery-validator --no-stream --format "{{.CPUPerc}}")
  VALIDATOR_MEM=$(docker stats ephemery-validator --no-stream --format "{{.MemUsage}}")
  
  echo -e "${GREEN}Validator CPU: ${VALIDATOR_CPU}${NC}"
  echo -e "${GREEN}Validator Memory: ${VALIDATOR_MEM}${NC}"
  
  # Show timestamp
  echo -e "\n${BLUE}Last updated: $(date)${NC}"
}

# Main function
function main {
  parse_args "$@"
  ensure_directories
  
  # Execute requested operation
  if [[ "${CONTINUOUS}" == "true" ]]; then
    echo -e "${BLUE}Starting continuous monitoring (interval: ${INTERVAL}s)...${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop${NC}"
    
    while true; do
      clear
      case "${OPERATION}" in
        status)
          get_validator_status
          ;;
        performance)
          get_validator_performance
          ;;
        health)
          check_validator_health
          ;;
        dashboard)
          show_dashboard
          ;;
      esac
      
      echo -e "\n${BLUE}Next update in ${INTERVAL} seconds...${NC}"
      sleep "${INTERVAL}"
    done
  else
    case "${OPERATION}" in
      status)
        get_validator_status
        ;;
      performance)
        get_validator_performance
        ;;
      health)
        check_validator_health
        ;;
      dashboard)
        show_dashboard
        ;;
    esac
  fi
}

# Execute main function
main "$@" 