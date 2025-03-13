#!/bin/bash
#
# Enhanced Checkpoint Sync Script for Ephemery
# This script addresses the checkpoint sync issues identified in the PRD

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
INVENTORY_FILE="${REPO_ROOT}/inventory.yaml"
APPLY_FIX=false
FORCE_RESET=false
TEST_ONLY=false
VERBOSE=false
CHECK_STATUS=false

# List of checkpoint sync URLs to test
CHECKPOINT_URLS=(
  "https://checkpoint-sync.holesky.ethpandaops.io"
  "https://beaconstate-holesky.chainsafe.io" 
  "https://checkpoint-sync.ephemery.dev"
  "https://checkpoint.ephemery.eth.limo"
  "https://checkpoint-sync.mainnet.ethpandaops.io"
  "https://sync-mainnet.beaconcha.in"
)

# Help function
function show_help {
  echo -e "${BLUE}Enhanced Checkpoint Sync Tool for Ephemery${NC}"
  echo ""
  echo "This script tests multiple checkpoint sync URLs, selects the best one,"
  echo "and applies fixes to ensure optimal checkpoint synchronization."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -i, --inventory FILE   Specify the inventory file (default: ${INVENTORY_FILE})"
  echo "  -a, --apply            Apply the fix automatically"
  echo "  -r, --reset            Force reset of the Lighthouse database"
  echo "  -t, --test             Test URLs without making changes"
  echo "  -s, --status           Check current sync status"
  echo "  -v, --verbose          Enable verbose output"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --inventory production-inventory.yaml --apply"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--inventory)
      INVENTORY_FILE="$2"
      shift 2
      ;;
    -a|--apply)
      APPLY_FIX=true
      shift
      ;;
    -r|--reset)
      FORCE_RESET=true
      shift
      ;;
    -t|--test)
      TEST_ONLY=true
      shift
      ;;
    -s|--status)
      CHECK_STATUS=true
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
      echo -e "${RED}Error: Unknown option $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local color="$NC"
  
  case "$level" in
    "INFO") color="$GREEN" ;;
    "WARN") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    "DEBUG") 
      color="$BLUE"
      if [[ "$VERBOSE" != "true" ]]; then
        return
      fi
      ;;
  esac
  
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
  log "ERROR" "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi

# Function to test a checkpoint sync URL
test_checkpoint_url() {
  local url="$1"
  local timeout="${2:-10}"
  
  log "DEBUG" "Testing URL: $url with timeout $timeout seconds"
  
  # Try to get finalized state
  local status_code
  status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url/eth/v1/beacon/states/finalized")
  
  if [[ "$status_code" -eq 200 ]]; then
    log "INFO" "URL $url is accessible (HTTP 200)"
    return 0
  fi
  
  log "DEBUG" "URL $url returned HTTP $status_code"
  return 1
}

# Function to find the best checkpoint sync URL
find_best_checkpoint_url() {
  log "INFO" "Testing checkpoint sync URLs..."
  
  local best_url=""
  local fastest_time=999
  
  for url in "${CHECKPOINT_URLS[@]}"; do
    log "DEBUG" "Testing URL: $url"
    
    # Measure response time with timeout
    local start_time=$(date +%s.%N)
    if test_checkpoint_url "$url" 5; then
      local end_time=$(date +%s.%N)
      local response_time=$(echo "$end_time - $start_time" | bc)
      
      log "INFO" "URL $url is working, response time: $response_time seconds"
      
      # Compare to find the fastest
      if (( $(echo "$response_time < $fastest_time" | bc -l) )); then
        fastest_time=$response_time
        best_url=$url
      fi
    else
      log "WARN" "URL $url is not accessible"
    fi
  done
  
  if [[ -n "$best_url" ]]; then
    log "INFO" "Best checkpoint sync URL: $best_url (response time: $fastest_time seconds)"
    echo "$best_url"
    return 0
  else
    log "ERROR" "No working checkpoint sync URLs found"
    return 1
  fi
}

# Function to update the inventory file with the best URL
update_inventory_file() {
  local inventory_file="$1"
  local best_url="$2"
  
  log "INFO" "Updating inventory file with best checkpoint sync URL"
  
  # Backup the inventory file
  local backup_file="${inventory_file}.backup.$(date +%Y%m%d%H%M%S)"
  cp "$inventory_file" "$backup_file"
  log "INFO" "Created backup of inventory file: $backup_file"
  
  # Update the checkpoint_sync_url in the inventory file
  if grep -q "checkpoint_sync_url:" "$inventory_file"; then
    sed -i.bak "s|checkpoint_sync_url:.*|checkpoint_sync_url: '$best_url'|g" "$inventory_file"
    log "INFO" "Updated existing checkpoint_sync_url in inventory file"
  else
    log "WARN" "checkpoint_sync_url not found in inventory file"
    # Try to add it in the appropriate section
    if grep -q "lighthouse:" "$inventory_file"; then
      sed -i.bak "/lighthouse:/a\\        checkpoint_sync_url: '$best_url'" "$inventory_file"
      log "INFO" "Added checkpoint_sync_url to lighthouse section"
    else
      log "ERROR" "Could not find appropriate section to add checkpoint_sync_url"
      return 1
    fi
  fi
  
  # Ensure use_checkpoint_sync is enabled
  if grep -q "use_checkpoint_sync:" "$inventory_file"; then
    sed -i.bak "s|use_checkpoint_sync:.*|use_checkpoint_sync: true|g" "$inventory_file"
    log "INFO" "Updated use_checkpoint_sync to true"
  fi
  
  # Clean up the temporary backup file
  rm -f "${inventory_file}.bak"
  
  log "INFO" "Inventory file updated successfully"
  return 0
}

# Function to check current sync status
check_sync_status() {
  log "INFO" "Checking current sync status..."
  
  # Try to get sync status from the Lighthouse API
  local sync_status
  sync_status=$(curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null)
  
  if [[ -z "$sync_status" ]]; then
    log "WARN" "Could not connect to Lighthouse API"
    # Check if the container is running
    if docker ps -q -f name=lighthouse | grep -q .; then
      log "INFO" "Lighthouse container is running"
    else
      log "ERROR" "Lighthouse container is not running"
    fi
    return 1
  fi
  
  # Extract sync information
  local is_syncing=$(echo "$sync_status" | grep -o '"is_syncing":true' || echo "false")
  local head_slot=$(echo "$sync_status" | grep -o '"head_slot":"[0-9]*"' | sed 's/"head_slot":"//g' | sed 's/"//g')
  local sync_distance=$(echo "$sync_status" | grep -o '"sync_distance":"[0-9]*"' | sed 's/"sync_distance":"//g' | sed 's/"//g')
  
  if [[ "$is_syncing" == *"true"* ]]; then
    log "INFO" "Lighthouse is currently syncing"
    log "INFO" "Head slot: $head_slot"
    log "INFO" "Sync distance: $sync_distance"
    
    # Calculate percentage
    if [[ -n "$head_slot" && -n "$sync_distance" && "$sync_distance" != "0" ]]; then
      local total_slots=$((head_slot + sync_distance))
      local sync_percentage=$(echo "scale=2; $head_slot * 100 / $total_slots" | bc)
      log "INFO" "Sync progress: ${sync_percentage}%"
    fi
  else
    log "INFO" "Lighthouse is fully synced"
    log "INFO" "Head slot: $head_slot"
  fi
  
  return 0
}

# Function to apply the fix
apply_fix() {
  local inventory_file="$1"
  local best_url="$2"
  local force_reset="$3"
  
  log "INFO" "Applying checkpoint sync fix..."
  
  # Update the inventory file
  if ! update_inventory_file "$inventory_file" "$best_url"; then
    log "ERROR" "Failed to update inventory file"
    return 1
  fi
  
  # Run the Ansible playbook to fix checkpoint sync
  log "INFO" "Running fix_checkpoint_sync.yaml playbook"
  
  local playbook_cmd="ansible-playbook -i ${inventory_file} ${REPO_ROOT}/ansible/playbooks/fix_checkpoint_sync.yaml"
  
  if [[ "$force_reset" == "true" ]]; then
    playbook_cmd+=" --extra-vars 'force_reset=true'"
  fi
  
  if [[ "$VERBOSE" == "true" ]]; then
    playbook_cmd+=" -v"
  fi
  
  log "DEBUG" "Running command: $playbook_cmd"
  
  if ! eval "$playbook_cmd"; then
    log "ERROR" "Failed to run fix_checkpoint_sync.yaml playbook"
    return 1
  fi
  
  log "INFO" "Checkpoint sync fix applied successfully"
  return 0
}

# Main execution
log "INFO" "Enhanced Checkpoint Sync Tool for Ephemery"
log "INFO" "Using inventory file: $INVENTORY_FILE"

if [[ "$CHECK_STATUS" == "true" ]]; then
  check_sync_status
  exit $?
fi

# Find the best checkpoint sync URL
best_url=$(find_best_checkpoint_url)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  log "ERROR" "Failed to find a working checkpoint sync URL"
  exit 1
fi

if [[ "$TEST_ONLY" == "true" ]]; then
  log "INFO" "Test completed successfully"
  exit 0
fi

if [[ "$APPLY_FIX" == "true" ]]; then
  apply_fix "$INVENTORY_FILE" "$best_url" "$FORCE_RESET"
  exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    log "INFO" "Fix applied successfully. Checking sync status..."
    sleep 10 # Give the service time to restart
    check_sync_status
  fi
  
  exit $exit_code
else
  log "INFO" "Found best checkpoint sync URL: $best_url"
  log "INFO" "To apply the fix, run this command with the --apply option"
  exit 0
fi 