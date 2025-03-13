#!/bin/bash
#
# Validator Configuration Test Script for Ephemery
# ===============================================
#
# This script tests the validator configuration in the inventory file
# and checks if the validator container is running correctly.
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
INVENTORY_FILE="${INVENTORY_FILE:-${REPO_ROOT}/inventory.yaml}"
VALIDATOR_CONTAINER_NAME="ephemery-validator"

# Default settings
VERBOSE=false
INVENTORY_ONLY=false
CONTAINER_ONLY=false

# Run the configuration tests
function run_tests {
  echo -e "${BLUE}Validator Configuration Test${NC}"
  echo -e "${BLUE}===========================${NC}"

  # Test inventory file
  if [[ "${CONTAINER_ONLY}" != "true" ]]; then
    check_inventory_file
    check_validator_enabled
    check_validator_config
  fi

  # Test validator container
  if [[ "${INVENTORY_ONLY}" != "true" ]]; then
    check_validator_container
    check_validator_keys
  fi

  echo -e "${BLUE}===========================${NC}"
  echo -e "${GREEN}Validator configuration test completed${NC}"
}

# Add integration test command
function run_integration_test {
  echo -e "${BLUE}Running integration tests...${NC}"

  # Pass all arguments to the integration test script
  "${SCRIPT_DIR}/integration_test.sh" "$@"

  return $?
}

# Update the help function to include integration test
function show_help {
  echo -e "${BLUE}Validator Configuration Test${NC}"
  echo ""
  echo "This script tests the validator configuration in the inventory file and checks if the validator container is running correctly."
  echo ""
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  config      Test validator configuration (default)"
  echo "  integration Run integration tests"
  echo ""
  echo "Options for config command:"
  echo "  -i, --inventory FILE       Inventory file to test (default: REPO_ROOT/inventory.yaml)"
  echo "  -c, --container NAME       Validator container name (default: ephemery-validator)"
  echo "  --inventory-only           Only test the inventory file"
  echo "  --container-only           Only test the validator container"
  echo "  -v, --verbose              Enable verbose output"
  echo "  -h, --help                 Show this help message"
  echo ""
  echo "For integration test options, run: $0 integration --help"
}

# Parse command line arguments
function parse_args {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--inventory)
        INVENTORY_FILE="$2"
        shift 2
        ;;
      -c|--container)
        VALIDATOR_CONTAINER_NAME="$2"
        shift 2
        ;;
      --inventory-only)
        INVENTORY_ONLY=true
        shift
        ;;
      --container-only)
        CONTAINER_ONLY=true
        shift
        ;;
      -v|--verbose)
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

# Check if inventory file exists
function check_inventory_file {
  echo -e "${BLUE}Checking inventory file...${NC}"

  if [[ ! -f "${INVENTORY_FILE}" ]]; then
    echo -e "${RED}Error: Inventory file '${INVENTORY_FILE}' does not exist${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Inventory file exists${NC}"
}

# Check if validator is enabled in inventory
function check_validator_enabled {
  echo -e "${BLUE}Checking if validator is enabled in inventory...${NC}"

  # Check if validator_enabled is set to true
  if grep -q "validator_enabled: true" "${INVENTORY_FILE}"; then
    echo -e "${GREEN}✓ Validator is enabled in inventory${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ Validator is not enabled in inventory${NC}"
    return 1
  fi
}

# Check validator configuration in inventory
function check_validator_config {
  echo -e "${BLUE}Checking validator configuration in inventory...${NC}"

  # Check if validator_client is set
  if grep -q "validator_client:" "${INVENTORY_FILE}"; then
    VALIDATOR_CLIENT=$(grep "validator_client:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator client: ${VALIDATOR_CLIENT}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator client not specified in inventory${NC}"
  fi

  # Check if validator_graffiti is set
  if grep -q "validator_graffiti:" "${INVENTORY_FILE}"; then
    VALIDATOR_GRAFFITI=$(grep "validator_graffiti:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator graffiti: ${VALIDATOR_GRAFFITI}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator graffiti not specified in inventory${NC}"
  fi

  # Check if validator_fee_recipient is set
  if grep -q "validator_fee_recipient:" "${INVENTORY_FILE}"; then
    VALIDATOR_FEE_RECIPIENT=$(grep "validator_fee_recipient:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator fee recipient: ${VALIDATOR_FEE_RECIPIENT}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator fee recipient not specified in inventory${NC}"
  fi

  # Check if validator_keys_src is set
  if grep -q "validator_keys_src:" "${INVENTORY_FILE}"; then
    VALIDATOR_KEYS_SRC=$(grep "validator_keys_src:" "${INVENTORY_FILE}" | head -1 | awk -F"'" '{print $2}')
    echo -e "${GREEN}✓ Validator keys source: ${VALIDATOR_KEYS_SRC}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator keys source not specified in inventory${NC}"
  fi

  # Check if validator_expected_key_count is set
  if grep -q "validator_expected_key_count:" "${INVENTORY_FILE}"; then
    VALIDATOR_EXPECTED_KEY_COUNT=$(grep "validator_expected_key_count:" "${INVENTORY_FILE}" | head -1 | awk '{print $2}')
    echo -e "${GREEN}✓ Validator expected key count: ${VALIDATOR_EXPECTED_KEY_COUNT}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator expected key count not specified in inventory${NC}"
  fi

  # Check if validator_memory_limit is set
  if grep -q "validator_memory_limit:" "${INVENTORY_FILE}"; then
    VALIDATOR_MEMORY_LIMIT=$(grep "validator_memory_limit:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator memory limit: ${VALIDATOR_MEMORY_LIMIT}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator memory limit not specified in inventory${NC}"
  fi

  # Check if validator_cpu_limit is set
  if grep -q "validator_cpu_limit:" "${INVENTORY_FILE}"; then
    VALIDATOR_CPU_LIMIT=$(grep "validator_cpu_limit:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator CPU limit: ${VALIDATOR_CPU_LIMIT}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator CPU limit not specified in inventory${NC}"
  fi

  # Check if validator_extra_opts is set
  if grep -q "validator_extra_opts:" "${INVENTORY_FILE}"; then
    VALIDATOR_EXTRA_OPTS=$(grep "validator_extra_opts:" "${INVENTORY_FILE}" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Validator extra options: ${VALIDATOR_EXTRA_OPTS}${NC}"
  else
    echo -e "${YELLOW}⚠ Validator extra options not specified in inventory${NC}"
  fi

  # Check if mev_boost_enabled is set
  if grep -q "mev_boost_enabled:" "${INVENTORY_FILE}"; then
    MEV_BOOST_ENABLED=$(grep "mev_boost_enabled:" "${INVENTORY_FILE}" | head -1 | awk '{print $2}')
    echo -e "${GREEN}✓ MEV-Boost enabled: ${MEV_BOOST_ENABLED}${NC}"
  else
    echo -e "${YELLOW}⚠ MEV-Boost enabled not specified in inventory${NC}"
  fi

  # Show all validator-related settings if verbose
  if [[ "${VERBOSE}" == "true" ]]; then
    echo -e "${BLUE}All validator-related settings in inventory:${NC}"
    grep -i validator "${INVENTORY_FILE}"
  fi
}

# Check if validator container is running
function check_validator_container {
  echo -e "${BLUE}Checking validator container...${NC}"

  if docker ps | grep -q "${VALIDATOR_CONTAINER_NAME}"; then
    echo -e "${GREEN}✓ Validator container is running${NC}"

    # Get container details
    CONTAINER_ID=$(docker ps | grep "${VALIDATOR_CONTAINER_NAME}" | awk '{print $1}')
    CONTAINER_IMAGE=$(docker ps | grep "${VALIDATOR_CONTAINER_NAME}" | awk '{print $2}')
    CONTAINER_STATUS=$(docker ps | grep "${VALIDATOR_CONTAINER_NAME}" | awk '{print $5}')

    echo -e "${GREEN}✓ Container ID: ${CONTAINER_ID}${NC}"
    echo -e "${GREEN}✓ Container image: ${CONTAINER_IMAGE}${NC}"
    echo -e "${GREEN}✓ Container status: ${CONTAINER_STATUS}${NC}"

    # Check container logs for errors
    if docker logs "${VALIDATOR_CONTAINER_NAME}" 2>&1 | grep -i error | tail -5 > /dev/null; then
      echo -e "${YELLOW}⚠ Recent errors found in container logs:${NC}"
      docker logs "${VALIDATOR_CONTAINER_NAME}" 2>&1 | grep -i error | tail -5
    else
      echo -e "${GREEN}✓ No recent errors found in container logs${NC}"
    fi

    # Check container health
    if docker inspect --format='{{.State.Health.Status}}' "${VALIDATOR_CONTAINER_NAME}" 2>/dev/null | grep -q "healthy"; then
      echo -e "${GREEN}✓ Container health: healthy${NC}"
    elif docker inspect --format='{{.State.Health.Status}}' "${VALIDATOR_CONTAINER_NAME}" 2>/dev/null | grep -q "unhealthy"; then
      echo -e "${RED}✗ Container health: unhealthy${NC}"
    else
      echo -e "${YELLOW}⚠ Container health: not available${NC}"
    fi

    # Show container details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
      echo -e "${BLUE}Container details:${NC}"
      docker inspect "${VALIDATOR_CONTAINER_NAME}" | jq '.[0].Config'
    fi

    return 0
  else
    echo -e "${RED}✗ Validator container is not running${NC}"

    # Check if container exists but is not running
    if docker ps -a | grep -q "${VALIDATOR_CONTAINER_NAME}"; then
      echo -e "${YELLOW}⚠ Validator container exists but is not running${NC}"

      # Get container status
      CONTAINER_STATUS=$(docker ps -a | grep "${VALIDATOR_CONTAINER_NAME}" | awk '{print $5}')
      echo -e "${YELLOW}⚠ Container status: ${CONTAINER_STATUS}${NC}"

      # Show last few lines of container logs
      echo -e "${YELLOW}⚠ Last few lines of container logs:${NC}"
      docker logs "${VALIDATOR_CONTAINER_NAME}" --tail 10
    else
      echo -e "${RED}✗ Validator container does not exist${NC}"
    fi

    return 1
  fi
}

# Check validator keys
function check_validator_keys {
  echo -e "${BLUE}Checking validator keys...${NC}"

  # Check if validator container is running
  if ! docker ps | grep -q "${VALIDATOR_CONTAINER_NAME}"; then
    echo -e "${RED}✗ Validator container is not running, cannot check keys${NC}"
    return 1
  fi

  # Check if validator keys exist in container
  if docker exec "${VALIDATOR_CONTAINER_NAME}" ls -la /var/lib/lighthouse/validators/keys/ 2>/dev/null | grep -q ".json"; then
    # Count keys
    KEY_COUNT=$(docker exec "${VALIDATOR_CONTAINER_NAME}" ls -la /var/lib/lighthouse/validators/keys/ 2>/dev/null | grep ".json" | wc -l)
    echo -e "${GREEN}✓ Found ${KEY_COUNT} validator keys in container${NC}"

    # Show key details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
      echo -e "${BLUE}Key details:${NC}"
      docker exec "${VALIDATOR_CONTAINER_NAME}" ls -la /var/lib/lighthouse/validators/keys/ 2>/dev/null | grep ".json"
    fi

    return 0
  else
    echo -e "${RED}✗ No validator keys found in container${NC}"
    return 1
  fi
}

# Main function
function main {
  # Parse command line arguments
  local COMMAND="config"
  local ARGS=()

  # Check if the first argument is a command
  if [[ $# -gt 0 && "$1" != -* ]]; then
    COMMAND="$1"
    shift
  fi

  # Process the command
  case "${COMMAND}" in
    config)
      parse_args "$@"
      run_tests
      ;;
    integration)
      run_integration_test "$@"
      ;;
    help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown command '${COMMAND}'${NC}"
      show_help
      exit 1
      ;;
  esac
}

# Call the main function with all arguments
main "$@"
