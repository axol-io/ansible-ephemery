#!/bin/bash

# Ephemery Validator Backup & Restore Script
# This script helps backup and restore validator keys and slashing protection data
# Version: 1.2.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Error: Path configuration not found at ${CORE_DIR}/path_config.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
else
  echo "Error: Error handling script not found at ${CORE_DIR}/error_handling.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
else
  echo "Error: Common utilities script not found at ${CORE_DIR}/common.sh"
  echo "Please ensure the core scripts are properly installed."
  exit 1
fi

# Declare version information for dependencies
declare -A VERSIONS=(
  [DOCKER]="24.0.0"
  [OPENSSL]="1.1.1"
  [GPG]="2.2.0"
)

# Define container names from path_config if not already defined
EPHEMERY_VALIDATOR_CONTAINER="${EPHEMERY_VALIDATOR_CONTAINER:-ephemery-validator}"

# Default settings
MODE="backup"
BACKUP_DIR=""
ENCRYPT_BACKUP=false
BACKUP_FILE=""
INCLUDE_SLASHING_PROTECTION=true
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# Function to show help
show_help() {
  log_info "Ephemery Validator Backup & Restore Script"
  echo ""
  echo "This script helps backup and restore validator keys and slashing protection data."
  echo ""
  echo "Usage: $0 [mode] [options]"
  echo ""
  echo "Modes:"
  echo "  backup   Create a backup of validator keys (default)"
  echo "  restore  Restore validator keys from a backup"
  echo ""
  echo "Options:"
  echo "  -d, --dir DIR          Directory to store backups or read from (default: ${EPHEMERY_BASE_DIR}/backups)"
  echo "  -f, --file FILE        Specific backup file to restore from (for restore mode)"
  echo "  -e, --encrypt          Encrypt the backup (backup mode)"
  echo "  --no-slashing          Exclude slashing protection data (backup mode)"
  echo "  --base-dir PATH        Specify a custom base directory (default: ${EPHEMERY_BASE_DIR})"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 backup              # Create a backup"
  echo "  $0 backup --encrypt    # Create an encrypted backup"
  echo "  $0 restore -f file.tar # Restore from specific backup"
}

# Function to check dependencies
check_dependencies() {
  local missing_deps=false

  # Check Docker with version validation
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker v${VERSIONS[DOCKER]} or later."
    missing_deps=true
  else
    local docker_version
    docker_version=$(docker --version | sed -n 's/Docker version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if ! version_greater_equal "$docker_version" "${VERSIONS[DOCKER]}"; then
      log_warning "Docker version $docker_version is older than recommended version ${VERSIONS[DOCKER]}"
    else
      log_success "Docker version $docker_version is installed (✓)"
    fi
  fi

  # Check OpenSSL if encryption is enabled
  if [ "$ENCRYPT_BACKUP" = true ]; then
    if ! command -v openssl &> /dev/null; then
      log_error "OpenSSL is not installed but required for encryption. Please install OpenSSL v${VERSIONS[OPENSSL]} or later."
      missing_deps=true
    else
      local openssl_version
      openssl_version=$(openssl version | sed -n 's/OpenSSL \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      if ! version_greater_equal "$openssl_version" "${VERSIONS[OPENSSL]}"; then
        log_warning "OpenSSL version $openssl_version is older than recommended version ${VERSIONS[OPENSSL]}"
      else
        log_success "OpenSSL version $openssl_version is installed (✓)"
      fi
    fi
  fi

  if [ "$missing_deps" = true ]; then
    log_fatal "Missing required dependencies. Please install them and try again."
    exit 1
  fi
}

# Helper function to compare versions
version_greater_equal() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Parse command line arguments
if [ $# -gt 0 ]; then
  if [ "$1" = "backup" ] || [ "$1" = "restore" ]; then
    MODE="$1"
    shift
  fi
fi

# Default backup directory
if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="${EPHEMERY_BASE_DIR}/backups"
fi

# Process remaining arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    -f|--file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    -e|--encrypt)
      ENCRYPT_BACKUP=true
      shift
      ;;
    --no-slashing)
      INCLUDE_SLASHING_PROTECTION=false
      shift
      ;;
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    -h|--help)
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

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to check if validator container is running
check_validator_container() {
  if ! docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    echo -e "${YELLOW}Validator container is not running.${NC}"

    # For backup, we can proceed if validator data exists
    if [ "$MODE" = "backup" ] && [ -d "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators" ]; then
      echo -e "${YELLOW}Proceeding with backup using data on disk.${NC}"
      return 0
    fi

    # For restore, we need to warn but can still proceed
    if [ "$MODE" = "restore" ]; then
      echo -e "${YELLOW}Warning: Validator container is not running.${NC}"
      echo -e "${YELLOW}Keys will be restored to disk, but you will need to restart the validator container.${NC}"
      return 0
    fi

    echo -e "${RED}Error: Cannot proceed without a validator container or valid validator data.${NC}"
    exit 1
  fi

  return 0
}

# Function to export slashing protection data
export_slashing_protection() {
  echo -e "${BLUE}Exporting slashing protection data...${NC}"

  local protection_file="${BACKUP_DIR}/slashing_protection_${TIMESTAMP}.json"

  if docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    # Container is running, use it to export
    docker exec ${EPHEMERY_VALIDATOR_CONTAINER} lighthouse \
      --testnet-dir=/ephemery_config \
      account validator slashing-protection export \
      --datadir=/validatordata \
      --output-path=/tmp/slashing_protection.json

    # Copy from container to host
    docker cp ${EPHEMERY_VALIDATOR_CONTAINER}:/tmp/slashing_protection.json "$protection_file"
  else
    # Container not running, try to use lighthouse CLI directly if it's available
    if command -v lighthouse &> /dev/null; then
      lighthouse \
        account validator slashing-protection export \
        --datadir=${EPHEMERY_BASE_DIR}/data/lighthouse-validator \
        --output-path="$protection_file"
    else
      echo -e "${RED}Error: Cannot export slashing protection without running container or lighthouse CLI.${NC}"
      return 1
    fi
  fi

  if [ -f "$protection_file" ]; then
    echo -e "${GREEN}Slashing protection data exported to: $protection_file${NC}"
    echo "$protection_file"
    return 0
  else
    echo -e "${RED}Failed to export slashing protection data.${NC}"
    return 1
  fi
}

# Function to create backup
create_backup() {
  echo -e "${BLUE}Creating validator backup...${NC}"

  # Check if validator data exists
  if [ ! -d "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators" ]; then
    echo -e "${RED}Error: No validator data found at ${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators${NC}"
    exit 1
  fi

  # Create temporary directory for backup
  local backup_tmp=$(mktemp -d)

  # Copy validator keystores
  echo -e "${BLUE}Copying validator keystores...${NC}"
  mkdir -p "${backup_tmp}/validators"
  cp -r ${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators/* "${backup_tmp}/validators/"

  # Copy validator password files
  if [ -d "${EPHEMERY_BASE_DIR}/secrets/validator-passwords" ]; then
    echo -e "${BLUE}Copying validator password files...${NC}"
    mkdir -p "${backup_tmp}/passwords"
    cp -r ${EPHEMERY_BASE_DIR}/secrets/validator-passwords/* "${backup_tmp}/passwords/"
  fi

  # Export slashing protection if required
  local protection_file=""
  if [ "$INCLUDE_SLASHING_PROTECTION" = true ]; then
    protection_file=$(export_slashing_protection)
    if [ $? -eq 0 ] && [ -f "$protection_file" ]; then
      mkdir -p "${backup_tmp}/slashing_protection"
      cp "$protection_file" "${backup_tmp}/slashing_protection/$(basename $protection_file)"
    fi
  fi

  # Create backup file name
  local backup_name="ephemery_validator_backup_${TIMESTAMP}"
  local backup_path="${BACKUP_DIR}/${backup_name}.zip"

  # Create zip archive
  echo -e "${BLUE}Creating backup archive...${NC}"
  (cd "$backup_tmp" && zip -r "$backup_path" .)

  # Encrypt if requested
  if [ "$ENCRYPT_BACKUP" = true ]; then
    echo -e "${BLUE}Encrypting backup...${NC}"
    if ! command -v openssl &> /dev/null; then
      echo -e "${RED}Error: openssl command not found. Cannot encrypt backup.${NC}"
    else
      echo -e "${YELLOW}Enter password for encryption:${NC}"
      openssl enc -aes-256-cbc -salt -in "$backup_path" -out "${backup_path}.enc"

      if [ $? -eq 0 ]; then
        rm "$backup_path"
        backup_path="${backup_path}.enc"
        echo -e "${GREEN}Backup encrypted successfully.${NC}"
      else
        echo -e "${RED}Encryption failed. Backup is left unencrypted.${NC}"
      fi
    fi
  fi

  # Cleanup
  rm -rf "$backup_tmp"

  echo -e "${GREEN}Backup created successfully at: $backup_path${NC}"
  echo -e "${YELLOW}Keep this backup secure as it contains private keys!${NC}"
}

# Function to restore from backup
restore_from_backup() {
  echo -e "${BLUE}Restoring validator from backup...${NC}"

  # Check if backup file is specified
  if [ -z "$BACKUP_FILE" ]; then
    # List available backups
    echo -e "${BLUE}Available backups:${NC}"
    ls -la "$BACKUP_DIR" | grep -E "ephemery_validator_backup_.*\.zip"

    echo -e "${YELLOW}Please specify a backup file with --file option.${NC}"
    exit 1
  fi

  # Construct full path to backup file
  local backup_path=""
  if [[ "$BACKUP_FILE" = /* ]]; then
    # Absolute path
    backup_path="$BACKUP_FILE"
  else
    # Relative to backup directory
    backup_path="${BACKUP_DIR}/${BACKUP_FILE}"
  fi

  # Check if backup file exists
  if [ ! -f "$backup_path" ]; then
    echo -e "${RED}Error: Backup file not found: $backup_path${NC}"
    exit 1
  fi

  # Check if it's an encrypted backup
  if [[ "$backup_path" == *.enc ]]; then
    echo -e "${BLUE}Encrypted backup detected. Decrypting...${NC}"

    local decrypted_path="${backup_path%.enc}"
    echo -e "${YELLOW}Enter password for decryption:${NC}"
    openssl enc -aes-256-cbc -d -in "$backup_path" -out "$decrypted_path"

    if [ $? -ne 0 ]; then
      echo -e "${RED}Decryption failed.${NC}"
      exit 1
    fi

    backup_path="$decrypted_path"
  fi

  # Create temporary directory for extraction
  local restore_tmp=$(mktemp -d)

  # Extract backup
  echo -e "${BLUE}Extracting backup...${NC}"
  unzip -q "$backup_path" -d "$restore_tmp"

  # Stop the validator container if running
  if docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    echo -e "${BLUE}Stopping validator container...${NC}"
    docker stop ${EPHEMERY_VALIDATOR_CONTAINER}
  fi

  # Backup existing validator data if any
  if [ -d "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators" ]; then
    echo -e "${BLUE}Backing up existing validator data...${NC}"
    mv "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators" \
       "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators.old.${TIMESTAMP}"
  fi

  # Restore validator keystores
  if [ -d "${restore_tmp}/validators" ]; then
    echo -e "${BLUE}Restoring validator keystores...${NC}"
    mkdir -p "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators"
    cp -r "${restore_tmp}/validators/"* "${EPHEMERY_BASE_DIR}/data/lighthouse-validator/validators/"
  else
    echo -e "${RED}Error: No validator data found in backup.${NC}"
  fi

  # Restore validator password files
  if [ -d "${restore_tmp}/passwords" ]; then
    echo -e "${BLUE}Restoring validator password files...${NC}"
    mkdir -p "${EPHEMERY_BASE_DIR}/secrets/validator-passwords"
    cp -r "${restore_tmp}/passwords/"* "${EPHEMERY_BASE_DIR}/secrets/validator-passwords/"
  fi

  # Import slashing protection if available
  if [ -d "${restore_tmp}/slashing_protection" ]; then
    echo -e "${BLUE}Restoring slashing protection data...${NC}"
    local protection_file=$(find "${restore_tmp}/slashing_protection" -name "*.json" | head -1)

    if [ -n "$protection_file" ]; then
      if docker ps -a | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
        # Copy to container and import
        docker cp "$protection_file" ${EPHEMERY_VALIDATOR_CONTAINER}:/tmp/slashing_protection.json

        echo -e "${BLUE}Starting validator container to import slashing protection...${NC}"
        docker start ${EPHEMERY_VALIDATOR_CONTAINER}
        sleep 5

        docker exec ${EPHEMERY_VALIDATOR_CONTAINER} lighthouse \
          --testnet-dir=/ephemery_config \
          account validator slashing-protection import \
          --datadir=/validatordata \
          --input-path=/tmp/slashing_protection.json
      else
        # Try to use lighthouse CLI directly if it's available
        if command -v lighthouse &> /dev/null; then
          lighthouse \
            account validator slashing-protection import \
            --datadir=${EPHEMERY_BASE_DIR}/data/lighthouse-validator \
            --input-path="$protection_file"
        else
          echo -e "${YELLOW}Warning: Cannot import slashing protection without validator container or lighthouse CLI.${NC}"
          echo -e "${YELLOW}Please start the validator container manually and import slashing protection:${NC}"
          echo "docker cp $protection_file ${EPHEMERY_VALIDATOR_CONTAINER}:/tmp/slashing_protection.json"
          echo "docker exec ${EPHEMERY_VALIDATOR_CONTAINER} lighthouse --testnet-dir=/ephemery_config account validator slashing-protection import --datadir=/validatordata --input-path=/tmp/slashing_protection.json"
        fi
      fi
    fi
  fi

  # Start validator container if stopped
  if docker ps -a | grep -q ${EPHEMERY_VALIDATOR_CONTAINER} && ! docker ps | grep -q ${EPHEMERY_VALIDATOR_CONTAINER}; then
    echo -e "${BLUE}Starting validator container...${NC}"
    docker start ${EPHEMERY_VALIDATOR_CONTAINER}
  else
    echo -e "${YELLOW}Note: You may need to start the validator container manually.${NC}"
  fi

  # Cleanup
  rm -rf "$restore_tmp"

  # Remove decrypted file if it was created
  if [[ "$backup_path" != "$BACKUP_FILE" && "$backup_path" != "$BACKUP_DIR/$BACKUP_FILE" ]]; then
    rm -f "$backup_path"
  fi

  echo -e "${GREEN}Validator keys and data restored successfully!${NC}"
}

# Main script logic
echo -e "${BLUE}===== Ephemery Validator Backup & Restore =====${NC}"
echo -e "Mode: ${YELLOW}${MODE}${NC}"

# Check validator container
check_validator_container

# Execute requested mode
case $MODE in
  backup)
    create_backup
    ;;
  restore)
    restore_from_backup
    ;;
  *)
    echo -e "${RED}Unknown mode: $MODE${NC}"
    show_help
    exit 1
    ;;
esac

echo -e "${GREEN}===== Operation Complete =====${NC}"
