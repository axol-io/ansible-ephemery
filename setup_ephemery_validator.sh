#!/bin/bash

# Ephemery Validator Setup Script
# This script sets up a Lighthouse validator client for the Ephemery network
# Version: 1.1.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Warning: Path configuration not found. Using legacy path definitions."
  # Define default settings if path_config.sh not available
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_TARGET_PEERS=100
  EPHEMERY_DOCKER_NETWORK="ephemery-net"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
  EPHEMERY_LIGHTHOUSE_IMAGE="pk910/ephemery-lighthouse:latest"
  EPHEMERY_FEE_RECIPIENT="0x0000000000000000000000000000000000000000"
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
fi

# Color definitions if not defined by common utilities
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
  if type log_info &>/dev/null; then
    log_info "Ephemery Validator Setup Script"
    log_info ""
    log_info "This script sets up a Lighthouse validator client for the Ephemery network."
    log_info ""
    log_info "Usage: $0 [options]"
    log_info ""
    log_info "Options:"
    log_info "  --base-dir PATH         Specify a custom base directory (default: ~/ephemery)"
    log_info "  --validator-count N     Expected validator count (for verification)"
    log_info "  --reset                 Reset validator database before starting"
    log_info "  --debug                 Enable debug mode with verbose output"
    log_info "  --help                  Display this help message"
    log_info ""
  else
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
  fi
}

# Function to log debug messages
debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    if type log_debug &>/dev/null; then
      log_debug "$1"
    else
      echo -e "${YELLOW}[DEBUG] $1${NC}"
    fi
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

# Display script banner
if type log_header &>/dev/null; then
  log_header "Ephemery Validator Setup Script"
else
  echo -e "${BLUE}=======================================${NC}"
  echo -e "${BLUE}   Ephemery Validator Setup Script    ${NC}"
  echo -e "${BLUE}=======================================${NC}"
  echo ""
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  if type log_warning &>/dev/null; then
    log_warning "Running as root. It's recommended to run as a non-root user."
  else
    echo -e "${YELLOW}Warning: Running as root. It's recommended to run as a non-root user.${NC}"
  fi
  
  read -p "Continue? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    if type log_error &>/dev/null; then
      log_error "Setup aborted by user."
      exit_script 0
    else
      echo -e "${RED}Setup aborted by user.${NC}"
      exit 0
    fi
  fi
fi

# Check Docker installation
if type log_info &>/dev/null; then
  log_info "Checking Docker installation..."
else
  echo -e "${BLUE}Checking Docker installation...${NC}"
fi

if type check_docker &>/dev/null; then
  check_docker || {
    if type log_error &>/dev/null; then
      log_error "Docker not found or not running. Please install Docker first."
      exit_script 1
    else
      echo -e "${RED}Error: Docker not found or not running. Please install Docker first.${NC}"
      exit 1
    fi
  }
else
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found. Please install Docker first.${NC}"
    exit 1
  fi
fi

# Debug output
debug_log "Base directory: $EPHEMERY_BASE_DIR"
debug_log "Validator keys directory: $EPHEMERY_VALIDATOR_KEYS_DIR"
debug_log "Docker network: $EPHEMERY_DOCKER_NETWORK"

# Create required directories
if type log_info &>/dev/null; then
  log_info "Creating required directories..."
else
  echo -e "${BLUE}Creating required directories...${NC}"
fi

if type create_directory &>/dev/null; then
  create_directory "${EPHEMERY_DATA_DIR}"
  create_directory "${EPHEMERY_VALIDATOR_KEYS_DIR}"
  create_directory "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
  run_with_error_handling "Setting permissions" chmod 750 "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
else
  mkdir -p "${EPHEMERY_DATA_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_KEYS_DIR}"
  mkdir -p "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
  chmod 750 "${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
fi

# Check Docker network
if type log_info &>/dev/null; then
  log_info "Checking Docker network..."
else
  echo -e "${BLUE}Checking Docker network...${NC}"
fi

if type ensure_network &>/dev/null; then
  ensure_network "${EPHEMERY_DOCKER_NETWORK}"
else
  if ! docker network ls | grep -q "${EPHEMERY_DOCKER_NETWORK}"; then
    if type log_info &>/dev/null; then
      log_info "Creating Docker network: ${EPHEMERY_DOCKER_NETWORK}"
      if type run_with_error_handling &>/dev/null; then
        run_with_error_handling "Create network" docker network create "${EPHEMERY_DOCKER_NETWORK}"
      else
        docker network create "${EPHEMERY_DOCKER_NETWORK}"
      fi
    else
      echo -e "${BLUE}Creating Docker network: ${EPHEMERY_DOCKER_NETWORK}${NC}"
      docker network create "${EPHEMERY_DOCKER_NETWORK}"
    fi
  fi
fi

# Check if beacon node is running
if type is_container_running &>/dev/null; then
  if ! is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; then
    if type log_error &>/dev/null; then
      log_error "Beacon node (${EPHEMERY_LIGHTHOUSE_CONTAINER}) is not running."
      log_warning "Please run setup_ephemery.sh first to start the beacon node."
      exit_script 1
    else
      echo -e "${RED}Error: Beacon node (${EPHEMERY_LIGHTHOUSE_CONTAINER}) is not running.${NC}"
      echo -e "${YELLOW}Please run setup_ephemery.sh first to start the beacon node.${NC}"
      exit 1
    fi
  fi
else
  if ! docker ps | grep -q ${EPHEMERY_LIGHTHOUSE_CONTAINER}; then
    echo -e "${RED}Error: Beacon node (${EPHEMERY_LIGHTHOUSE_CONTAINER}) is not running.${NC}"
    echo -e "${YELLOW}Please run setup_ephemery.sh first to start the beacon node.${NC}"
    exit 1
  fi
fi

# Check for checkpoint sync status
if type check_file_exists &>/dev/null; then
  if check_file_exists "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}"; then
    CHECKPOINT_URL=$(cat ${EPHEMERY_CHECKPOINT_SYNC_URL_FILE})
    if type log_success &>/dev/null; then
      log_success "Detected checkpoint sync with URL: ${CHECKPOINT_URL}"
      log_warning "This will accelerate the beacon node synchronization process."
      log_info "Checking beacon node sync status..."
    else
      echo -e "${GREEN}Detected checkpoint sync with URL: ${CHECKPOINT_URL}${NC}"
      echo -e "${YELLOW}This will accelerate the beacon node synchronization process.${NC}"
      echo -e "${BLUE}Checking beacon node sync status...${NC}"
    fi

    # Check if the beacon node is synced before proceeding
    if type run_with_error_handling &>/dev/null; then
      SYNC_STATUS=$(run_with_error_handling "Check sync status" curl -s http://localhost:${EPHEMERY_LIGHTHOUSE_HTTP_PORT}/eth/v1/node/syncing)
    else
      SYNC_STATUS=$(curl -s http://localhost:${EPHEMERY_LIGHTHOUSE_HTTP_PORT}/eth/v1/node/syncing)
    fi
    IS_SYNCING=$(echo $SYNC_STATUS | grep -o '"is_syncing":true' || true)

    if [ ! -z "$IS_SYNCING" ]; then
      if type log_warning &>/dev/null; then
        log_warning "Beacon node is still syncing. Validator duties will be inactive until sync completes."
        log_warning "You can proceed with validator setup, but validators won't be active immediately."
      else
        echo -e "${YELLOW}Beacon node is still syncing. Validator duties will be inactive until sync completes.${NC}"
        echo -e "${YELLOW}You can proceed with validator setup, but validators won't be active immediately.${NC}"
      fi
      
      read -p "Continue with validator setup? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if type log_error &>/dev/null; then
          log_error "Setup aborted by user."
          exit_script 0
        else
          echo -e "${RED}Setup aborted by user.${NC}"
          exit 0
        fi
      fi
    else
      if type log_success &>/dev/null; then
        log_success "Beacon node appears to be synced. Proceeding with validator setup."
      else
        echo -e "${GREEN}Beacon node appears to be synced. Proceeding with validator setup.${NC}"
      fi
    fi
  fi
else
  if [ -f "${EPHEMERY_CHECKPOINT_SYNC_URL_FILE}" ]; then
    CHECKPOINT_URL=$(cat ${EPHEMERY_CHECKPOINT_SYNC_URL_FILE})
    echo -e "${GREEN}Detected checkpoint sync with URL: ${CHECKPOINT_URL}${NC}"
    echo -e "${YELLOW}This will accelerate the beacon node synchronization process.${NC}"

    # Check if the beacon node is synced before proceeding
    echo -e "${BLUE}Checking beacon node sync status...${NC}"
    SYNC_STATUS=$(curl -s http://localhost:${EPHEMERY_LIGHTHOUSE_HTTP_PORT}/eth/v1/node/syncing)
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
  fi
fi

# Prepare validator keys
if type log_info &>/dev/null; then
  log_info "Preparing validator keys..."
else
  echo -e "${BLUE}Preparing validator keys...${NC}"
fi

# Check if validator keys already exist
if type check_directory_exists &>/dev/null; then
  if ! check_directory_exists "${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys"; then
    if type log_info &>/dev/null; then
      log_info "Extracting validator keys..."
    else
      echo -e "${BLUE}Extracting validator keys...${NC}"
    fi
    
    if type check_file_exists &>/dev/null; then
      if check_file_exists "ansible/files/validator_keys/validator_keys.zip"; then
        if type log_success &>/dev/null; then
          log_success "Found validator_keys.zip file"
          run_with_error_handling "Extract keys" unzip -o ansible/files/validator_keys/validator_keys.zip -d ${EPHEMERY_VALIDATOR_KEYS_DIR}
          log_success "Keys extracted to ${EPHEMERY_VALIDATOR_KEYS_DIR}"
        else
          echo -e "${GREEN}Found validator_keys.zip file${NC}"
          unzip -o ansible/files/validator_keys/validator_keys.zip -d ${EPHEMERY_VALIDATOR_KEYS_DIR}
          echo -e "${GREEN}Keys extracted to ${EPHEMERY_VALIDATOR_KEYS_DIR}${NC}"
        fi
      else
        if type log_error &>/dev/null; then
          log_error "validator_keys.zip file not found in ansible/files/validator_keys/"
          log_warning "Please ensure you have placed your validator keys at ansible/files/validator_keys/validator_keys.zip"
          log_warning "If you don't have validator keys yet, you can:"
          log_info "1. Generate new validator keys using the Ethereum staking deposit CLI"
          log_info "2. Download existing keys from a secure backup"
          log_info "3. Request validator keys from your team if this is a shared environment"
          log_warning "Once you have your keys, place them at the path above and run this script again."
          exit_script 1
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
      fi
    else
      if [ -f ansible/files/validator_keys/validator_keys.zip ]; then
        echo -e "${GREEN}Found validator_keys.zip file${NC}"
        unzip -o ansible/files/validator_keys/validator_keys.zip -d ${EPHEMERY_VALIDATOR_KEYS_DIR}
        echo -e "${GREEN}Keys extracted to ${EPHEMERY_VALIDATOR_KEYS_DIR}${NC}"
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
    fi
  else
    if type log_success &>/dev/null; then
      log_success "Validator keys already extracted, skipping extraction"
    else
      echo -e "${GREEN}Validator keys already extracted, skipping extraction${NC}"
    fi
  fi
else
  if [ ! -d ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys ]; then
    echo -e "${BLUE}Extracting validator keys...${NC}"
    if [ -f ansible/files/validator_keys/validator_keys.zip ]; then
      echo -e "${GREEN}Found validator_keys.zip file${NC}"
      unzip -o ansible/files/validator_keys/validator_keys.zip -d ${EPHEMERY_VALIDATOR_KEYS_DIR}
      echo -e "${GREEN}Keys extracted to ${EPHEMERY_VALIDATOR_KEYS_DIR}${NC}"
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
fi

# Check that we have keystore files
KEYSTORE_COUNT=$(find ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys -name "keystore-*.json" | wc -l)
if [ $KEYSTORE_COUNT -eq 0 ]; then
    echo -e "${RED}Error: No validator keystore files found in ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys${NC}"
    exit 1
fi
echo -e "${GREEN}Found $KEYSTORE_COUNT validator keystores${NC}"

# Validate keystore files
echo -e "${BLUE}Validating keystore files...${NC}"
VALID_COUNT=0
INVALID_COUNT=0

for keystore in ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys/keystore-*.json; do
    # Check if file is valid JSON and has required fields
    if jq . "$keystore" &>/dev/null && jq -e '.pubkey' "$keystore" &>/dev/null; then
        VALID_COUNT=$((VALID_COUNT + 1))
    else
        INVALID_COUNT=$((INVALID_COUNT + 1))
        echo -e "${RED}Invalid keystore file: $(basename "$keystore")${NC}"
    fi
done

echo -e "${BLUE}Validation summary:${NC}"
echo -e "${GREEN}Valid keystores: ${VALID_COUNT}${NC}"
if [ $INVALID_COUNT -gt 0 ]; then
    echo -e "${RED}Invalid keystores: ${INVALID_COUNT}${NC}"
    echo -e "${YELLOW}Warning: Some keystore files are invalid and will be skipped.${NC}"
    read -p "Continue with setup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup aborted by user.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}Invalid keystores: ${INVALID_COUNT}${NC}"
fi

# Verify validator count if specified
if [ $VALIDATOR_COUNT -gt 0 ] && [ $VALID_COUNT -ne $VALIDATOR_COUNT ]; then
    echo -e "${RED}Warning: Expected $VALIDATOR_COUNT validators but found $VALID_COUNT valid keystores.${NC}"
    read -p "Continue with setup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup aborted by user.${NC}"
        exit 0
    fi
fi

# Count valid and invalid keystores
VALID_COUNT=$(find ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys -name "keystore-*.json" | wc -l)
INVALID_COUNT=$(find ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys -name "*.json" ! -name "keystore-*.json" | wc -l)

if type log_info &>/dev/null; then
  log_info "Found keystores:"
  log_success "Valid keystores: ${VALID_COUNT}"
  
  if [ $VALID_COUNT -eq 0 ]; then
    log_error "No valid validator keystores found."
    log_warning "Please ensure your validator_keys.zip contains keystore-*.json files."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_error "Setup aborted by user."
      exit_script 0
    fi
  else
    log_info "Invalid keystores: ${INVALID_COUNT}"
  fi
else
  echo -e "${BLUE}Found keystores:${NC}"
  echo -e "${GREEN}Valid keystores: ${VALID_COUNT}${NC}"
  
  if [ $VALID_COUNT -eq 0 ]; then
    echo -e "${RED}Error: No valid validator keystores found.${NC}"
    echo -e "${YELLOW}Please ensure your validator_keys.zip contains keystore-*.json files.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup aborted by user.${NC}"
        exit 0
    fi
  else
    echo -e "${GREEN}Invalid keystores: ${INVALID_COUNT}${NC}"
  fi
fi

# Verify validator count if specified
if [ $VALIDATOR_COUNT -gt 0 ] && [ $VALID_COUNT -ne $VALIDATOR_COUNT ]; then
  if type log_warning &>/dev/null; then
    log_warning "Expected $VALIDATOR_COUNT validators but found $VALID_COUNT valid keystores."
    read -p "Continue with setup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_error "Setup aborted by user."
      exit_script 0
    fi
  else
    echo -e "${RED}Warning: Expected $VALIDATOR_COUNT validators but found $VALID_COUNT valid keystores.${NC}"
    read -p "Continue with setup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}Setup aborted by user.${NC}"
      exit 0
    fi
  fi
fi

# Create validator password file
if type log_info &>/dev/null; then
  log_info "Creating validator password file..."
else
  echo -e "${BLUE}Creating validator password file...${NC}"
fi

VALIDATOR_PASSWORD_DIR="${EPHEMERY_VALIDATOR_PASSWORDS_DIR}"
if type create_directory &>/dev/null; then
  create_directory "$VALIDATOR_PASSWORD_DIR"
  run_with_error_handling "Set directory permissions" chmod 700 "$VALIDATOR_PASSWORD_DIR"
else
  mkdir -p "$VALIDATOR_PASSWORD_DIR"
  chmod 700 "$VALIDATOR_PASSWORD_DIR"
fi

if type check_file_exists &>/dev/null; then
  if ! check_file_exists "$VALIDATOR_PASSWORD_DIR/validators.txt"; then
    if type run_with_error_handling &>/dev/null; then
      run_with_error_handling "Create password file" bash -c "echo \"ephemery\" > \"$VALIDATOR_PASSWORD_DIR/validators.txt\""
      run_with_error_handling "Set file permissions" chmod 600 "$VALIDATOR_PASSWORD_DIR/validators.txt"
      if type log_success &>/dev/null; then
        log_success "Created validator password file"
      else
        echo -e "${GREEN}Created validator password file${NC}"
      fi
    else
      echo "ephemery" > "$VALIDATOR_PASSWORD_DIR/validators.txt"
      chmod 600 "$VALIDATOR_PASSWORD_DIR/validators.txt"
      echo -e "${GREEN}Created validator password file${NC}"
    fi
  else
    if type log_success &>/dev/null; then
      log_success "Validator password file already exists"
    else
      echo -e "${GREEN}Validator password file already exists${NC}"
    fi
  fi
else
  if [ ! -f "$VALIDATOR_PASSWORD_DIR/validators.txt" ]; then
    echo "ephemery" > "$VALIDATOR_PASSWORD_DIR/validators.txt"
    chmod 600 "$VALIDATOR_PASSWORD_DIR/validators.txt"
    echo -e "${GREEN}Created validator password file${NC}"
  else
    echo -e "${GREEN}Validator password file already exists${NC}"
  fi
fi

# Stop running validator container if it exists
if type is_container_running &>/dev/null; then
  if is_container_running "${EPHEMERY_VALIDATOR_CONTAINER}" || docker ps -a | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    if type log_info &>/dev/null; then
      log_info "Stopping existing validator container..."
      run_with_error_handling "Stop container" docker stop ${EPHEMERY_VALIDATOR_CONTAINER} || true
      run_with_error_handling "Remove container" docker rm ${EPHEMERY_VALIDATOR_CONTAINER} || true
    else
      echo -e "${BLUE}Stopping existing validator container...${NC}"
      docker stop ${EPHEMERY_VALIDATOR_CONTAINER} || true
      docker rm ${EPHEMERY_VALIDATOR_CONTAINER} || true
    fi
  fi
else
  if docker ps -a | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    echo -e "${BLUE}Stopping existing validator container...${NC}"
    docker stop ${EPHEMERY_VALIDATOR_CONTAINER} || true
    docker rm ${EPHEMERY_VALIDATOR_CONTAINER} || true
  fi
fi

# Reset database if requested
if [ "$RESET_DATABASE" = true ]; then
  if type log_info &>/dev/null; then
    log_info "Resetting validator database..."
    run_with_error_handling "Reset database" rm -rf ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR}/*
    log_success "Validator database reset complete"
  else
    echo -e "${BLUE}Resetting validator database...${NC}"
    rm -rf ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR}/*
    echo -e "${GREEN}Validator database reset complete${NC}"
  fi
fi

# Start validator container
if type log_info &>/dev/null; then
  log_info "Starting validator container..."
else
  echo -e "${BLUE}Starting validator container...${NC}"
fi

if type run_with_error_handling &>/dev/null; then
  run_with_error_handling "Start validator container" docker run -d --name ${EPHEMERY_VALIDATOR_CONTAINER} --network ${EPHEMERY_DOCKER_NETWORK} \
    -v ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR}:/validatordata \
    -v ${EPHEMERY_CONFIG_DIR}:/ephemery_config \
    -v ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys:/validator-keys \
    -v ${EPHEMERY_VALIDATOR_PASSWORDS_DIR}:/validator-passwords \
    -p ${EPHEMERY_VALIDATOR_METRICS_PORT}:5064 \
    ${EPHEMERY_LIGHTHOUSE_IMAGE} \
    lighthouse validator \
    --datadir /validatordata \
    --beacon-nodes http://${EPHEMERY_LIGHTHOUSE_CONTAINER}:${EPHEMERY_LIGHTHOUSE_HTTP_PORT} \
    --testnet-dir=/ephemery_config \
    --init-slashing-protection \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5064 \
    --suggested-fee-recipient ${EPHEMERY_FEE_RECIPIENT} \
    --validators-dir /validator-keys \
    --secrets-dir /validator-passwords
else
  docker run -d --name ${EPHEMERY_VALIDATOR_CONTAINER} --network ${EPHEMERY_DOCKER_NETWORK} \
    -v ${EPHEMERY_LIGHTHOUSE_VALIDATOR_DIR}:/validatordata \
    -v ${EPHEMERY_CONFIG_DIR}:/ephemery_config \
    -v ${EPHEMERY_VALIDATOR_KEYS_DIR}/validator_keys:/validator-keys \
    -v ${EPHEMERY_VALIDATOR_PASSWORDS_DIR}:/validator-passwords \
    -p ${EPHEMERY_VALIDATOR_METRICS_PORT}:5064 \
    ${EPHEMERY_LIGHTHOUSE_IMAGE} \
    lighthouse validator \
    --datadir /validatordata \
    --beacon-nodes http://${EPHEMERY_LIGHTHOUSE_CONTAINER}:${EPHEMERY_LIGHTHOUSE_HTTP_PORT} \
    --testnet-dir=/ephemery_config \
    --init-slashing-protection \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5064 \
    --suggested-fee-recipient ${EPHEMERY_FEE_RECIPIENT} \
    --validators-dir /validator-keys \
    --secrets-dir /validator-passwords
fi

# Check if container started successfully
if type is_container_running &>/dev/null; then
  if ! is_container_running "${EPHEMERY_VALIDATOR_CONTAINER}"; then
    if type log_error &>/dev/null; then
      log_error "Validator container failed to start."
      log_warning "Checking container logs for errors:"
      run_with_error_handling "Show logs" docker logs ${EPHEMERY_VALIDATOR_CONTAINER}
      exit_script 1
    else
      echo -e "${RED}Error: Validator container failed to start.${NC}"
      echo -e "${YELLOW}Checking container logs for errors:${NC}"
      docker logs ${EPHEMERY_VALIDATOR_CONTAINER}
      exit 1
    fi
  fi
else
  if ! docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    echo -e "${RED}Error: Validator container failed to start.${NC}"
    echo -e "${YELLOW}Checking container logs for errors:${NC}"
    docker logs ${EPHEMERY_VALIDATOR_CONTAINER}
    exit 1
  fi
fi

if type log_success &>/dev/null; then
  log_success "Validator setup complete!"
  log_info ""
  log_info "Monitor validator logs:"
  log_info "docker logs -f ${EPHEMERY_VALIDATOR_CONTAINER}"
  log_info ""
  log_warning "Note: It may take some time for validators to become active on the network."
  log_warning "      The beacon node must be fully synced before validators can participate."
  log_info ""
  log_info "Validator metrics:"
  log_info "Available at http://localhost:${EPHEMERY_VALIDATOR_METRICS_PORT}/metrics"
else
  echo -e "${GREEN}Validator setup complete!${NC}"
  echo ""
  echo -e "${BLUE}Monitor validator logs:${NC}"
  echo "docker logs -f ${EPHEMERY_VALIDATOR_CONTAINER}"
  echo ""
  echo -e "${YELLOW}Note: It may take some time for validators to become active on the network.${NC}"
  echo -e "${YELLOW}      The beacon node must be fully synced before validators can participate.${NC}"
  echo ""
  echo -e "${BLUE}Validator metrics:${NC}"
  echo "Available at http://localhost:${EPHEMERY_VALIDATOR_METRICS_PORT}/metrics"
fi
