#!/bin/bash
#
# Validator Key Management Script for Ephemery
# ===========================================
#
# This script provides comprehensive validator key management functionality:
# - Generate new validator keys
# - Import existing validator keys
# - List current validator keys
# - Backup validator keys
# - Restore validator keys from backup
# - Validate key integrity
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
VALIDATOR_KEYS_DIR="${EPHEMERY_BASE_DIR}/secrets/validator/keys"
VALIDATOR_PASSWORDS_DIR="${EPHEMERY_BASE_DIR}/secrets/validator/passwords"
VALIDATOR_BACKUP_DIR="${EPHEMERY_BASE_DIR}/backups/validator/keys"
VALIDATOR_CONTAINER_NAME="ephemery-validator"

# Default settings
NETWORK="ephemery"
CLIENT="lighthouse"
VERBOSE=false
FORCE=false
DRY_RUN=false
OPERATION=""
KEY_COUNT=0
MNEMONIC=""
WITHDRAWAL_ADDRESS=""
FEE_RECIPIENT_ADDRESS=""

# Help function
function show_help {
  echo -e "${BLUE}Validator Key Management for Ephemery${NC}"
  echo ""
  echo "This script provides comprehensive validator key management functionality."
  echo ""
  echo "Usage: $0 [operation] [options]"
  echo ""
  echo "Operations:"
  echo "  generate    Generate new validator keys"
  echo "  import      Import existing validator keys"
  echo "  list        List current validator keys"
  echo "  backup      Backup validator keys"
  echo "  restore     Restore validator keys from backup"
  echo "  validate    Validate key integrity"
  echo ""
  echo "Options:"
  echo "  -n, --network NAME      Network name (default: ${NETWORK})"
  echo "  -c, --client NAME       Client name (default: ${CLIENT})"
  echo "  -k, --key-count NUM     Number of keys to generate (for generate operation)"
  echo "  -m, --mnemonic STRING   Mnemonic for key generation (optional)"
  echo "  -w, --withdrawal ADDR   Withdrawal address (for generate operation)"
  echo "  -f, --fee-recipient ADDR Fee recipient address (for generate operation)"
  echo "  -s, --source PATH       Source path for import operation"
  echo "  -b, --backup-dir PATH   Backup directory (default: ${VALIDATOR_BACKUP_DIR})"
  echo "  -t, --timestamp TIME    Backup timestamp for restore (default: latest)"
  echo "  --force                 Force operation without confirmation"
  echo "  --dry-run               Show what would be done without making changes"
  echo "  -v, --verbose           Enable verbose output"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 generate --key-count 10 --withdrawal 0x123..."
  echo "  $0 import --source /path/to/keys"
  echo "  $0 list"
  echo "  $0 backup"
  echo "  $0 restore --timestamp 20240313-123045"
  echo "  $0 validate"
}

# Parse command line arguments
function parse_args {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi

  # First argument is the operation
  OPERATION="$1"
  shift

  # Check if operation is valid
  case "${OPERATION}" in
    generate|import|list|backup|restore|validate)
      # Valid operation
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Invalid operation '${OPERATION}'${NC}"
      show_help
      exit 1
      ;;
  esac

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--network)
        NETWORK="$2"
        shift 2
        ;;
      -c|--client)
        CLIENT="$2"
        shift 2
        ;;
      -k|--key-count)
        KEY_COUNT="$2"
        shift 2
        ;;
      -m|--mnemonic)
        MNEMONIC="$2"
        shift 2
        ;;
      -w|--withdrawal)
        WITHDRAWAL_ADDRESS="$2"
        shift 2
        ;;
      -f|--fee-recipient)
        FEE_RECIPIENT_ADDRESS="$2"
        shift 2
        ;;
      -s|--source)
        SOURCE_PATH="$2"
        shift 2
        ;;
      -b|--backup-dir)
        VALIDATOR_BACKUP_DIR="$2"
        shift 2
        ;;
      -t|--timestamp)
        BACKUP_TIMESTAMP="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
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

# Validate required parameters for each operation
function validate_params {
  case "${OPERATION}" in
    generate)
      if [[ -z "${KEY_COUNT}" || "${KEY_COUNT}" -le 0 ]]; then
        echo -e "${RED}Error: Key count must be specified and greater than 0 for generate operation${NC}"
        exit 1
      fi
      if [[ -z "${WITHDRAWAL_ADDRESS}" ]]; then
        echo -e "${RED}Error: Withdrawal address must be specified for generate operation${NC}"
        exit 1
      fi
      ;;
    import)
      if [[ -z "${SOURCE_PATH}" ]]; then
        echo -e "${RED}Error: Source path must be specified for import operation${NC}"
        exit 1
      fi
      if [[ ! -d "${SOURCE_PATH}" ]]; then
        echo -e "${RED}Error: Source path '${SOURCE_PATH}' does not exist or is not a directory${NC}"
        exit 1
      fi
      ;;
    restore)
      if [[ -z "${BACKUP_TIMESTAMP}" ]]; then
        BACKUP_TIMESTAMP="latest"
        echo -e "${YELLOW}No backup timestamp specified, using latest backup${NC}"
      fi
      ;;
  esac
}

# Ensure required directories exist
function ensure_directories {
  mkdir -p "${VALIDATOR_KEYS_DIR}"
  mkdir -p "${VALIDATOR_PASSWORDS_DIR}"
  mkdir -p "${VALIDATOR_BACKUP_DIR}"
}

# Check if validator container is running
function check_validator_container {
  if docker ps | grep -q "${VALIDATOR_CONTAINER_NAME}"; then
    echo -e "${YELLOW}Warning: Validator container is running. It's recommended to stop it before making changes.${NC}"
    if [[ "${FORCE}" != "true" ]]; then
      read -p "Do you want to stop the validator container? (y/n): " stop_container
      if [[ "${stop_container}" == "y" || "${stop_container}" == "Y" ]]; then
        echo -e "${BLUE}Stopping validator container...${NC}"
        if [[ "${DRY_RUN}" != "true" ]]; then
          docker stop "${VALIDATOR_CONTAINER_NAME}"
        else
          echo -e "${YELLOW}[DRY RUN] Would stop validator container${NC}"
        fi
      else
        echo -e "${YELLOW}Proceeding with validator container running. This may cause issues.${NC}"
      fi
    else
      echo -e "${BLUE}Stopping validator container (--force specified)...${NC}"
      if [[ "${DRY_RUN}" != "true" ]]; then
        docker stop "${VALIDATOR_CONTAINER_NAME}"
      else
        echo -e "${YELLOW}[DRY RUN] Would stop validator container${NC}"
      fi
    fi
  fi
}

# Generate validator keys
function generate_keys {
  echo -e "${BLUE}Generating ${KEY_COUNT} validator keys...${NC}"

  # Create temporary directory for key generation
  TMP_DIR=$(mktemp -d)

  # Determine client-specific command
  case "${CLIENT}" in
    lighthouse)
      DOCKER_CMD="docker run --rm -v ${TMP_DIR}:/keys sigp/lighthouse:latest \
        account validator new \
        --count ${KEY_COUNT} \
        --base-dir /keys \
        --network ${NETWORK} \
        --withdrawal-address ${WITHDRAWAL_ADDRESS}"

      if [[ -n "${MNEMONIC}" ]]; then
        DOCKER_CMD="${DOCKER_CMD} --mnemonic-phrase \"${MNEMONIC}\""
      fi
      ;;
    prysm)
      DOCKER_CMD="docker run --rm -v ${TMP_DIR}:/keys prysmaticlabs/prysm-validator:latest \
        accounts create \
        --wallet-dir=/keys \
        --num-accounts=${KEY_COUNT} \
        --chain=${NETWORK} \
        --withdrawal-public-address=${WITHDRAWAL_ADDRESS}"
      ;;
    teku)
      DOCKER_CMD="docker run --rm -v ${TMP_DIR}:/keys consensys/teku:latest \
        validator generate \
        --output-path=/keys \
        --count=${KEY_COUNT} \
        --network=${NETWORK} \
        --withdrawal-address=${WITHDRAWAL_ADDRESS}"
      ;;
    nimbus)
      DOCKER_CMD="docker run --rm -v ${TMP_DIR}:/keys statusim/nimbus-eth2:latest \
        deposits create \
        --count=${KEY_COUNT} \
        --out-dir=/keys \
        --withdrawal-address=${WITHDRAWAL_ADDRESS}"
      ;;
    *)
      echo -e "${RED}Error: Unsupported client '${CLIENT}'${NC}"
      exit 1
      ;;
  esac

  # Execute key generation command
  if [[ "${DRY_RUN}" != "true" ]]; then
    eval "${DOCKER_CMD}"

    # Copy generated keys to validator keys directory
    cp -r "${TMP_DIR}"/* "${VALIDATOR_KEYS_DIR}/"

    # Create password file if it doesn't exist
    if [[ ! -f "${VALIDATOR_PASSWORDS_DIR}/validators.txt" ]]; then
      echo "ephemery" > "${VALIDATOR_PASSWORDS_DIR}/validators.txt"
    fi

    # Clean up temporary directory
    rm -rf "${TMP_DIR}"

    echo -e "${GREEN}Successfully generated ${KEY_COUNT} validator keys${NC}"
  else
    echo -e "${YELLOW}[DRY RUN] Would execute: ${DOCKER_CMD}${NC}"
    echo -e "${YELLOW}[DRY RUN] Would copy generated keys to ${VALIDATOR_KEYS_DIR}${NC}"
  fi
}

# Import validator keys
function import_keys {
  echo -e "${BLUE}Importing validator keys from ${SOURCE_PATH}...${NC}"

  # Count keys in source directory
  KEY_COUNT=$(find "${SOURCE_PATH}" -name "*.json" | wc -l)
  echo -e "${BLUE}Found ${KEY_COUNT} keys to import${NC}"

  # Backup existing keys
  if [[ -d "${VALIDATOR_KEYS_DIR}" && "$(ls -A "${VALIDATOR_KEYS_DIR}" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}Existing keys found. Creating backup...${NC}"
    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PATH="${VALIDATOR_BACKUP_DIR}/${BACKUP_TIMESTAMP}"

    if [[ "${DRY_RUN}" != "true" ]]; then
      mkdir -p "${BACKUP_PATH}"
      cp -r "${VALIDATOR_KEYS_DIR}"/* "${BACKUP_PATH}/"
      echo -e "${GREEN}Backup created at ${BACKUP_PATH}${NC}"
    else
      echo -e "${YELLOW}[DRY RUN] Would create backup at ${BACKUP_PATH}${NC}"
    fi
  fi

  # Copy keys from source to validator keys directory
  if [[ "${DRY_RUN}" != "true" ]]; then
    cp -r "${SOURCE_PATH}"/* "${VALIDATOR_KEYS_DIR}/"
    echo -e "${GREEN}Successfully imported ${KEY_COUNT} validator keys${NC}"
  else
    echo -e "${YELLOW}[DRY RUN] Would copy keys from ${SOURCE_PATH} to ${VALIDATOR_KEYS_DIR}${NC}"
  fi
}

# List validator keys
function list_keys {
  echo -e "${BLUE}Listing validator keys...${NC}"

  if [[ -d "${VALIDATOR_KEYS_DIR}" ]]; then
    KEY_COUNT=$(find "${VALIDATOR_KEYS_DIR}" -name "*.json" | wc -l)
    echo -e "${GREEN}Found ${KEY_COUNT} validator keys${NC}"

    if [[ "${VERBOSE}" == "true" ]]; then
      echo -e "${BLUE}Key details:${NC}"
      for key_file in "${VALIDATOR_KEYS_DIR}"/*.json; do
        if [[ -f "${key_file}" ]]; then
          key_name=$(basename "${key_file}")
          pubkey=$(grep -o '"pubkey": "[^"]*' "${key_file}" | cut -d'"' -f4)
          echo -e "${CYAN}${key_name}${NC}: ${pubkey}"
        fi
      done
    fi
  else
    echo -e "${YELLOW}No validator keys directory found at ${VALIDATOR_KEYS_DIR}${NC}"
  fi
}

# Backup validator keys
function backup_keys {
  echo -e "${BLUE}Backing up validator keys...${NC}"

  if [[ -d "${VALIDATOR_KEYS_DIR}" && "$(ls -A "${VALIDATOR_KEYS_DIR}" 2>/dev/null)" ]]; then
    KEY_COUNT=$(find "${VALIDATOR_KEYS_DIR}" -name "*.json" | wc -l)
    echo -e "${BLUE}Found ${KEY_COUNT} keys to backup${NC}"

    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PATH="${VALIDATOR_BACKUP_DIR}/${BACKUP_TIMESTAMP}"

    if [[ "${DRY_RUN}" != "true" ]]; then
      mkdir -p "${BACKUP_PATH}"
      cp -r "${VALIDATOR_KEYS_DIR}"/* "${BACKUP_PATH}/"

      # Create latest_backup symlink
      ln -sf "${BACKUP_TIMESTAMP}" "${VALIDATOR_BACKUP_DIR}/latest"

      echo -e "${GREEN}Backup created at ${BACKUP_PATH}${NC}"
      echo -e "${GREEN}Updated 'latest' symlink to point to this backup${NC}"
    else
      echo -e "${YELLOW}[DRY RUN] Would create backup at ${BACKUP_PATH}${NC}"
      echo -e "${YELLOW}[DRY RUN] Would update 'latest' symlink${NC}"
    fi
  else
    echo -e "${YELLOW}No validator keys found to backup at ${VALIDATOR_KEYS_DIR}${NC}"
  fi
}

# Restore validator keys from backup
function restore_keys {
  echo -e "${BLUE}Restoring validator keys from backup...${NC}"

  # Determine backup path
  if [[ "${BACKUP_TIMESTAMP}" == "latest" ]]; then
    if [[ -L "${VALIDATOR_BACKUP_DIR}/latest" ]]; then
      BACKUP_TIMESTAMP=$(readlink "${VALIDATOR_BACKUP_DIR}/latest")
      echo -e "${BLUE}Using latest backup: ${BACKUP_TIMESTAMP}${NC}"
    else
      echo -e "${RED}Error: No 'latest' backup symlink found${NC}"
      exit 1
    fi
  fi

  BACKUP_PATH="${VALIDATOR_BACKUP_DIR}/${BACKUP_TIMESTAMP}"

  if [[ ! -d "${BACKUP_PATH}" ]]; then
    echo -e "${RED}Error: Backup directory '${BACKUP_PATH}' does not exist${NC}"
    exit 1
  fi

  KEY_COUNT=$(find "${BACKUP_PATH}" -name "*.json" | wc -l)
  echo -e "${BLUE}Found ${KEY_COUNT} keys in backup${NC}"

  # Backup current keys before restoring
  if [[ -d "${VALIDATOR_KEYS_DIR}" && "$(ls -A "${VALIDATOR_KEYS_DIR}" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}Existing keys found. Creating backup before restore...${NC}"
    CURRENT_BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    CURRENT_BACKUP_PATH="${VALIDATOR_BACKUP_DIR}/${CURRENT_BACKUP_TIMESTAMP}-pre-restore"

    if [[ "${DRY_RUN}" != "true" ]]; then
      mkdir -p "${CURRENT_BACKUP_PATH}"
      cp -r "${VALIDATOR_KEYS_DIR}"/* "${CURRENT_BACKUP_PATH}/"
      echo -e "${GREEN}Pre-restore backup created at ${CURRENT_BACKUP_PATH}${NC}"
    else
      echo -e "${YELLOW}[DRY RUN] Would create pre-restore backup at ${CURRENT_BACKUP_PATH}${NC}"
    fi
  fi

  # Restore keys from backup
  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -rf "${VALIDATOR_KEYS_DIR}"/*
    cp -r "${BACKUP_PATH}"/* "${VALIDATOR_KEYS_DIR}/"
    echo -e "${GREEN}Successfully restored ${KEY_COUNT} validator keys from backup${NC}"
  else
    echo -e "${YELLOW}[DRY RUN] Would restore keys from ${BACKUP_PATH} to ${VALIDATOR_KEYS_DIR}${NC}"
  fi
}

# Validate key integrity
function validate_keys {
  echo -e "${BLUE}Validating validator keys...${NC}"

  if [[ ! -d "${VALIDATOR_KEYS_DIR}" ]]; then
    echo -e "${RED}Error: Validator keys directory '${VALIDATOR_KEYS_DIR}' does not exist${NC}"
    exit 1
  fi

  KEY_COUNT=$(find "${VALIDATOR_KEYS_DIR}" -name "*.json" | wc -l)
  echo -e "${BLUE}Found ${KEY_COUNT} validator keys${NC}"

  if [[ "${KEY_COUNT}" -eq 0 ]]; then
    echo -e "${YELLOW}No validator keys found to validate${NC}"
    return
  fi

  VALID_COUNT=0
  INVALID_COUNT=0

  for key_file in "${VALIDATOR_KEYS_DIR}"/*.json; do
    if [[ -f "${key_file}" ]]; then
      key_name=$(basename "${key_file}")

      # Check if file is valid JSON
      if jq . "${key_file}" >/dev/null 2>&1; then
        # Check if file contains required fields
        if jq -e '.pubkey' "${key_file}" >/dev/null 2>&1; then
          VALID_COUNT=$((VALID_COUNT + 1))
          if [[ "${VERBOSE}" == "true" ]]; then
            echo -e "${GREEN}✓ ${key_name}${NC}"
          fi
        else
          INVALID_COUNT=$((INVALID_COUNT + 1))
          echo -e "${RED}✗ ${key_name} (missing required fields)${NC}"
        fi
      else
        INVALID_COUNT=$((INVALID_COUNT + 1))
        echo -e "${RED}✗ ${key_name} (invalid JSON)${NC}"
      fi
    fi
  done

  echo -e "${BLUE}Validation summary:${NC}"
  echo -e "${GREEN}Valid keys: ${VALID_COUNT}${NC}"
  if [[ "${INVALID_COUNT}" -gt 0 ]]; then
    echo -e "${RED}Invalid keys: ${INVALID_COUNT}${NC}"
  else
    echo -e "${GREEN}Invalid keys: ${INVALID_COUNT}${NC}"
  fi
}

# Restart validator container if it was running
function restart_validator_container {
  if docker ps -a | grep -q "${VALIDATOR_CONTAINER_NAME}"; then
    echo -e "${BLUE}Restarting validator container...${NC}"
    if [[ "${DRY_RUN}" != "true" ]]; then
      docker start "${VALIDATOR_CONTAINER_NAME}"
    else
      echo -e "${YELLOW}[DRY RUN] Would restart validator container${NC}"
    fi
  fi
}

# Main function
function main {
  parse_args "$@"
  validate_params
  ensure_directories

  # Check if validator container is running
  check_validator_container

  # Execute requested operation
  case "${OPERATION}" in
    generate)
      generate_keys
      ;;
    import)
      import_keys
      ;;
    list)
      list_keys
      ;;
    backup)
      backup_keys
      ;;
    restore)
      restore_keys
      ;;
    validate)
      validate_keys
      ;;
  esac

  # Restart validator container if it was running
  restart_validator_container
}

# Execute main function
main "$@"
