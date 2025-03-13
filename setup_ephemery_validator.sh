#!/bin/bash

# Ephemery Validator Setup Script
# This script sets up a Lighthouse validator client for the Ephemery network

# Source common configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/scripts/core/ephemery_config.sh" ]; then
  source "$SCRIPT_DIR/scripts/core/ephemery_config.sh"
else
  # Fallback to local definitions if common config not found
  # Color definitions
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  # Define default settings
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_TARGET_PEERS=100
  EPHEMERY_DOCKER_NETWORK="ephemery-net"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
  EPHEMERY_LIGHTHOUSE_IMAGE="pk910/ephemery-lighthouse:latest"
  EPHEMERY_FEE_RECIPIENT="0x0000000000000000000000000000000000000000"
fi

# Color definitions if not defined by common config
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
RED=${RED:-'\033[0;31m'}
BLUE=${BLUE:-'\033[0;34m'}
NC=${NC:-'\033[0m'}

# Script-specific settings
VALIDATOR_COUNT=0
RESET_DATABASE=false
DEBUG_MODE=false

# Function to show help
show_help() {
  echo -e "${BLUE}Ephemery Validator Setup Script${NC}"
  echo ""
  echo "This script sets up a Lighthouse validator client for the Ephemery network."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --base-dir PATH         Specify a custom base directory (default: ~/ephemery)"
  echo "  --validator-count N     Expected validator count (for verification)"
  echo "  --reset                 Reset validator database before starting"
  echo "  --debug                 Enable debug mode with verbose output"
  echo "  --help                  Display this help message"
  echo ""
}

# Function to log debug messages
debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    echo -e "${BLUE}[DEBUG]${NC} $1"
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    --validator-count)
      VALIDATOR_COUNT="$2"
      shift 2
      ;;
    --reset)
      RESET_DATABASE=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --help)
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

echo -e "${BLUE}Setting up Ephemery validator client...${NC}"
debug_log "EPHEMERY_BASE_DIR: $EPHEMERY_BASE_DIR"
debug_log "VALIDATOR_COUNT: $VALIDATOR_COUNT"
debug_log "RESET_DATABASE: $RESET_DATABASE"

# Verify docker is available
if type verify_docker &>/dev/null; then
  verify_docker || exit 1
else
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in the PATH.${NC}"
    exit 1
  fi

  if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running or current user doesn't have permission.${NC}"
    exit 1
  fi
fi

# Create validator directories
if type ensure_directories &>/dev/null; then
  ensure_directories
else
  mkdir -p ${EPHEMERY_BASE_DIR}/data/lighthouse-validator
  mkdir -p ${EPHEMERY_BASE_DIR}/data/validator-keys
  mkdir -p ${EPHEMERY_BASE_DIR}/secrets/validator-passwords
fi

# Ensure validator-specific directories exist
mkdir -p ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR:-"${EPHEMERY_BASE_DIR}/data/lighthouse-validator"}
mkdir -p ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}
mkdir -p ${EPHEMERY_VALIDATOR_PASSWORDS_DIR:-"${EPHEMERY_BASE_DIR}/secrets/validator-passwords"}

# Ensure Docker network exists
if type ensure_docker_network &>/dev/null; then
  ensure_docker_network
else
  if ! docker network ls | grep -q "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}"; then
    echo -e "${BLUE}Creating Docker network: ${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}${NC}"
    docker network create "${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"}"
  fi
fi

# Check if beacon node is running
if ! docker ps | grep -q ${EPHEMERY_LIGHTHOUSE_CONTAINER:-"ephemery-lighthouse"}; then
    echo -e "${RED}Error: Beacon node (${EPHEMERY_LIGHTHOUSE_CONTAINER:-"ephemery-lighthouse"}) is not running.${NC}"
    echo -e "${YELLOW}Please run setup_ephemery.sh first to start the beacon node.${NC}"
    exit 1
fi

# Check for checkpoint sync status
if [ -f "${EPHEMERY_CHECKPOINT_URL_FILE:-"${EPHEMERY_BASE_DIR}/checkpoint_url.txt"}" ]; then
    CHECKPOINT_URL=$(cat ${EPHEMERY_CHECKPOINT_URL_FILE:-"${EPHEMERY_BASE_DIR}/checkpoint_url.txt"})
    echo -e "${GREEN}Detected checkpoint sync with URL: ${CHECKPOINT_URL}${NC}"
    echo -e "${YELLOW}This will accelerate the beacon node synchronization process.${NC}"

    # Check if the beacon node is synced before proceeding
    echo -e "${BLUE}Checking beacon node sync status...${NC}"
    SYNC_STATUS=$(curl -s http://localhost:${EPHEMERY_LIGHTHOUSE_HTTP_PORT:-5052}/eth/v1/node/syncing)
    IS_SYNCING=$(echo $SYNC_STATUS | grep -o '"is_syncing":true' || true)

    if [ ! -z "$IS_SYNCING" ]; then
        echo -e "${YELLOW}Beacon node is still syncing. Validator duties will be inactive until sync completes.${NC}"
        echo -e "${YELLOW}You can proceed with validator setup, but validators won't be active immediately.${NC}"
        read -p "Continue with validator setup? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Setup aborted by user.${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}Beacon node appears to be synced. Proceeding with validator setup.${NC}"
    fi
else
    echo -e "${YELLOW}No checkpoint sync detected. Beacon node may take longer to synchronize.${NC}"
    echo -e "${YELLOW}Validators won't be active until the beacon node completes synchronization.${NC}"
fi

# Reset database if requested
if [ "$RESET_DATABASE" = true ]; then
    echo -e "${YELLOW}Resetting validator database as requested...${NC}"
    rm -rf ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR:-"${EPHEMERY_BASE_DIR}/data/lighthouse-validator"}/*
    echo -e "${GREEN}Validator database reset complete${NC}"
fi

# Stop and remove any existing validator container
echo -e "${BLUE}Cleaning up any existing validator container...${NC}"
docker stop ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"} 2>/dev/null || true
docker rm ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"} 2>/dev/null || true

# Extract validator keys from zip file if not already extracted
if [ ! -d ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}/validator_keys ]; then
    echo -e "${BLUE}Extracting validator keys...${NC}"
    if [ -f ansible/files/validator_keys/validator_keys.zip ]; then
        echo -e "${GREEN}Found validator_keys.zip file${NC}"
        unzip -o ansible/files/validator_keys/validator_keys.zip -d ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}
        echo -e "${GREEN}Keys extracted to ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}${NC}"
    else
        echo -e "${RED}Error: validator_keys.zip file not found in ansible/files/validator_keys/${NC}"
        echo -e "${YELLOW}Please ensure you have placed your validator keys at ansible/files/validator_keys/validator_keys.zip${NC}"
        echo -e "${YELLOW}If you don't have validator keys yet, you can:${NC}"
        echo -e "1. Generate new validator keys using the Ethereum staking deposit CLI"
        echo -e "2. Download existing keys from a secure backup"
        echo -e "3. Request validator keys from your team if this is a shared environment"
        echo -e "${YELLOW}Once you have your keys, place them at the path above and run this script again.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Validator keys already extracted, skipping extraction${NC}"
fi

# Check that we have keystore files
KEYSTORE_COUNT=$(find ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}/validator_keys -name "keystore-*.json" | wc -l)
if [ $KEYSTORE_COUNT -eq 0 ]; then
    echo -e "${RED}Error: No validator keystore files found in ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}/validator_keys${NC}"
    exit 1
fi
echo -e "${GREEN}Found $KEYSTORE_COUNT validator keystores${NC}"

# Validate keystore files
echo -e "${BLUE}Validating keystore files...${NC}"
for KEYSTORE in $(find ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}/validator_keys -name "keystore-*.json"); do
    if ! jq -e . "$KEYSTORE" &>/dev/null; then
        echo -e "${RED}Error: Invalid keystore file found: $KEYSTORE${NC}"
        echo -e "${YELLOW}The file does not contain valid JSON. Please check your validator keys.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}All keystore files validated successfully${NC}"

# Verify against expected count if provided
if [ $VALIDATOR_COUNT -gt 0 ] && [ $KEYSTORE_COUNT -ne $VALIDATOR_COUNT ]; then
    echo -e "${RED}Warning: Found $KEYSTORE_COUNT validators, but expected $VALIDATOR_COUNT${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup aborted by user.${NC}"
        exit 0
    fi
fi

# Copy the correct password file
echo -e "${BLUE}Setting up password file for validators...${NC}"
VALIDATOR_PASSWORD_DIR=${EPHEMERY_VALIDATOR_PASSWORDS_DIR:-"${EPHEMERY_BASE_DIR}/secrets/validator-passwords"}
mkdir -p $VALIDATOR_PASSWORD_DIR

# Try different possible locations for the password file
PASSWORD_FILE_LOCATIONS=(
    "ansible/files/passwords/validators.txt"
    "${SCRIPT_DIR}/ansible/files/passwords/validators.txt"
    "${EPHEMERY_BASE_DIR}/secrets/validator-passwords/validators-password.txt"
)

PASSWORD_FILE_FOUND=false
for PASSWORD_FILE in "${PASSWORD_FILE_LOCATIONS[@]}"; do
    if [ -f "$PASSWORD_FILE" ]; then
        echo -e "${GREEN}Found validator password file at $PASSWORD_FILE, copying to $VALIDATOR_PASSWORD_DIR${NC}"
        cp "$PASSWORD_FILE" "$VALIDATOR_PASSWORD_DIR/validators-password.txt"
        chmod 600 "$VALIDATOR_PASSWORD_DIR/validators-password.txt"
        PASSWORD_FILE_FOUND=true
        break
    fi
done

if [ "$PASSWORD_FILE_FOUND" = false ]; then
    echo -e "${RED}Error: Password file not found at any of the expected locations${NC}"
    echo -e "${YELLOW}Please provide a validators.txt password file at one of these locations:${NC}"
    for PASSWORD_FILE in "${PASSWORD_FILE_LOCATIONS[@]}"; do
        echo "  - $PASSWORD_FILE"
    done
    exit 1
fi

# Import validator keys directly using the lighthouse CLI in a temporary container
echo -e "${BLUE}Importing validator keys...${NC}"
docker run --rm \
  -v ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR:-"${EPHEMERY_BASE_DIR}/data/lighthouse-validator"}:/validatordata \
  -v ${EPHEMERY_VALIDATOR_KEYS_DIR:-"${EPHEMERY_BASE_DIR}/data/validator-keys"}/validator_keys:/validator-keys \
  -v $VALIDATOR_PASSWORD_DIR:/validator-passwords \
  -v ${EPHEMERY_CONFIG_DIR:-"${EPHEMERY_BASE_DIR}/config"}:/ephemery_config \
  ${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"} \
  lighthouse \
  --testnet-dir=/ephemery_config \
  account validator import \
  --directory=/validator-keys \
  --datadir=/validatordata \
  --password-file=/validator-passwords/validators-password.txt \
  --reuse-password

# Start Lighthouse validator client
echo -e "${BLUE}Starting Lighthouse validator client...${NC}"
docker run -d --name ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"} --network ${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"} \
  -v ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR:-"${EPHEMERY_BASE_DIR}/data/lighthouse-validator"}:/validatordata \
  -v ${EPHEMERY_CONFIG_DIR:-"${EPHEMERY_BASE_DIR}/config"}:/ephemery_config \
  -v $VALIDATOR_PASSWORD_DIR:/validator-passwords \
  -p ${EPHEMERY_VALIDATOR_METRICS_PORT:-5064}:5064 \
  ${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"} \
  lighthouse validator \
  --datadir /validatordata \
  --beacon-nodes http://${EPHEMERY_LIGHTHOUSE_CONTAINER:-"ephemery-lighthouse"}:${EPHEMERY_LIGHTHOUSE_HTTP_PORT:-5052} \
  --testnet-dir=/ephemery_config \
  --init-slashing-protection \
  --metrics \
  --metrics-address 0.0.0.0 \
  --metrics-port 5064 \
  --suggested-fee-recipient ${EPHEMERY_FEE_RECIPIENT:-"0x0000000000000000000000000000000000000000"}

# Check if container started successfully
if ! docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"}; then
    echo -e "${RED}Error: Validator container failed to start.${NC}"
    echo -e "${YELLOW}Checking container logs for errors:${NC}"
    docker logs ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"}
    exit 1
fi

echo -e "${GREEN}Validator setup complete!${NC}"
echo ""
echo -e "${BLUE}Monitor validator logs:${NC}"
echo "docker logs -f ${EPHEMERY_VALIDATOR_CONTAINER:-"ephemery-validator"}"
echo ""
echo -e "${YELLOW}Note: It may take some time for validators to become active on the network.${NC}"
echo -e "${YELLOW}      The beacon node must be fully synced before validators can participate.${NC}"
echo ""
echo -e "${BLUE}Validator metrics:${NC}"
echo "Available at http://localhost:${EPHEMERY_VALIDATOR_METRICS_PORT:-5064}/metrics"
