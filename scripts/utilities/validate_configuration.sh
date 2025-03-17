#!/bin/bash
# Version: 1.0.0
#
# Configuration Validation Script for Ephemery
# This script checks for configuration consistency and standardization

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/../core/ephemery_config.sh" ]; then
  source "${SCRIPT_DIR}/../core/ephemery_config.sh"
else
  echo "Error: Could not find ephemery_config.sh"
  exit 1
fi

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script settings
VERBOSE=false
SHOW_ALL=false
FIX_ISSUES=false

# Function to show help
show_help() {
  echo -e "${BLUE}Ephemery Configuration Validation Script${NC}"
  echo ""
  echo "This script checks for configuration consistency and standardization."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -v, --verbose       Show detailed information"
  echo "  -a, --all           Show all checks, including passed ones"
  echo "  -f, --fix           Attempt to fix issues automatically"
  echo "  -h, --help          Display this help message"
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -a | --all)
      SHOW_ALL=true
      shift
      ;;
    -f | --fix)
      FIX_ISSUES=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Display script banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Ephemery Configuration Validation    ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Validation result tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILURES=0

# Helper function to print check status
print_check_status() {
  local status=$1
  local message=$2
  local details=$3

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  case ${status} in
    "PASS")
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      if [ "${SHOW_ALL}" = true ]; then
        echo -e "${GREEN}✓ PASS${NC}: ${message}"
        if [ "${VERBOSE}" = true ] && [ ! -z "${details}" ]; then
          echo -e "  ${CYAN}Details:${NC} ${details}"
        fi
      fi
      ;;
    "WARN")
      WARNINGS=$((WARNINGS + 1))
      echo -e "${YELLOW}⚠ WARN${NC}: ${message}"
      if [ ! -z "${details}" ]; then
        echo -e "  ${CYAN}Details:${NC} ${details}"
      fi
      ;;
    "FAIL")
      FAILURES=$((FAILURES + 1))
      echo -e "${RED}✗ FAIL${NC}: ${message}"
      if [ ! -z "${details}" ]; then
        echo -e "  ${CYAN}Details:${NC} ${details}"
      fi
      ;;
  esac
}

# Check 1: Config file existence
echo -e "${BLUE}Checking configuration files...${NC}"
if [ -f "/opt/ephemery/config/ephemery_paths.conf" ]; then
  print_check_status "PASS" "Standardized paths configuration file exists" "/opt/ephemery/config/ephemery_paths.conf"
else
  print_check_status "FAIL" "Standardized paths configuration file not found" "/opt/ephemery/config/ephemery_paths.conf not found"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Creating standardized paths configuration file...${NC}"
    mkdir -p "/opt/ephemery/config"
    # Copy the template config file or create one if it doesn't exist
    if [ -f "${SCRIPT_DIR}/../../config/ephemery_paths.conf" ]; then
      cp "${SCRIPT_DIR}/../../config/ephemery_paths.conf" "/opt/ephemery/config/ephemery_paths.conf"
    else
      echo -e "${RED}Template configuration file not found, cannot create automatically${NC}"
    fi
  fi
fi

# Check 2: Container naming consistency
echo -e "${BLUE}Checking container naming...${NC}"
VALIDATOR_CONTAINER_PATTERN="${NETWORK_NAME:-ephemery}-validator-*"
if docker ps -a | grep -q "ephemery-validator-lighthouse" && docker ps -a | grep -q "${VALIDATOR_CONTAINER_PATTERN}"; then
  print_check_status "WARN" "Inconsistent validator container naming detected" "Found both ephemery-validator-lighthouse and pattern ${VALIDATOR_CONTAINER_PATTERN}"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Cannot automatically rename running containers. Please stop containers and recreate them with standardized names.${NC}"
  fi
elif docker ps -a | grep -q "ephemery-validator-lighthouse"; then
  print_check_status "WARN" "Non-standard validator container name detected" "Found ephemery-validator-lighthouse, recommended name is ${EPHEMERY_VALIDATOR_CONTAINER}"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Cannot automatically rename running containers. Please stop containers and recreate them with standardized names.${NC}"
  fi
else
  print_check_status "PASS" "Validator container naming is consistent" "No inconsistent container names detected"
fi

# Check 3: Checkpoint sync URL configuration
echo -e "${BLUE}Checking checkpoint sync configuration...${NC}"
if [ -f "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}" ]; then
  CHECKPOINT_URL=$(cat "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}")
  print_check_status "PASS" "Checkpoint sync URL file found" "URL: ${CHECKPOINT_URL}"

  # Test the URL
  if curl --connect-timeout 5 --max-time 10 -s "${CHECKPOINT_URL}" >/dev/null; then
    print_check_status "PASS" "Checkpoint sync URL is accessible" "${CHECKPOINT_URL}"
  else
    print_check_status "WARN" "Checkpoint sync URL is not accessible" "${CHECKPOINT_URL}"

    if [ "${FIX_ISSUES}" = true ]; then
      echo -e "${YELLOW}Finding a working checkpoint sync URL...${NC}"
      if type find_best_checkpoint_url &>/dev/null; then
        BEST_URL=$(find_best_checkpoint_url)
        if [ ! -z "${BEST_URL}" ]; then
          echo "${BEST_URL}" >"${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}"
          echo -e "${GREEN}Updated checkpoint sync URL to: ${BEST_URL}${NC}"
        else
          echo -e "${RED}Could not find a working checkpoint sync URL${NC}"
        fi
      else
        echo -e "${RED}find_best_checkpoint_url function not available${NC}"
      fi
    fi
  fi
else
  if [ -f "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" ]; then
    print_check_status "WARN" "Checkpoint sync URL file found at non-standard location" "${EPHEMERY_BASE_DIR}/checkpoint_url.txt"

    if [ "${FIX_ISSUES}" = true ]; then
      echo -e "${YELLOW}Moving checkpoint sync URL file to standard location...${NC}"
      mkdir -p "$(dirname "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}")"
      cp "${EPHEMERY_BASE_DIR}/checkpoint_url.txt" "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}"
      echo -e "${GREEN}Checkpoint sync URL file moved to: ${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}${NC}"
    fi
  else
    print_check_status "FAIL" "No checkpoint sync URL file found" "Expected at ${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}"

    if [ "${FIX_ISSUES}" = true ]; then
      echo -e "${YELLOW}Finding a working checkpoint sync URL...${NC}"
      if type find_best_checkpoint_url &>/dev/null; then
        BEST_URL=$(find_best_checkpoint_url)
        if [ ! -z "${BEST_URL}" ]; then
          mkdir -p "$(dirname "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}")"
          echo "${BEST_URL}" >"${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}"
          echo -e "${GREEN}Created checkpoint sync URL file with URL: ${BEST_URL}${NC}"
        else
          echo -e "${RED}Could not find a working checkpoint sync URL${NC}"
        fi
      else
        echo -e "${RED}find_best_checkpoint_url function not available${NC}"
      fi
    fi
  fi
fi

# Check 4: Validator key paths
echo -e "${BLUE}Checking validator key paths...${NC}"
EXPECTED_KEYS_DIR="${EPHEMERY_VALIDATOR_KEYS_DIR}"
ALTERNATIVE_KEYS_DIR="${EPHEMERY_BASE_DIR}/data/validator-keys"
SECRETS_KEYS_DIR="${EPHEMERY_SECRETS_DIR}/validator/keys"

VALID_PATH=""
if [ -d "${EXPECTED_KEYS_DIR}/validator_keys" ]; then
  VALID_PATH="${EXPECTED_KEYS_DIR}/validator_keys"
  print_check_status "PASS" "Validator keys found at standard path" "${EXPECTED_KEYS_DIR}/validator_keys"
elif [ -d "${ALTERNATIVE_KEYS_DIR}/validator_keys" ]; then
  VALID_PATH="${ALTERNATIVE_KEYS_DIR}/validator_keys"
  print_check_status "WARN" "Validator keys found at alternative path" "${ALTERNATIVE_KEYS_DIR}/validator_keys"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Moving validator keys to standard path...${NC}"
    mkdir -p "${EXPECTED_KEYS_DIR}"
    cp -r "${ALTERNATIVE_KEYS_DIR}/validator_keys" "${EXPECTED_KEYS_DIR}/"
    echo -e "${GREEN}Validator keys moved to standard path: ${EXPECTED_KEYS_DIR}/validator_keys${NC}"
  fi
elif [ -d "${SECRETS_KEYS_DIR}" ]; then
  VALID_PATH="${SECRETS_KEYS_DIR}"
  print_check_status "WARN" "Validator keys found at secrets path" "${SECRETS_KEYS_DIR}"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Moving validator keys to standard path...${NC}"
    mkdir -p "${EXPECTED_KEYS_DIR}/validator_keys"
    cp -r "${SECRETS_KEYS_DIR}"/* "${EXPECTED_KEYS_DIR}/validator_keys/"
    echo -e "${GREEN}Validator keys moved to standard path: ${EXPECTED_KEYS_DIR}/validator_keys${NC}"
  fi
else
  print_check_status "FAIL" "No validator keys found at any standard path" "Checked ${EXPECTED_KEYS_DIR}/validator_keys, ${ALTERNATIVE_KEYS_DIR}/validator_keys, ${SECRETS_KEYS_DIR}"
fi

# Validate validator keys if found
if [ ! -z "${VALID_PATH}" ]; then
  KEYSTORE_COUNT=$(find "${VALID_PATH}" -name "keystore-*.json" | wc -l)
  if [ "${KEYSTORE_COUNT}" -gt 0 ]; then
    print_check_status "PASS" "Found ${KEYSTORE_COUNT} validator keystores" "${VALID_PATH}"

    # Validate key integrity if validate_validator_keys function is available
    if type validate_validator_keys &>/dev/null; then
      if validate_validator_keys >/dev/null; then
        print_check_status "PASS" "All validator keys are valid" "${VALID_PATH}"
      else
        print_check_status "WARN" "Some validator keys may be invalid" "Run validate_validator_keys for details"
      fi
    else
      print_check_status "WARN" "Could not validate key integrity" "validate_validator_keys function not available"
    fi
  else
    print_check_status "WARN" "No validator keystores found in keys directory" "${VALID_PATH}"
  fi
fi

# Check 5: Docker networking
echo -e "${BLUE}Checking Docker networking...${NC}"
if docker network ls | grep -q "${EPHEMERY_DOCKER_NETWORK}"; then
  print_check_status "PASS" "Docker network exists" "${EPHEMERY_DOCKER_NETWORK}"
else
  print_check_status "FAIL" "Docker network not found" "${EPHEMERY_DOCKER_NETWORK}"

  if [ "${FIX_ISSUES}" = true ]; then
    echo -e "${YELLOW}Creating Docker network...${NC}"
    docker network create "${EPHEMERY_DOCKER_NETWORK}"
    echo -e "${GREEN}Docker network created: ${EPHEMERY_DOCKER_NETWORK}${NC}"
  fi
fi

# Check 6: Container health
echo -e "${BLUE}Checking container health...${NC}"
if docker ps | grep -q "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; then
  print_check_status "PASS" "Lighthouse container is running" "${EPHEMERY_LIGHTHOUSE_CONTAINER}"
else
  print_check_status "WARN" "Lighthouse container is not running" "${EPHEMERY_LIGHTHOUSE_CONTAINER}"
fi

if docker ps | grep -q "${EPHEMERY_VALIDATOR_CONTAINER}"; then
  print_check_status "PASS" "Validator container is running" "${EPHEMERY_VALIDATOR_CONTAINER}"
else
  print_check_status "WARN" "Validator container is not running" "${EPHEMERY_VALIDATOR_CONTAINER}"
fi

if docker ps | grep -q "${EPHEMERY_GETH_CONTAINER}"; then
  print_check_status "PASS" "Geth container is running" "${EPHEMERY_GETH_CONTAINER}"
else
  print_check_status "WARN" "Geth container is not running" "${EPHEMERY_GETH_CONTAINER}"
fi

# Summary
echo -e "\n${BLUE}Validation Summary:${NC}"
echo -e "${GREEN}Passed: ${PASSED_CHECKS}/${TOTAL_CHECKS}${NC}"
if [ ${WARNINGS} -gt 0 ]; then
  echo -e "${YELLOW}Warnings: ${WARNINGS}${NC}"
fi
if [ ${FAILURES} -gt 0 ]; then
  echo -e "${RED}Failures: ${FAILURES}${NC}"
fi

if [ ${FAILURES} -gt 0 ]; then
  echo -e "\n${RED}Some configuration issues need to be addressed.${NC}"
  if [ "${FIX_ISSUES}" = false ]; then
    echo -e "${YELLOW}Run with --fix option to attempt automatic resolution of issues.${NC}"
  fi
  exit 1
elif [ ${WARNINGS} -gt 0 ]; then
  echo -e "\n${YELLOW}Configuration has warnings but no critical issues.${NC}"
  exit 0
else
  echo -e "\n${GREEN}All configuration checks passed!${NC}"
  exit 0
fi
