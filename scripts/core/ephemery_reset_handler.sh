#!/bin/bash
# ephemery_reset_handler.sh - Handles Ephemery network resets
#
# This script detects when the Ephemery network has reset and performs
# necessary actions to prepare the node for the new network, including
# restoring validator keys.

# Strict error handling
set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
UTILITIES_DIR="${PARENT_DIR}/utilities"
KEY_RESTORE_WRAPPER="${UTILITIES_DIR}/ephemery_key_restore_wrapper.sh"

# Default paths
DATA_DIR="${HOME}/ephemery/data"
CONFIG_DIR="${HOME}/ephemery/config"
LAST_GENESIS_TIME_FILE="${DATA_DIR}/last_genesis_time"
RESET_DETECTED_FILE="${DATA_DIR}/reset_detected"
RESET_HANDLED_FILE="${DATA_DIR}/reset_handled"
LOG_FILE="${DATA_DIR}/logs/reset_handler.log"

# Default settings
VERBOSE=false
FORCE=false
DRY_RUN=false
RESTORE_KEYS=true
RESTART_CONTAINERS=true
BEACON_CONTAINER="ephemery-beacon-lighthouse"
VALIDATOR_CONTAINER="ephemery-validator-lighthouse"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create data directory if it doesn't exist
mkdir -p "${DATA_DIR}" "${DATA_DIR}/logs"

# Logging function
log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} - $1" | tee -a "${LOG_FILE}"
}

# Print usage information
function print_usage() {
    echo -e "${BLUE}Ephemery Reset Handler${NC}"
    echo
    echo "This script detects and handles Ephemery network resets, including validator key restoration."
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 [options]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  -f, --force           Force reset handling even if no reset is detected"
    echo "  -n, --no-keys         Skip validator key restoration"
    echo "  -c, --no-containers   Skip container restart"
    echo "  -d, --dry-run         Validate and log but don't make changes"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--no-keys)
            RESTORE_KEYS=false
            shift
            ;;
        -c|--no-containers)
            RESTART_CONTAINERS=false
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Function to check for network reset
check_for_reset() {
    log "Checking for Ephemery network reset..."

    # Check if config directory exists
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        log "Error: Config directory not found: ${CONFIG_DIR}"
        return 1
    fi

    # Get current genesis time from configuration
    local genesis_file="${CONFIG_DIR}/genesis.json"
    if [[ ! -f "${genesis_file}" ]]; then
        log "Error: Genesis file not found: ${genesis_file}"
        return 1
    }

    # Extract genesis time with proper fallback
    local current_genesis_time
    if command -v jq >/dev/null 2>&1; then
        current_genesis_time=$(jq -r '.genesis_time' "${genesis_file}" 2>/dev/null || echo "0")
    else
        # Fallback to grep and sed if jq not available
        current_genesis_time=$(grep -o '"genesis_time":"[^"]*"' "${genesis_file}" | sed 's/"genesis_time":"//;s/"//g' || echo "0")
    fi

    if [[ -z "${current_genesis_time}" || "${current_genesis_time}" == "0" || "${current_genesis_time}" == "null" ]]; then
        log "Error: Could not extract genesis time from ${genesis_file}"
        return 1
    fi

    # Check if we have a record of the last genesis time
    if [[ ! -f "${LAST_GENESIS_TIME_FILE}" ]]; then
        log "No previous genesis time recorded. Recording current genesis time: ${current_genesis_time}"
        echo "${current_genesis_time}" > "${LAST_GENESIS_TIME_FILE}"
        return 1
    }

    # Compare with last recorded genesis time
    local last_genesis_time
    last_genesis_time=$(cat "${LAST_GENESIS_TIME_FILE}")

    if [[ "${current_genesis_time}" != "${last_genesis_time}" ]]; then
        log "Ephemery network reset detected!"
        log "Old genesis time: ${last_genesis_time}"
        log "New genesis time: ${current_genesis_time}"

        # Update the last genesis time
        echo "${current_genesis_time}" > "${LAST_GENESIS_TIME_FILE}"

        # Create reset detection file
        touch "${RESET_DETECTED_FILE}"

        return 0 # Reset detected
    else
        log "No network reset detected. Genesis time unchanged: ${current_genesis_time}"

        # If force option is used, treat as reset
        if [[ "${FORCE}" == "true" ]]; then
            log "Force option used. Treating as reset."
            touch "${RESET_DETECTED_FILE}"
            return 0
        fi

        return 1 # No reset detected
    fi
}

# Function to handle reset
handle_reset() {
    log "Handling Ephemery network reset..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN: Would handle network reset here"
    else
        # Step 1: Stop containers if requested
        if [[ "${RESTART_CONTAINERS}" == "true" ]]; then
            log "Stopping Ephemery containers..."
            docker stop "${BEACON_CONTAINER}" "${VALIDATOR_CONTAINER}" 2>/dev/null || log "Warning: Failed to stop containers (may not be running)"
        fi

        # Step 2: Restore validator keys if requested
        if [[ "${RESTORE_KEYS}" == "true" ]]; then
            log "Restoring validator keys..."
            if [[ -x "${KEY_RESTORE_WRAPPER}" ]]; then
                # Build key restore options
                local restore_opts=()
                if [[ "${VERBOSE}" == "true" ]]; then
                    restore_opts+=("--verbose")
                fi
                if [[ "${DRY_RUN}" == "true" ]]; then
                    restore_opts+=("--dry-run")
                fi
                # Don't restart container since we'll do it ourselves
                restore_opts+=("--no-start")

                # Run key restore
                "${KEY_RESTORE_WRAPPER}" "${restore_opts[@]}" || {
                    log "Error: Validator key restore failed"
                    return 1
                }
            else
                log "Error: Key restore wrapper not found or not executable: ${KEY_RESTORE_WRAPPER}"
                return 1
            fi
        fi

        # Step 3: Restart containers if requested
        if [[ "${RESTART_CONTAINERS}" == "true" ]]; then
            log "Starting Ephemery containers..."
            docker start "${BEACON_CONTAINER}" "${VALIDATOR_CONTAINER}" 2>/dev/null || {
                log "Error: Failed to start containers"
                return 1
            }
        fi

        # Mark reset as handled
        touch "${RESET_HANDLED_FILE}"
        log "Network reset handling complete"
    fi
}

# Main execution
log "Ephemery reset handler started"

# Check if a reset was already detected but not handled
if [[ -f "${RESET_DETECTED_FILE}" ]] && [[ ! -f "${RESET_HANDLED_FILE}" ]]; then
    log "Previously detected reset found. Handling now."
    handle_reset
    if [[ $? -eq 0 ]]; then
        rm -f "${RESET_DETECTED_FILE}"
        log "Reset handling successful"
    else
        log "Reset handling failed. Will try again next time."
    fi
    exit 0
# Check for a new reset
elif check_for_reset; then
    log "New network reset detected. Handling now."
    handle_reset
    if [[ $? -eq 0 ]]; then
        rm -f "${RESET_DETECTED_FILE}"
        log "Reset handling successful"
    else
        log "Reset handling failed. Will try again next time."
    fi
    exit 0
else
    log "No network reset detected. Nothing to do."
    exit 0
fi
