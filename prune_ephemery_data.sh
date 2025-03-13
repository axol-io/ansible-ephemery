#!/bin/bash

# Ephemery Data Pruning Script
# This script helps manage disk space by providing options to prune old data

# Source common configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/scripts/core/ephemery_config.sh" ]; then
  source "$SCRIPT_DIR/scripts/core/ephemery_config.sh"
else
  # Fallback to local definitions if common config not found
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_GETH_CONTAINER="ephemery-geth"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
fi

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
PRUNE_TYPE="safe"
DRY_RUN=true
CONFIRM=false

# Function to show help
show_help() {
  echo -e "${BLUE}Ephemery Data Pruning Script${NC}"
  echo ""
  echo "This script helps manage disk space by removing unnecessary data files."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -s, --safe              Safe pruning (removes only non-essential data, default)"
  echo "  -a, --aggressive        Aggressive pruning (removes more data, may affect performance)"
  echo "  -f, --full              Full pruning (completely resets nodes, requires resync)"
  echo "  -e, --execution-only    Prune only execution layer data"
  echo "  -c, --consensus-only    Prune only consensus layer data"
  echo "  -d, --dry-run           Show what would be pruned without making changes (default)"
  echo "  -y, --yes               Skip confirmation prompts"
  echo "  --base-dir PATH         Specify a custom base directory (default: ~/ephemery)"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --safe               # Safe pruning (dry run mode)"
  echo "  $0 --safe --yes         # Safe pruning with automatic confirmation"
  echo "  $0 --aggressive --yes   # Aggressive pruning with automatic confirmation"
  echo "  $0 --full --yes         # Full pruning with automatic confirmation"
}

# Parse command line arguments
PRUNE_EXECUTION=true
PRUNE_CONSENSUS=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--safe)
      PRUNE_TYPE="safe"
      shift
      ;;
    -a|--aggressive)
      PRUNE_TYPE="aggressive"
      shift
      ;;
    -f|--full)
      PRUNE_TYPE="full"
      shift
      ;;
    -e|--execution-only)
      PRUNE_EXECUTION=true
      PRUNE_CONSENSUS=false
      shift
      ;;
    -c|--consensus-only)
      PRUNE_EXECUTION=false
      PRUNE_CONSENSUS=true
      shift
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -y|--yes)
      CONFIRM=true
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

# Function to check disk usage
check_disk_usage() {
  echo -e "${BLUE}Current disk usage:${NC}"

  # Get disk usage for Ephemery data directory
  echo -e "${BLUE}Total Ephemery data:${NC}"
  du -sh ${EPHEMERY_BASE_DIR} 2>/dev/null || echo "N/A"

  if [ -d "${EPHEMERY_BASE_DIR}/data/geth" ]; then
    echo -e "${BLUE}Execution (Geth) data:${NC}"
    du -sh ${EPHEMERY_BASE_DIR}/data/geth 2>/dev/null || echo "N/A"
  fi

  if [ -d "${EPHEMERY_BASE_DIR}/data/lighthouse" ]; then
    echo -e "${BLUE}Consensus (Lighthouse) data:${NC}"
    du -sh ${EPHEMERY_BASE_DIR}/data/lighthouse 2>/dev/null || echo "N/A"
  fi

  # Check available disk space
  echo -e "${BLUE}Available disk space:${NC}"
  df -h ${EPHEMERY_BASE_DIR} | grep -v "Filesystem"
}

# Function to stop containers
stop_containers() {
  local needed=$1

  if [ "$needed" = true ]; then
    echo -e "${BLUE}Stopping containers for pruning...${NC}"

    if [ "$DRY_RUN" = false ]; then
      echo -e "${YELLOW}Stopping containers...${NC}"
      docker stop ${EPHEMERY_VALIDATOR_CONTAINER} 2>/dev/null || true
      docker stop ${EPHEMERY_LIGHTHOUSE_CONTAINER} 2>/dev/null || true
      docker stop ${EPHEMERY_GETH_CONTAINER} 2>/dev/null || true
    else
      echo -e "${YELLOW}[DRY RUN] Would stop containers:${NC}"
      echo "  - ${EPHEMERY_VALIDATOR_CONTAINER}"
      echo "  - ${EPHEMERY_LIGHTHOUSE_CONTAINER}"
      echo "  - ${EPHEMERY_GETH_CONTAINER}"
    fi
  fi
}

# Function to start containers
start_containers() {
  local needed=$1

  if [ "$needed" = true ] && [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}Starting containers after pruning...${NC}"
    docker start ${EPHEMERY_GETH_CONTAINER} 2>/dev/null || true
    sleep 5
    docker start ${EPHEMERY_LIGHTHOUSE_CONTAINER} 2>/dev/null || true
    sleep 5
    docker start ${EPHEMERY_VALIDATOR_CONTAINER} 2>/dev/null || true
  elif [ "$needed" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would start containers:${NC}"
    echo "  - ${EPHEMERY_GETH_CONTAINER}"
    echo "  - ${EPHEMERY_LIGHTHOUSE_CONTAINER}"
    echo "  - ${EPHEMERY_VALIDATOR_CONTAINER}"
  fi
}

# Function to prune execution (Geth) data
prune_execution_data() {
  if [ "$PRUNE_EXECUTION" = false ]; then
    return
  fi

  echo -e "${BLUE}===== Execution Layer (Geth) Pruning =====${NC}"

  case $PRUNE_TYPE in
    safe)
      echo -e "${YELLOW}Safe pruning for Geth:${NC}"

      # Check if container is running
      if docker ps | grep -q ${EPHEMERY_GETH_CONTAINER}; then
        if [ "$DRY_RUN" = false ]; then
          echo -e "${BLUE}Running Geth garbage collection...${NC}"
          docker exec ${EPHEMERY_GETH_CONTAINER} geth snapshot prune-state
        else
          echo -e "${YELLOW}[DRY RUN] Would run Geth garbage collection${NC}"
        fi
      else
        echo -e "${YELLOW}Geth container not running, skipping garbage collection${NC}"
      fi
      ;;

    aggressive)
      echo -e "${YELLOW}Aggressive pruning for Geth:${NC}"

      # Need to stop containers for aggressive pruning
      stop_containers true

      if [ "$DRY_RUN" = false ]; then
        echo -e "${BLUE}Removing ancient and state trie data...${NC}"
        rm -rf ${EPHEMERY_BASE_DIR}/data/geth/geth/chaindata/ancient/receipts/*
        rm -rf ${EPHEMERY_BASE_DIR}/data/geth/geth/chaindata/ancient/bodies/*
        rm -rf ${EPHEMERY_BASE_DIR}/data/geth/geth/triecache/*
      else
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC}"
        echo "  - Ancient receipts and block bodies"
        echo "  - Trie cache data"
      fi

      # Start containers after pruning
      start_containers true
      ;;

    full)
      echo -e "${RED}Full pruning for Geth:${NC}"

      # Need to stop containers for full pruning
      stop_containers true

      if [ "$DRY_RUN" = false ]; then
        echo -e "${RED}Removing all Geth data (will require full resync)...${NC}"
        rm -rf ${EPHEMERY_BASE_DIR}/data/geth/*
      else
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC}"
        echo "  - All Geth data (requires full resync)"
      fi

      # Start containers after pruning
      start_containers true
      ;;
  esac
}

# Function to prune consensus (Lighthouse) data
prune_consensus_data() {
  if [ "$PRUNE_CONSENSUS" = false ]; then
    return
  fi

  echo -e "${BLUE}===== Consensus Layer (Lighthouse) Pruning =====${NC}"

  case $PRUNE_TYPE in
    safe)
      echo -e "${YELLOW}Safe pruning for Lighthouse:${NC}"

      # Remove freezer database states (archived states that aren't needed for normal operation)
      if [ "$DRY_RUN" = false ]; then
        if [ -d "${EPHEMERY_BASE_DIR}/data/lighthouse/freezer_db" ]; then
          echo -e "${BLUE}Pruning older states from freezer database...${NC}"
          find ${EPHEMERY_BASE_DIR}/data/lighthouse/freezer_db -type f -name "*.ssz" -mtime +30 -delete
        fi
      else
        echo -e "${YELLOW}[DRY RUN] Would prune:${NC}"
        echo "  - Older state files from freezer database"
      fi
      ;;

    aggressive)
      echo -e "${YELLOW}Aggressive pruning for Lighthouse:${NC}"

      # Need to stop containers for aggressive pruning
      stop_containers true

      if [ "$DRY_RUN" = false ]; then
        echo -e "${BLUE}Removing freezer database and hot database...${NC}"
        rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/freezer_db/*
        rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/hot_db/*
      else
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC}"
        echo "  - Freezer database (archived blockchain data)"
        echo "  - Hot database (recent blockchain data)"
      fi

      # Start containers after pruning
      start_containers true
      ;;

    full)
      echo -e "${RED}Full pruning for Lighthouse:${NC}"

      # Need to stop containers for full pruning
      stop_containers true

      if [ "$DRY_RUN" = false ]; then
        echo -e "${RED}Removing all Lighthouse data (will require full resync)...${NC}"
        rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/*
      else
        echo -e "${YELLOW}[DRY RUN] Would remove:${NC}"
        echo "  - All Lighthouse data (requires full resync)"
      fi

      # Start containers after pruning
      start_containers true
      ;;
  esac
}

# Main logic starts here
echo -e "${BLUE}===== Ephemery Data Pruning =====${NC}"
echo -e "Pruning mode: ${YELLOW}${PRUNE_TYPE}${NC}"
[ "$DRY_RUN" = true ] && echo -e "${YELLOW}Dry run mode: Only showing what would be pruned${NC}"

# Check current disk usage
check_disk_usage

# Confirm pruning operation
if [ "$CONFIRM" = false ] && [ "$DRY_RUN" = false ]; then
  echo ""
  echo -e "${RED}WARNING: This will prune data from your Ephemery node${NC}"
  echo -e "Pruning mode: ${YELLOW}${PRUNE_TYPE}${NC}"

  if [ "$PRUNE_TYPE" = "aggressive" ]; then
    echo -e "${YELLOW}Aggressive pruning may temporarily affect node performance${NC}"
  elif [ "$PRUNE_TYPE" = "full" ]; then
    echo -e "${RED}Full pruning will require a complete resync of your node${NC}"
  fi

  read -p "Continue with pruning? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Pruning aborted by user.${NC}"
    exit 0
  fi
fi

# Execute pruning operations
prune_execution_data
prune_consensus_data

# Check disk usage after pruning
if [ "$DRY_RUN" = false ]; then
  echo -e "${BLUE}Disk usage after pruning:${NC}"
  check_disk_usage
else
  echo -e "${YELLOW}Dry run completed. No changes were made.${NC}"
  echo -e "To actually perform the pruning, run again without the --dry-run flag."
fi

echo -e "${GREEN}===== Pruning Operation Complete =====${NC}"
