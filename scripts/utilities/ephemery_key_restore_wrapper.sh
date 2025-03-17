#!/bin/bash
# Version: 1.0.0
# ephemery_key_restore_wrapper.sh - Wrapper for enhanced_key_restore.sh tailored for Ephemery setups
#
# This script provides a simplified interface for restoring validator keys in Ephemery environments,
# handling common configurations and providing sensible defaults.

# Strict error handling
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILITIES_DIR="${SCRIPT_DIR}"
ENHANCED_KEY_RESTORE="${UTILITIES_DIR}/enhanced_key_restore.sh"

# Default paths for Ephemery setup
DEFAULT_BACKUP_DIR="${HOME}/ephemery/backups/validators"
DEFAULT_TARGET_DIR="${HOME}/ephemery/secrets/validator/keys"
DEFAULT_VALIDATOR_CONTAINER="ephemery-validator-lighthouse"

# Default settings
FORCE=false
DRY_RUN=false
VERBOSE=false
SKIP_BACKUP=false
BACKUP_DIR=""
TARGET_DIR=""
SPECIFIC_BACKUP=""
STOP_VALIDATOR=true
START_VALIDATOR=true
VALIDATOR_CONTAINER="${DEFAULT_VALIDATOR_CONTAINER}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
function print_usage() {
  echo -e "${BLUE}Ephemery Validator Key Restore Wrapper${NC}"
  echo
  echo "This script provides a simplified interface for restoring validator keys in Ephemery setups."
  echo
  echo -e "${YELLOW}Usage:${NC}"
  echo "  $0 [options]"
  echo
  echo -e "${YELLOW}Options:${NC}"
  echo "  -b, --backup-dir DIR    Custom backup directory path (default: ${DEFAULT_BACKUP_DIR})"
  echo "  -t, --target-dir DIR    Custom target directory path (default: ${DEFAULT_TARGET_DIR})"
  echo "  -s, --specific BACKUP   Use a specific backup (timestamp or folder name)"
  echo "  -f, --force             Force restore even if validation fails"
  echo "  -d, --dry-run           Perform validation without actual restore"
  echo "  -v, --verbose           Enable verbose output"
  echo "  -n, --no-backup         Skip creating backup of existing keys"
  echo "  --no-stop               Don't stop the validator container before restore"
  echo "  --no-start              Don't start the validator container after restore"
  echo "  --container NAME        Specify validator container name (default: ${DEFAULT_VALIDATOR_CONTAINER})"
  echo "  --list-backups          List available backups in backup directory"
  echo "  -h, --help              Show this help message"
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo "  # Restore from latest backup"
  echo "  $0"
  echo
  echo "  # List available backups"
  echo "  $0 --list-backups"
  echo
  echo "  # Restore from a specific backup"
  echo "  $0 --specific validator_keys_backup_20231115120000"
  echo
  echo "  # Specify custom paths"
  echo "  $0 --backup-dir /path/to/backups --target-dir /path/to/keys"
  echo
  echo "  # Dry run with verbose output"
  echo "  $0 --dry-run --verbose"
}

# List available backups
function list_backups() {
  local backup_dir="${1:-${DEFAULT_BACKUP_DIR}}"

  if [[ ! -d "${backup_dir}" ]]; then
    echo -e "${RED}Backup directory not found: ${backup_dir}${NC}"
    exit 1
  fi

  echo -e "${BLUE}Available backups in ${backup_dir}:${NC}"

  # List directories that match the backup pattern
  backup_count=0
  while IFS= read -r backup; do
    if [[ -d "${backup}" ]]; then
      # Extract timestamp or name from path
      name=$(basename "${backup}")

      # Count JSON files in the backup
      json_count=$(find "${backup}" -name "*.json" | wc -l)

      # Display with file count
      echo -e "  ${YELLOW}${name}${NC} (${json_count} key files)"

      ((backup_count++))
    fi
  done < <(find "${backup_dir}" -maxdepth 1 -type d -name "validator_keys_backup_*" | sort)

  # Check for latest symlink
  if [[ -L "${backup_dir}/latest" ]]; then
    latest_target=$(readlink "${backup_dir}/latest")
    echo -e "${GREEN}Latest backup symlink:${NC} points to $(basename "${latest_target}")"
  fi

  if [[ ${backup_count} -eq 0 ]]; then
    echo -e "${YELLOW}No backups found matching the expected pattern.${NC}"
  else
    echo -e "${GREEN}Found ${backup_count} backup(s).${NC}"
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -h | --help)
      print_usage
      exit 0
      ;;
    --list-backups)
      BACKUP_DIR="${2:-${DEFAULT_BACKUP_DIR}}"
      list_backups "${BACKUP_DIR}"
      exit 0
      ;;
    -b | --backup-dir)
      BACKUP_DIR="$2"
      shift
      shift
      ;;
    -t | --target-dir)
      TARGET_DIR="$2"
      shift
      shift
      ;;
    -s | --specific)
      SPECIFIC_BACKUP="$2"
      shift
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -n | --no-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --no-stop)
      STOP_VALIDATOR=false
      shift
      ;;
    --no-start)
      START_VALIDATOR=false
      shift
      ;;
    --container)
      VALIDATOR_CONTAINER="$2"
      shift
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      print_usage
      exit 1
      ;;
  esac
done

# Set default paths if not specified
BACKUP_DIR="${BACKUP_DIR:-${DEFAULT_BACKUP_DIR}}"
TARGET_DIR="${TARGET_DIR:-${DEFAULT_TARGET_DIR}}"

# Check if backup directory exists
if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo -e "${RED}Backup directory not found: ${BACKUP_DIR}${NC}"
  exit 1
fi

# Determine final backup path based on options
if [[ -n "${SPECIFIC_BACKUP}" ]]; then
  # Check if user provided a full path or just a timestamp/name
  if [[ -d "${SPECIFIC_BACKUP}" ]]; then
    # User provided a full path
    FINAL_BACKUP_PATH="${SPECIFIC_BACKUP}"
  elif [[ -d "${BACKUP_DIR}/${SPECIFIC_BACKUP}" ]]; then
    # User provided a relative path within backup dir
    FINAL_BACKUP_PATH="${BACKUP_DIR}/${SPECIFIC_BACKUP}"
  else
    echo -e "${RED}Specified backup not found: ${SPECIFIC_BACKUP}${NC}"
    echo "Available backups:"
    list_backups "${BACKUP_DIR}"
    exit 1
  fi
elif [[ -L "${BACKUP_DIR}/latest" ]]; then
  # Use latest symlink
  FINAL_BACKUP_PATH="${BACKUP_DIR}/latest"
  echo -e "${GREEN}Using latest backup: $(basename "$(readlink "${FINAL_BACKUP_PATH}")")${NC}"
else
  # Find most recent backup
  latest_backup=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "validator_keys_backup_*" | sort | tail -n 1)

  if [[ -z "${latest_backup}" ]]; then
    echo -e "${RED}No backups found in ${BACKUP_DIR}${NC}"
    exit 1
  fi

  FINAL_BACKUP_PATH="${latest_backup}"
  echo -e "${YELLOW}No 'latest' symlink found. Using most recent backup: $(basename "${FINAL_BACKUP_PATH}")${NC}"
fi

# Dry run doesn't need to stop the validator
if [[ "${DRY_RUN}" == "true" ]]; then
  STOP_VALIDATOR=false
  START_VALIDATOR=false
fi

echo -e "${BLUE}Ephemery Validator Key Restore Configuration:${NC}"
echo "  Backup source: ${FINAL_BACKUP_PATH}"
echo "  Target directory: ${TARGET_DIR}"
echo "  Force: ${FORCE}"
echo "  Dry run: ${DRY_RUN}"
echo "  Skip backup: ${SKIP_BACKUP}"
echo "  Validator container: ${VALIDATOR_CONTAINER}"
echo "  Stop validator: ${STOP_VALIDATOR}"
echo "  Start validator: ${START_VALIDATOR}"
echo

# Prompt for confirmation if not a dry run
if [[ "${DRY_RUN}" == "false" ]]; then
  read -p "Proceed with restore? (y/n) " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
  fi
fi

# Build restore command
restore_cmd=("${ENHANCED_KEY_RESTORE}" "--backup-dir" "${FINAL_BACKUP_PATH}" "--target-dir" "${TARGET_DIR}")

if [[ "${FORCE}" == "true" ]]; then
  restore_cmd+=("--force")
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  restore_cmd+=("--dry-run")
fi

if [[ "${VERBOSE}" == "true" ]]; then
  restore_cmd+=("--verbose")
fi

if [[ "${SKIP_BACKUP}" == "true" ]]; then
  restore_cmd+=("--no-backup")
fi

# Stop validator container if needed
if [[ "${STOP_VALIDATOR}" == "true" ]]; then
  echo -e "${BLUE}Stopping validator container...${NC}"
  if docker stop "${VALIDATOR_CONTAINER}" 2>/dev/null; then
    echo -e "${GREEN}Validator container stopped successfully.${NC}"
  else
    echo -e "${YELLOW}Warning: Failed to stop validator container or container not running.${NC}"
  fi
fi

# Execute restore command
echo -e "${BLUE}Executing key restore...${NC}"
"${restore_cmd[@]}"
restore_status=$?

# Start validator container if needed
if [[ "${START_VALIDATOR}" == "true" && "${restore_status}" -eq 0 ]]; then
  echo -e "${BLUE}Starting validator container...${NC}"
  if docker start "${VALIDATOR_CONTAINER}" 2>/dev/null; then
    echo -e "${GREEN}Validator container started successfully.${NC}"
  else
    echo -e "${RED}Failed to start validator container.${NC}"
  fi
elif [[ "${restore_status}" -ne 0 ]]; then
  echo -e "${RED}Restore failed with status ${restore_status}, not starting validator container.${NC}"
fi

# Final status
if [[ "${restore_status}" -eq 0 ]]; then
  echo -e "${GREEN}Validator key restore operation completed successfully.${NC}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}This was a dry run. No actual changes were made.${NC}"
  fi

  exit 0
else
  echo -e "${RED}Validator key restore operation failed.${NC}"
  exit 1
fi
