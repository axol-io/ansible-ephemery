#!/bin/bash
# Version: 1.0.0
# Script to manage generated inventory files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
ACTION="list"
DAYS_TO_KEEP=30
BACKUP_DIR="${PROJECT_ROOT}/inventory_backups"
INVENTORY_PATTERN="*-inventory-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.yaml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Manage Ephemery inventory files"
  echo ""
  echo "Options:"
  echo "  --list                  List all generated inventory files (default)"
  echo "  --clean                 Clean up old inventory files"
  echo "  --backup                Backup all inventory files"
  echo "  --days DAYS             Days to keep when cleaning (default: 30)"
  echo "  --backup-dir DIR        Backup directory (default: ./inventory_backups)"
  echo "  --help                  Display this help and exit"
  echo ""
  echo "Examples:"
  echo "  $0 --list                          # List all inventory files"
  echo "  $0 --clean --days 7                # Clean inventory files older than 7 days"
  echo "  $0 --backup --backup-dir /backups  # Backup inventory files to /backups"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --list)
      ACTION="list"
      shift
      ;;
    --clean)
      ACTION="clean"
      shift
      ;;
    --backup)
      ACTION="backup"
      shift
      ;;
    --days)
      DAYS_TO_KEEP="$2"
      shift 2
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}" >&2
      usage
      exit 1
      ;;
  esac
done

# Function to find all inventory files
find_inventory_files() {
  find "${PROJECT_ROOT}" -maxdepth 1 -type f -name "${INVENTORY_PATTERN}" | sort
}

# Function to list inventory files
list_inventory_files() {
  echo -e "${BLUE}Generated Inventory Files:${NC}"
  local files=($(find_inventory_files))

  if [ ${#files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No inventory files found.${NC}"
    return
  fi

  echo -e "${GREEN}Found ${#files[@]} inventory files:${NC}"
  echo ""
  printf "%-50s %-25s %-15s\n" "FILENAME" "CREATED" "SIZE"
  echo "----------------------------------------------------------------------------------------"

  for file in "${files[@]}"; do
    local filename=$(basename "${file}")
    local created=$(stat -c "%y" "${file}" 2>/dev/null || stat -f "%Sm" "${file}" 2>/dev/null)
    local size=$(du -h "${file}" | cut -f1)
    printf "%-50s %-25s %-15s\n" "${filename}" "${created}" "${size}"
  done
}

# Function to clean old inventory files
clean_inventory_files() {
  echo -e "${BLUE}Cleaning inventory files older than ${DAYS_TO_KEEP} days...${NC}"

  # Use find to locate old files
  local old_files=()

  if [[ "${OSTYPE}" == "darwin"* ]]; then
    # macOS
    old_files=($(find "${PROJECT_ROOT}" -maxdepth 1 -type f -name "${INVENTORY_PATTERN}" -mtime +"${DAYS_TO_KEEP}" -print))
  else
    # Linux
    old_files=($(find "${PROJECT_ROOT}" -maxdepth 1 -type f -name "${INVENTORY_PATTERN}" -mtime +"${DAYS_TO_KEEP}" -print))
  fi

  if [ ${#old_files[@]} -eq 0 ]; then
    echo -e "${GREEN}No old inventory files to clean.${NC}"
    return
  fi

  echo -e "${YELLOW}The following ${#old_files[@]} files will be deleted:${NC}"
  for file in "${old_files[@]}"; do
    echo "- $(basename "${file}")"
  done

  echo ""
  read -p "Are you sure you want to delete these files? (y/N) " -n 1 -r
  echo ""

  if [[ ${REPLY} =~ ^[Yy]$ ]]; then
    for file in "${old_files[@]}"; do
      rm -f "${file}"
      echo -e "${GREEN}Deleted: $(basename "${file}")${NC}"
    done
    echo -e "${GREEN}Cleanup complete.${NC}"
  else
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
  fi
}

# Function to backup inventory files
backup_inventory_files() {
  echo -e "${BLUE}Backing up inventory files to ${BACKUP_DIR}...${NC}"

  # Create backup directory if it doesn't exist
  mkdir -p "${BACKUP_DIR}"

  # Get list of inventory files
  local files=($(find_inventory_files))

  if [ ${#files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No inventory files found to backup.${NC}"
    return
  fi

  # Create timestamped backup directory
  local backup_timestamp=$(date +"%Y-%m-%d-%H-%M")
  local backup_path="${BACKUP_DIR}/inventory-backup-${backup_timestamp}"
  mkdir -p "${backup_path}"

  # Copy files to backup directory
  for file in "${files[@]}"; do
    cp "${file}" "${backup_path}/"
    echo -e "${GREEN}Backed up: $(basename "${file}")${NC}"
  done

  echo -e "${GREEN}Backup complete: ${backup_path}${NC}"
  echo -e "${GREEN}Total files backed up: ${#files[@]}${NC}"
}

# Execute the requested action
case ${ACTION} in
  list)
    list_inventory_files
    ;;
  clean)
    list_inventory_files
    echo ""
    clean_inventory_files
    ;;
  backup)
    backup_inventory_files
    ;;
  *)
    echo -e "${RED}Error: Unknown action ${ACTION}${NC}" >&2
    usage
    exit 1
    ;;
esac
