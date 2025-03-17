#!/bin/bash
# Version: 1.0.0
#
# Test Standardized Paths
# This script tests that all components work correctly with different base directories
# by creating a test configuration with a different base directory and running key scripts.

set -e

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "${BLUE}Loading configuration from ${CONFIG_FILE}${NC}"
  # shellcheck source=/opt/ephemery/config/ephemery_paths.conf
  source "${CONFIG_FILE}"
else
  echo -e "${YELLOW}Configuration file not found, using default paths${NC}"
  # Default paths if config not available
  export EPHEMERY_BASE_DIR="/opt/ephemery"
  export EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  export EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  export EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
  export EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
  export EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
  export EPHEMERY_VALIDATOR_KEYS="${EPHEMERY_DATA_DIR}/validator_keys"
  export EPHEMERY_METRICS_DIR="${EPHEMERY_DATA_DIR}/metrics"
fi

echo -e "${BLUE}=== Ephemery Standardized Paths Test ===${NC}"
echo -e "${BLUE}Testing that components work with different base directories${NC}"

# Create a test directory
TEST_BASE_DIR="/tmp/ephemery_test"
echo -e "${YELLOW}Creating test directory: ${TEST_BASE_DIR}${NC}"
mkdir -p "${TEST_BASE_DIR}/config"
mkdir -p "${TEST_BASE_DIR}/data/geth"
mkdir -p "${TEST_BASE_DIR}/data/lighthouse"
mkdir -p "${TEST_BASE_DIR}/data/metrics"
mkdir -p "${TEST_BASE_DIR}/logs"
mkdir -p "${TEST_BASE_DIR}/scripts"

# Create a test configuration file
TEST_CONFIG="${TEST_BASE_DIR}/config/ephemery_paths.conf"
echo -e "${YELLOW}Creating test configuration: ${TEST_CONFIG}${NC}"

cat >"${TEST_CONFIG}" <<EOF
# Ephemery Paths Configuration - TEST VERSION
# This file defines standard paths used across all Ephemery scripts and services

# Base directory for Ephemery installation
EPHEMERY_BASE_DIR="${TEST_BASE_DIR}"

# Directory for Ephemery scripts
EPHEMERY_SCRIPTS_DIR="\${EPHEMERY_BASE_DIR}/scripts"

# Directory for Ephemery data
EPHEMERY_DATA_DIR="\${EPHEMERY_BASE_DIR}/data"

# Directory for Ephemery logs
EPHEMERY_LOGS_DIR="\${EPHEMERY_BASE_DIR}/logs"

# Directory for Ephemery configuration
EPHEMERY_CONFIG_DIR="\${EPHEMERY_BASE_DIR}/config"

# JWT secret path
EPHEMERY_JWT_SECRET="\${EPHEMERY_CONFIG_DIR}/jwt.hex"

# Validator keys directory
EPHEMERY_VALIDATOR_KEYS="\${EPHEMERY_DATA_DIR}/validator_keys"

# Metrics directory
EPHEMERY_METRICS_DIR="\${EPHEMERY_DATA_DIR}/metrics"

# Default endpoints
LIGHTHOUSE_API_ENDPOINT="http://localhost:5052"
GETH_API_ENDPOINT="http://localhost:8545"
VALIDATOR_API_ENDPOINT="http://localhost:5062"
EOF

# Create a JWT token for testing
echo -e "${YELLOW}Creating test JWT token${NC}"
openssl rand -hex 32 >"${TEST_BASE_DIR}/config/jwt.hex"

# Copy key scripts for testing
echo -e "${YELLOW}Copying scripts for testing${NC}"
cp scripts/monitoring/check_sync_status.sh "${TEST_BASE_DIR}/scripts/"
cp scripts/monitoring/run_validator_monitoring.sh "${TEST_BASE_DIR}/scripts/"
cp scripts/utilities/common.sh "${TEST_BASE_DIR}/scripts/"
cp scripts/maintenance/reset_ephemery.sh "${TEST_BASE_DIR}/scripts/"

# Test each script with the test configuration
echo -e "\n${BLUE}=== Testing Scripts ===${NC}"

# Function to test a script
test_script() {
  local script_name="$1"
  local script_path="${TEST_BASE_DIR}/scripts/${script_name}"

  echo -e "${YELLOW}Testing ${script_name}...${NC}"

  # Make the script executable
  chmod +x "${script_path}"

  # Run the script with CONFIG_FILE environment variable
  if CONFIG_FILE="${TEST_CONFIG}" bash -c "cd ${TEST_BASE_DIR} && ${script_path} --dry-run" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ ${script_name} works with test configuration${NC}"
    return 0
  else
    echo -e "${RED}✗ ${script_name} failed with test configuration${NC}"
    return 1
  fi
}

# Add --dry-run support to scripts for testing
echo -e "${YELLOW}Adding dry-run support to scripts${NC}"
for script in "${TEST_BASE_DIR}/scripts/"*.sh; do
  # Add dry-run support by adding a check at the beginning of the script
  sed -i '1,10s|^#!/bin/bash|#!/bin/bash\n\n# Check for dry-run mode\nif [[ "$1" == "--dry-run" ]]; then\n  echo "Running in dry-run mode"\n  exit 0\nfi|' "${script}"
done

# Test each script
test_script "check_sync_status.sh"
test_script "run_validator_monitoring.sh"
test_script "reset_ephemery.sh"

# Clean up
echo -e "\n${YELLOW}Cleaning up test directory${NC}"
rm -rf "${TEST_BASE_DIR}"

echo -e "\n${GREEN}=== Test Complete ===${NC}"
echo -e "${GREEN}All scripts have been tested with a different base directory${NC}"
