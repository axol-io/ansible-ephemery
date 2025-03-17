#!/bin/bash
# Version: 1.0.0
#
# Ephemery Deployment Verification Script
# ======================================
#
# This script verifies that an Ephemery deployment is working correctly by
# checking various components and connections.
#

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for better readability in terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_TYPE="local"
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT="22"
INVENTORY_FILE=""
VERBOSE=false

# Show help message
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                  Show this help message"
  echo "  -t, --type TYPE             Deployment type (local|remote), default: local"
  echo "  -H, --host HOST             Remote host (for remote deployment)"
  echo "  -u, --user USER             Remote user (for remote deployment)"
  echo "  -p, --port PORT             SSH port (default: 22)"
  echo "  -i, --inventory FILE        Inventory file for configuration details"
  echo "  -v, --verbose               Enable verbose output"
  echo ""
  echo "Examples:"
  echo "  $0 --type local                   # Verify local deployment"
  echo "  $0 --type remote --host my-server # Verify remote deployment"
  echo ""
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
      -h | --help)
        show_help
        exit 0
        ;;
      -t | --type)
        DEPLOYMENT_TYPE="$2"
        shift 2
        ;;
      -H | --host)
        REMOTE_HOST="$2"
        shift 2
        ;;
      -u | --user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -p | --port)
        REMOTE_PORT="$2"
        shift 2
        ;;
      -i | --inventory)
        INVENTORY_FILE="$2"
        shift 2
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        echo -e "${RED}Error: Unknown option $1${NC}"
        show_help
        exit 1
        ;;
    esac
  done

  # Validate arguments
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    if [[ -z "${REMOTE_HOST}" ]]; then
      echo -e "${RED}Error: Remote host (-H, --host) is required for remote verification${NC}"
      exit 1
    fi

    if [[ -z "${REMOTE_USER}" ]]; then
      # Default to ubuntu
      REMOTE_USER="ubuntu"
    fi
  fi
}

# Run a command locally or remotely
run_cmd() {
  local cmd="$1"
  local description="$2"
  local output

  if [[ "${VERBOSE}" == true ]]; then
    echo -e "${BLUE}Executing: ${cmd}${NC}"
  fi

  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    output=$(eval "${cmd}" 2>&1) || {
      echo -e "${RED}Failed: ${description}${NC}"
      return 1
    }
  else
    output=$(ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "${cmd}" 2>&1) || {
      echo -e "${RED}Failed: ${description}${NC}"
      return 1
    }
  fi

  if [[ "${VERBOSE}" == true ]]; then
    echo -e "${YELLOW}Output: ${output}${NC}"
  fi

  echo -e "${GREEN}✓ ${description}${NC}"
  return 0
}

# Check if docker container is running
check_container() {
  local container_name="$1"

  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    if docker ps | grep -q "${container_name}"; then
      echo -e "${GREEN}✓ Container ${container_name} is running${NC}"
      return 0
    else
      echo -e "${RED}✗ Container ${container_name} is not running${NC}"
      return 1
    fi
  else
    if ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps | grep -q ${container_name}"; then
      echo -e "${GREEN}✓ Container ${container_name} is running${NC}"
      return 0
    else
      echo -e "${RED}✗ Container ${container_name} is not running${NC}"
      return 1
    fi
  fi
}

# Check API connectivity
check_api() {
  local url="$1"
  local description="$2"
  local output

  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    if curl -s "${url}" >/dev/null; then
      echo -e "${GREEN}✓ ${description} is responding${NC}"
      return 0
    else
      echo -e "${RED}✗ ${description} is not responding${NC}"
      return 1
    fi
  else
    if ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "curl -s ${url} > /dev/null"; then
      echo -e "${GREEN}✓ ${description} is responding${NC}"
      return 0
    else
      echo -e "${RED}✗ ${description} is not responding${NC}"
      return 1
    fi
  fi
}

# Verify execution client
verify_execution() {
  echo -e "${BLUE}Verifying execution client...${NC}"

  # Check if execution container is running
  check_container "ephemery-geth"

  # Check if execution API is responding
  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    check_api "http://localhost:8545" "Execution API"
  else
    check_api "http://localhost:8545" "Execution API"
  fi

  # Check if execution client is syncing
  local cmd="curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:8545"
  run_cmd "${cmd}" "Execution sync status check"
}

# Verify consensus client
verify_consensus() {
  echo -e "${BLUE}Verifying consensus client...${NC}"

  # Check if consensus container is running
  check_container "ephemery-lighthouse"

  # Check if consensus API is responding
  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    check_api "http://localhost:5052/eth/v1/node/identity" "Consensus API"
  else
    check_api "http://localhost:5052/eth/v1/node/identity" "Consensus API"
  fi

  # Check if consensus client is syncing
  local cmd="curl -s http://localhost:5052/eth/v1/node/syncing"
  run_cmd "${cmd}" "Consensus sync status check"
}

# Verify validator (if enabled)
verify_validator() {
  echo -e "${BLUE}Verifying validator client...${NC}"

  # Check if validator container is running
  if check_container "ephemery-validator"; then
    # Check if validator API is responding
    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      check_api "http://localhost:5062/lighthouse/validators" "Validator API"
    else
      check_api "http://localhost:5062/lighthouse/validators" "Validator API"
    fi
  else
    echo -e "${YELLOW}Validator not enabled or not running${NC}"
  fi
}

# Verify retention system (if enabled)
verify_retention() {
  echo -e "${BLUE}Verifying Ephemery retention system...${NC}"

  local retention_script="/opt/ephemery/scripts/ephemery_retention.sh"
  local cmd="test -f ${retention_script} && echo 'Retention script exists' || echo 'Retention script not found'"

  run_cmd "${cmd}" "Retention script check"

  # Check if cron job is set up
  cmd="crontab -l | grep -q ephemery_retention && echo 'Cron job exists' || echo 'Cron job not found'"
  run_cmd "${cmd}" "Retention cron job check"
}

# Verify dashboard (if enabled)
verify_dashboard() {
  echo -e "${BLUE}Verifying dashboard...${NC}"

  # Check if dashboard container is running
  if check_container "ephemery-dashboard"; then
    # Check if dashboard is responding
    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      check_api "http://localhost/ephemery-status/" "Dashboard"
    else
      check_api "http://localhost/ephemery-status/" "Dashboard"
    fi
  else
    echo -e "${YELLOW}Dashboard not enabled or not running${NC}"
  fi
}

# Run all verifications
run_verification() {
  echo -e "${BLUE}Starting deployment verification...${NC}"

  # Basic execution and consensus verification
  verify_execution
  verify_consensus

  # Optional component verification
  verify_validator
  verify_retention
  verify_dashboard

  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}       Ephemery Deployment Verification Complete                ${NC}"
  echo -e "${GREEN}================================================================${NC}"
}

# Main function
main() {
  parse_args "$@"
  run_verification
}

# Execute main function
main "$@"
