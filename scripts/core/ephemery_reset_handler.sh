#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: ephemery_reset_handler.sh
# Description: Handles Ephemery network resets
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
#
# This script detects when the Ephemery network has reset and performs
# necessary actions to prepare the node for the new network, including
# restoring validator keys.

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common and config libraries
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/config.sh"

# Setup error handling and cleanup
setup_traps

# Script constants and paths
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
UTILITIES_DIR="${PARENT_DIR}/utilities"
KEY_RESTORE_WRAPPER="${UTILITIES_DIR}/ephemery_key_restore_wrapper.sh"

# Default paths from configuration or defaults
DATA_DIR="${EPHEMERY_DATA_DIR:-${HOME}/ephemery/data}"
CONFIG_DIR="${EPHEMERY_CONFIG_DIR:-${HOME}/ephemery/config}"
LOGS_DIR="${EPHEMERY_LOGS_DIR:-${DATA_DIR}/logs}"
LAST_GENESIS_TIME_FILE="${DATA_DIR}/last_genesis_time"
RESET_DETECTED_FILE="${DATA_DIR}/reset_detected"
RESET_HANDLED_FILE="${DATA_DIR}/reset_handled"
LOG_FILE="${LOGS_DIR}/reset_handler.log"

# Default settings
VERBOSE=false
FORCE=false
DRY_RUN=false
RESTORE_KEYS=true
RESTART_CONTAINERS=true
BEACON_CONTAINER="ephemery-beacon-lighthouse"
VALIDATOR_CONTAINER="ephemery-validator-lighthouse"

# Create data directory if it doesn't exist
mkdir -p "${DATA_DIR}" "${LOGS_DIR}"

# Print usage information
function print_usage() {
    log_info "Ephemery Reset Handler"
    log_info ""
    log_info "This script detects and handles Ephemery network resets, including validator key restoration."
    log_info ""
    log_info "Usage:"
    log_info "  $0 [options]"
    log_info ""
    log_info "Options:"
    log_info "  -f, --force           Force reset handling even if no reset is detected"
    log_info "  -n, --no-keys         Skip validator key restoration"
    log_info "  -c, --no-containers   Skip container restart"
    log_info "  -d, --dry-run         Validate and log but don't make changes"
    log_info "  -v, --verbose         Enable verbose output"
    log_info "  -h, --help            Show this help message"
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
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Function to check for network reset
check_for_reset() {
    log_info "Checking for Ephemery network reset..."

    # Check if config directory exists
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        log_error "Config directory not found: ${CONFIG_DIR}"
        return 1
    fi

    # Get current genesis time from configuration
    local genesis_file="${CONFIG_DIR}/genesis.json"
    if [[ ! -f "${genesis_file}" ]]; then
        log_error "Genesis file not found: ${genesis_file}"
        return 1
    fi

    # Extract genesis time with proper fallback
    local current_genesis_time
    if is_command_available jq; then
        current_genesis_time=$(jq -r '.genesis_time' "${genesis_file}" 2>/dev/null || echo "0")
    else
        # Fallback to grep and sed if jq not available
        current_genesis_time=$(grep -o '"genesis_time":"[^"]*"' "${genesis_file}" | sed 's/"genesis_time":"//;s/"//g' || echo "0")
    fi

    if [[ -z "${current_genesis_time}" || "${current_genesis_time}" == "0" || "${current_genesis_time}" == "null" ]]; then
        log_error "Could not extract genesis time from ${genesis_file}"
        return 1
    fi

    # Check if we have a record of the last genesis time
    if [[ ! -f "${LAST_GENESIS_TIME_FILE}" ]]; then
        log_info "No previous genesis time recorded. Recording current genesis time: ${current_genesis_time}"
        echo "${current_genesis_time}" > "${LAST_GENESIS_TIME_FILE}"
        return 1
    fi

    # Compare with last recorded genesis time
    local last_genesis_time
    last_genesis_time=$(cat "${LAST_GENESIS_TIME_FILE}")

    if [[ "${current_genesis_time}" != "${last_genesis_time}" ]]; then
        log_info "Ephemery network reset detected!"
        log_info "Old genesis time: ${last_genesis_time}"
        log_info "New genesis time: ${current_genesis_time}"

        # Update the last genesis time
        echo "${current_genesis_time}" > "${LAST_GENESIS_TIME_FILE}"

        # Create reset detection file
        touch "${RESET_DETECTED_FILE}"

        return 0 # Reset detected
    else
        log_info "No network reset detected. Genesis time unchanged: ${current_genesis_time}"

        # If force option is used, treat as reset
        if [[ "${FORCE}" == "true" ]]; then
            log_info "Force option used. Treating as reset."
            touch "${RESET_DETECTED_FILE}"
            return 0
        fi

        return 1 # No reset detected
    fi
}

# Function to handle reset
handle_reset() {
    log_info "Handling Ephemery network reset..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would handle network reset here"
    else
        # Step 1: Stop containers if requested
        if [[ "${RESTART_CONTAINERS}" == "true" ]]; then
            log_info "Stopping Ephemery containers..."
            if ! docker stop "${BEACON_CONTAINER}" "${VALIDATOR_CONTAINER}" 2>/dev/null; then
                log_warn "Failed to stop containers (may not be running)"
            fi
        fi

        # Step 2: Restore validator keys if requested
        if [[ "${RESTORE_KEYS}" == "true" ]]; then
            log_info "Restoring validator keys..."
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
                if ! "${KEY_RESTORE_WRAPPER}" "${restore_opts[@]}"; then
                    log_error "Validator key restore failed"
                    return 1
                fi
            else
                log_error "Key restore wrapper not found or not executable: ${KEY_RESTORE_WRAPPER}"
                return 1
            fi
        fi

        # Step 3: Restart containers if requested
        if [[ "${RESTART_CONTAINERS}" == "true" ]]; then
            log_info "Starting Ephemery containers..."
            if ! docker start "${BEACON_CONTAINER}" "${VALIDATOR_CONTAINER}" 2>/dev/null; then
                log_error "Failed to start containers"
                return 1
            fi
        fi

        # Mark reset as handled
        touch "${RESET_HANDLED_FILE}"
        log_success "Network reset handling complete"
    fi
}

# Define cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Add specific cleanup actions here if needed
}

# Main execution
log_info "Ephemery reset handler started"

# Check if a reset was already detected but not handled
if [[ -f "${RESET_DETECTED_FILE}" ]] && [[ ! -f "${RESET_HANDLED_FILE}" ]]; then
    log_info "Previously detected reset found. Handling now."
    if handle_reset; then
        rm -f "${RESET_DETECTED_FILE}"
        log_success "Reset handling successful"
    else
        log_error "Reset handling failed. Will try again next time."
    fi
    exit 0
# Check for a new reset
elif check_for_reset; then
    log_info "New network reset detected. Handling now."
    if handle_reset; then
        rm -f "${RESET_DETECTED_FILE}"
        log_success "Reset handling successful"
    else
        log_error "Reset handling failed. Will try again next time."
    fi
    exit 0
else
    log_info "No network reset detected. Nothing to do."
    exit 0
fi
