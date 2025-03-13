#!/bin/bash
#
# Validator Scripts Integration Test
# ==================================
#
# This script tests the integration of validator management scripts with
# the Ephemery deployment system. It verifies that the scripts work correctly
# in a real environment.
#

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default settings
TEST_ENV="local"
EPHEMERY_BASE_DIR="${HOME}/ephemery-test"
CLEANUP=true
VERBOSE=false

# Help function
function show_help {
  echo -e "${BLUE}Validator Scripts Integration Test${NC}"
  echo ""
  echo "This script tests the integration of validator management scripts with the Ephemery deployment system."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -e, --env ENV             Test environment (local, docker, remote) (default: local)"
  echo "  -d, --dir PATH            Ephemery base directory (default: ~/ephemery-test)"
  echo "  -h, --host HOST           Remote host for testing (required for remote env)"
  echo "  -u, --user USER           SSH user for remote testing (default: root)"
  echo "  -k, --key FILE            SSH key file for remote testing"
  echo "  --no-cleanup              Don't clean up test environment after testing"
  echo "  -v, --verbose             Enable verbose output"
  echo "  --help                    Show this help message"
}

# Parse command line arguments
function parse_args {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        TEST_ENV="$2"
        shift 2
        ;;
      -d|--dir)
        EPHEMERY_BASE_DIR="$2"
        shift 2
        ;;
      -h|--host)
        REMOTE_HOST="$2"
        shift 2
        ;;
      -u|--user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -k|--key)
        REMOTE_KEY="$2"
        shift 2
        ;;
      --no-cleanup)
        CLEANUP=false
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --help)
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

  # Validate arguments
  if [[ "${TEST_ENV}" == "remote" && -z "${REMOTE_HOST}" ]]; then
    echo -e "${RED}Error: Remote host (-h, --host) is required for remote testing${NC}"
    show_help
    exit 1
  fi
}

# Set up test environment
function setup_test_env {
  echo -e "${BLUE}Setting up test environment: ${TEST_ENV}${NC}"

  case "${TEST_ENV}" in
    local)
      setup_local_env
      ;;
    docker)
      setup_docker_env
      ;;
    remote)
      setup_remote_env
      ;;
    *)
      echo -e "${RED}Error: Unknown test environment '${TEST_ENV}'${NC}"
      exit 1
      ;;
  esac
}

# Set up local test environment
function setup_local_env {
  echo -e "${BLUE}Setting up local test environment...${NC}"

  # Create test directories
  mkdir -p "${EPHEMERY_BASE_DIR}"
  mkdir -p "${EPHEMERY_BASE_DIR}/config"
  mkdir -p "${EPHEMERY_BASE_DIR}/scripts"
  mkdir -p "${EPHEMERY_BASE_DIR}/scripts/validator"
  mkdir -p "${EPHEMERY_BASE_DIR}/data"
  mkdir -p "${EPHEMERY_BASE_DIR}/data/validator"
  mkdir -p "${EPHEMERY_BASE_DIR}/logs"

  # Copy validator scripts
  cp "${SCRIPT_DIR}/manage_validator_keys.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"
  cp "${SCRIPT_DIR}/monitor_validator.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"
  cp "${SCRIPT_DIR}/test_validator_config.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"

  # Make scripts executable
  chmod +x "${EPHEMERY_BASE_DIR}/scripts/validator/"*.sh

  # Create test configuration
  cat > "${EPHEMERY_BASE_DIR}/config/ephemery_paths.conf" << EOF
# Ephemery Paths Configuration
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR}"
EPHEMERY_SCRIPTS_DIR="\${EPHEMERY_BASE_DIR}/scripts"
EPHEMERY_DATA_DIR="\${EPHEMERY_BASE_DIR}/data"
EPHEMERY_LOGS_DIR="\${EPHEMERY_BASE_DIR}/logs"
EPHEMERY_CONFIG_DIR="\${EPHEMERY_BASE_DIR}/config"
EOF

  # Create validator monitoring configuration
  cat > "${EPHEMERY_BASE_DIR}/config/validator_monitoring.conf" << EOF
# Validator Monitoring Configuration
BEACON_API="http://localhost:5052"
VALIDATOR_API="http://localhost:5062"
VALIDATOR_METRICS_API="http://localhost:5064/metrics"
ALERT_THRESHOLD="90"
MONITORING_INTERVAL="60"
EOF

  echo -e "${GREEN}✓ Local test environment set up at ${EPHEMERY_BASE_DIR}${NC}"
}

# Set up Docker test environment
function setup_docker_env {
  echo -e "${BLUE}Setting up Docker test environment...${NC}"

  # Create test directories
  mkdir -p "${EPHEMERY_BASE_DIR}"

  # Create Docker Compose file
  cat > "${EPHEMERY_BASE_DIR}/docker-compose.yaml" << EOF
version: '3.8'

services:
  beacon:
    image: pk910/ephemery-lighthouse:latest
    container_name: ephemery-beacon
    command: lighthouse beacon --network ephemery --datadir=/data --http --http-address=0.0.0.0 --metrics --metrics-address=0.0.0.0
    ports:
      - "5052:5052"
      - "5054:5054"
    volumes:
      - ./data/lighthouse:/data
      - ./network:/network
    restart: unless-stopped

  validator:
    image: pk910/ephemery-lighthouse:latest
    container_name: ephemery-validator
    command: lighthouse validator --network ephemery --datadir=/data --beacon-nodes=http://beacon:5052 --metrics --metrics-address=0.0.0.0
    ports:
      - "5062:5062"
      - "5064:5064"
    volumes:
      - ./data/validator:/data
    depends_on:
      - beacon
    restart: unless-stopped
EOF

  # Create directories for Docker volumes
  mkdir -p "${EPHEMERY_BASE_DIR}/data/lighthouse"
  mkdir -p "${EPHEMERY_BASE_DIR}/data/validator"
  mkdir -p "${EPHEMERY_BASE_DIR}/network"
  mkdir -p "${EPHEMERY_BASE_DIR}/scripts/validator"

  # Copy validator scripts
  cp "${SCRIPT_DIR}/manage_validator_keys.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"
  cp "${SCRIPT_DIR}/monitor_validator.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"
  cp "${SCRIPT_DIR}/test_validator_config.sh" "${EPHEMERY_BASE_DIR}/scripts/validator/"

  # Make scripts executable
  chmod +x "${EPHEMERY_BASE_DIR}/scripts/validator/"*.sh

  # Start Docker containers
  echo -e "${BLUE}Starting Docker containers...${NC}"
  (cd "${EPHEMERY_BASE_DIR}" && docker-compose up -d)

  echo -e "${GREEN}✓ Docker test environment set up at ${EPHEMERY_BASE_DIR}${NC}"
}

# Set up remote test environment
function setup_remote_env {
  echo -e "${BLUE}Setting up remote test environment on ${REMOTE_HOST}...${NC}"

  # Build SSH command
  SSH_CMD="ssh"
  if [[ -n "${REMOTE_KEY}" ]]; then
    SSH_CMD="${SSH_CMD} -i ${REMOTE_KEY}"
  fi
  SSH_CMD="${SSH_CMD} ${REMOTE_USER:-root}@${REMOTE_HOST}"

  # Create remote directories
  ${SSH_CMD} "mkdir -p ${EPHEMERY_BASE_DIR}/scripts/validator"
  ${SSH_CMD} "mkdir -p ${EPHEMERY_BASE_DIR}/config"
  ${SSH_CMD} "mkdir -p ${EPHEMERY_BASE_DIR}/data/validator"
  ${SSH_CMD} "mkdir -p ${EPHEMERY_BASE_DIR}/logs"

  # Copy validator scripts
  scp ${REMOTE_KEY:+-i "${REMOTE_KEY}"} "${SCRIPT_DIR}/manage_validator_keys.sh" "${REMOTE_USER:-root}@${REMOTE_HOST}:${EPHEMERY_BASE_DIR}/scripts/validator/"
  scp ${REMOTE_KEY:+-i "${REMOTE_KEY}"} "${SCRIPT_DIR}/monitor_validator.sh" "${REMOTE_USER:-root}@${REMOTE_HOST}:${EPHEMERY_BASE_DIR}/scripts/validator/"
  scp ${REMOTE_KEY:+-i "${REMOTE_KEY}"} "${SCRIPT_DIR}/test_validator_config.sh" "${REMOTE_USER:-root}@${REMOTE_HOST}:${EPHEMERY_BASE_DIR}/scripts/validator/"

  # Make scripts executable
  ${SSH_CMD} "chmod +x ${EPHEMERY_BASE_DIR}/scripts/validator/*.sh"

  # Create configuration files
  ${SSH_CMD} "cat > ${EPHEMERY_BASE_DIR}/config/ephemery_paths.conf << EOF
# Ephemery Paths Configuration
EPHEMERY_BASE_DIR=\"${EPHEMERY_BASE_DIR}\"
EPHEMERY_SCRIPTS_DIR=\"\\\${EPHEMERY_BASE_DIR}/scripts\"
EPHEMERY_DATA_DIR=\"\\\${EPHEMERY_BASE_DIR}/data\"
EPHEMERY_LOGS_DIR=\"\\\${EPHEMERY_BASE_DIR}/logs\"
EPHEMERY_CONFIG_DIR=\"\\\${EPHEMERY_BASE_DIR}/config\"
EOF"

  ${SSH_CMD} "cat > ${EPHEMERY_BASE_DIR}/config/validator_monitoring.conf << EOF
# Validator Monitoring Configuration
BEACON_API=\"http://localhost:5052\"
VALIDATOR_API=\"http://localhost:5062\"
VALIDATOR_METRICS_API=\"http://localhost:5064/metrics\"
ALERT_THRESHOLD=\"90\"
MONITORING_INTERVAL=\"60\"
EOF"

  echo -e "${GREEN}✓ Remote test environment set up on ${REMOTE_HOST}:${EPHEMERY_BASE_DIR}${NC}"
}

# Run tests
function run_tests {
  echo -e "${BLUE}Running integration tests...${NC}"

  # Run tests based on environment
  case "${TEST_ENV}" in
    local)
      run_local_tests
      ;;
    docker)
      run_docker_tests
      ;;
    remote)
      run_remote_tests
      ;;
  esac
}

# Run local tests
function run_local_tests {
  echo -e "${BLUE}Running local tests...${NC}"

  # Test manage_validator_keys.sh
  echo -e "${BLUE}Testing manage_validator_keys.sh...${NC}"
  "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh" --help

  # Generate test keys
  echo -e "${BLUE}Generating test validator keys...${NC}"
  "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh" generate --key-count 1 --network ephemery --client lighthouse --withdrawal 0x0000000000000000000000000000000000000000 --fee-recipient 0x0000000000000000000000000000000000000000 --force

  # List keys
  echo -e "${BLUE}Listing validator keys...${NC}"
  "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh" list

  # Test monitor_validator.sh
  echo -e "${BLUE}Testing monitor_validator.sh...${NC}"
  "${EPHEMERY_BASE_DIR}/scripts/validator/monitor_validator.sh" --help

  # Test test_validator_config.sh
  echo -e "${BLUE}Testing test_validator_config.sh...${NC}"
  "${EPHEMERY_BASE_DIR}/scripts/validator/test_validator_config.sh" --help

  echo -e "${GREEN}✓ Local tests completed${NC}"
}

# Run Docker tests
function run_docker_tests {
  echo -e "${BLUE}Running Docker tests...${NC}"

  # Wait for containers to start
  echo -e "${BLUE}Waiting for containers to start...${NC}"
  sleep 10

  # Check if containers are running
  if ! docker ps | grep -q "ephemery-validator"; then
    echo -e "${RED}Error: Validator container is not running${NC}"
    docker ps
    exit 1
  fi

  # Generate test keys
  echo -e "${BLUE}Generating test validator keys...${NC}"
  (cd "${EPHEMERY_BASE_DIR}" && ./scripts/validator/manage_validator_keys.sh generate --key-count 1 --network ephemery --client lighthouse --withdrawal 0x0000000000000000000000000000000000000000 --fee-recipient 0x0000000000000000000000000000000000000000 --force)

  # Import keys to validator
  echo -e "${BLUE}Importing keys to validator...${NC}"
  docker cp "${EPHEMERY_BASE_DIR}/data/validator/keys" ephemery-validator:/data/
  docker cp "${EPHEMERY_BASE_DIR}/data/validator/secrets" ephemery-validator:/data/

  # Restart validator container
  echo -e "${BLUE}Restarting validator container...${NC}"
  docker restart ephemery-validator
  sleep 5

  # Test monitor_validator.sh
  echo -e "${BLUE}Testing monitor_validator.sh...${NC}"
  (cd "${EPHEMERY_BASE_DIR}" && ./scripts/validator/monitor_validator.sh status)

  echo -e "${GREEN}✓ Docker tests completed${NC}"
}

# Run remote tests
function run_remote_tests {
  echo -e "${BLUE}Running remote tests on ${REMOTE_HOST}...${NC}"

  # Build SSH command
  SSH_CMD="ssh"
  if [[ -n "${REMOTE_KEY}" ]]; then
    SSH_CMD="${SSH_CMD} -i ${REMOTE_KEY}"
  fi
  SSH_CMD="${SSH_CMD} ${REMOTE_USER:-root}@${REMOTE_HOST}"

  # Test manage_validator_keys.sh
  echo -e "${BLUE}Testing manage_validator_keys.sh...${NC}"
  ${SSH_CMD} "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh --help"

  # Generate test keys
  echo -e "${BLUE}Generating test validator keys...${NC}"
  ${SSH_CMD} "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh generate --key-count 1 --network ephemery --client lighthouse --withdrawal 0x0000000000000000000000000000000000000000 --fee-recipient 0x0000000000000000000000000000000000000000 --force"

  # List keys
  echo -e "${BLUE}Listing validator keys...${NC}"
  ${SSH_CMD} "${EPHEMERY_BASE_DIR}/scripts/validator/manage_validator_keys.sh list"

  # Test monitor_validator.sh
  echo -e "${BLUE}Testing monitor_validator.sh...${NC}"
  ${SSH_CMD} "${EPHEMERY_BASE_DIR}/scripts/validator/monitor_validator.sh --help"

  # Test test_validator_config.sh
  echo -e "${BLUE}Testing test_validator_config.sh...${NC}"
  ${SSH_CMD} "${EPHEMERY_BASE_DIR}/scripts/validator/test_validator_config.sh --help"

  echo -e "${GREEN}✓ Remote tests completed${NC}"
}

# Clean up test environment
function cleanup {
  if [[ "${CLEANUP}" != "true" ]]; then
    echo -e "${YELLOW}Skipping cleanup as requested${NC}"
    return 0
  fi

  echo -e "${BLUE}Cleaning up test environment...${NC}"

  case "${TEST_ENV}" in
    local)
      echo -e "${BLUE}Removing local test environment...${NC}"
      rm -rf "${EPHEMERY_BASE_DIR}"
      ;;
    docker)
      echo -e "${BLUE}Stopping Docker containers...${NC}"
      (cd "${EPHEMERY_BASE_DIR}" && docker-compose down)
      echo -e "${BLUE}Removing Docker test environment...${NC}"
      rm -rf "${EPHEMERY_BASE_DIR}"
      ;;
    remote)
      echo -e "${BLUE}Removing remote test environment...${NC}"
      SSH_CMD="ssh"
      if [[ -n "${REMOTE_KEY}" ]]; then
        SSH_CMD="${SSH_CMD} -i ${REMOTE_KEY}"
      fi
      SSH_CMD="${SSH_CMD} ${REMOTE_USER:-root}@${REMOTE_HOST}"
      ${SSH_CMD} "rm -rf ${EPHEMERY_BASE_DIR}"
      ;;
  esac

  echo -e "${GREEN}✓ Test environment cleaned up${NC}"
}

# Main function
function main {
  parse_args "$@"

  # Set up test environment
  setup_test_env

  # Run tests
  run_tests

  # Clean up
  cleanup

  echo -e "${GREEN}✓ All integration tests completed successfully${NC}"
}

# Execute main function
main "$@"
