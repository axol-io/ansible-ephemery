source "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/fixtures/reset_test/get_genesis_time.sh"
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

GENESIS_TIME_FILE="/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/fixtures/reset_test/genesis_time.txt"
#!/bin/bash
# Version: 1.0.0
#
# Ephemery Retention Script
# =========================
#
# This script manages the Ephemery testnet node lifecycle by:
# - Detecting when the testnet has been reset to a new genesis
# - Downloading the latest genesis configuration files
# - Resetting the node data and initializing with the new genesis
# - Restarting the clients
#
# Run this script via crontab every 5 minutes to stay in sync with the network.
# Example cron: */5 * * * * /root/ephemery/scripts/ephemery_retention.sh > /root/ephemery/logs/retention.log 2>&1
#

# Exit immediately if a command exits with a non-zero status
set -e
# Exit if any command in a pipeline fails
set -o pipefail

# Function to get genesis time from genesis.json
get_genesis_time() {
  if [ -f "${CONFIG_DIR}/genesis.json" ]; then
    # Extract genesis_time from the JSON file
    grep -o '"genesis_time":[^,}]*' "${CONFIG_DIR}/genesis.json" | cut -d: -f2 | tr -d '"' | tr -d ' '
  else
    echo "0"
  fi
}

# Parse command line arguments
TEST_MODE=false
TEST_DIR=""

for arg in "$@"; do
  case $arg in
    --test-mode)
      TEST_MODE=true
      shift
      ;;
    --test-dir=*)
      TEST_DIR="${arg#*=}"
      shift
      ;;
  esac
done

# ======================
# Configuration Variables
# ======================
# Adjust these to match your environment

# Base directory for all Ephemery files
if [ -n "$TEST_DIR" ]; then
  HOME_DIR="$TEST_DIR"
else
  HOME_DIR="/root/ephemery"
fi
# Directory for client data storage
DATA_DIR="${HOME_DIR}/data"
# Directory for configuration files (genesis.json, etc.)
CONFIG_DIR="${HOME_DIR}/config"
# Directory for log files
LOG_DIR="${HOME_DIR}/logs"
# GitHub repository for genesis files
GENESIS_REPO="ephemery-testnet/ephemery-genesis"
# Port for the consensus layer API
CL_PORT=5052

# Make sure log directory exists
mkdir -p "${LOG_DIR}"

# ========================
# Client Management Functions
# ========================

# start_clients()
# Purpose: Starts the Docker containers for the execution and consensus clients
# Usage: start_clients
start_clients() {
  echo "$(date) - Starting Ephemery clients..."
  # Start execution layer client first
  docker start ephemery-geth
  # Wait for Geth to initialize before starting consensus layer
  sleep 10
  # Start consensus layer client
  docker start ephemery-lighthouse
  # If you're running a validator, uncomment:
  # docker start ephemery-validator
}

# stop_clients()
# Purpose: Stops all Docker containers for the Ethereum clients
# Usage: stop_clients
stop_clients() {
  echo "$(date) - Stopping Ephemery clients..."
  # Stop execution and consensus clients
  # Use || true to prevent script failure if containers are already stopped
  docker stop ephemery-geth ephemery-lighthouse || true
  # If you're running a validator, uncomment:
  # docker stop ephemery-validator || true
}

# ========================
# Data Management Functions
# ========================

# clear_datadirs()
# Purpose: Clears client data directories while preserving critical files
# Usage: clear_datadirs
clear_datadirs() {
  echo "$(date) - Clearing data directories..."

  # Preserve nodekey if it exists to maintain network identity
  if [ -f "${DATA_DIR}/geth/nodekey" ]; then
    # Save nodekey content
    GETH_NODEKEY=$(cat "${DATA_DIR}/geth/nodekey")
    # Remove all Geth data
    rm -rf "${DATA_DIR}/geth/"*
    # Recreate directory
    mkdir -p "${DATA_DIR}/geth"
    # Restore nodekey
    echo "${GETH_NODEKEY}" >"${DATA_DIR}/geth/nodekey"
  else
    # If no nodekey exists, just clear the directory
    rm -rf "${DATA_DIR}/geth/"*
  fi

  # Clear beacon node data completely
  rm -rf "${DATA_DIR}/beacon/"*

  # Clear slashing protection database if it exists
  if [ -f "${DATA_DIR}/validator/slashing_protection.sqlite" ]; then
    rm -f "${DATA_DIR}/validator/slashing_protection.sqlite"
  fi
}

# =============================
# Genesis Management Functions
# =============================

# setup_genesis()
# Purpose: Initializes the execution client with the new genesis configuration
# Usage: setup_genesis
setup_genesis() {
  echo "$(date) - Initializing Geth with new genesis..."
  # Run Geth init command in Docker with mounted volumes
  docker run --rm -v "${DATA_DIR}/geth:/data" -v "${CONFIG_DIR}:/config" \
    pk910/ephemery-geth geth init --datadir=/data /config/genesis.json
}

# get_github_release(repo)
# Purpose: Retrieves the latest release tag from a GitHub repository
# Parameters:
#   $1 - GitHub repository path (e.g., "ephemery-testnet/ephemery-genesis")
# Returns: The latest release tag name as a string
# Usage: latest_release=$(get_github_release "ephemery-testnet/ephemery-genesis")
get_github_release() {
  # Use GitHub API to get latest release
  curl --silent "https://api.github.com/repos/$1/releases/latest" \
    |
    # Extract the tag_name field from the JSON response
    grep '"tag_name":' \
    |
    # Parse the value with sed
    sed -E 's/.*"([^"]+)".*/\1/' \
    |
    # Take only the first result
    head -n 1
}

# download_genesis_release(release)
# Purpose: Downloads and extracts the latest genesis configuration files
# Parameters:
#   $1 - Release tag to download
# Usage: download_genesis_release "v1.2.3"
download_genesis_release() {
  local release=$1
  echo "$(date) - Downloading genesis files for release: ${release}"

  # Ensure config directory exists
  mkdir -p "${CONFIG_DIR}"
  # Clear existing config files
  rm -rf "${CONFIG_DIR}"/*

  # Download and extract the release tarball
  echo "Downloading from: https://github.com/${GENESIS_REPO}/releases/download/${release}/testnet-all.tar.gz"
  wget -qO- "https://github.com/${GENESIS_REPO}/releases/download/${release}/testnet-all.tar.gz" | tar xvz -C "${CONFIG_DIR}"

  # Extract variables from config.vars if it exists
  if [ -f "${CONFIG_DIR}/config.vars" ]; then
    # Source the config file to get variables
    source "${CONFIG_DIR}/config.vars"
    # Create retention.vars with key information
    echo "CHAIN_ID=${CHAIN_ID}" >"${CONFIG_DIR}/retention.vars"
    echo "ITERATION_RELEASE=${release}" >>"${CONFIG_DIR}/retention.vars"
    echo "GENESIS_RESET_INTERVAL=${GENESIS_RESET_INTERVAL}" >>"${CONFIG_DIR}/retention.vars"
  fi
}

# reset_testnet(release)
# Purpose: Performs a complete reset of the testnet node to a new genesis state
# Parameters:
#   $1 - Release tag to reset to
# Usage: reset_testnet "v1.2.3"
reset_testnet() {
  echo "$(date) - Resetting testnet to release: $1"
  
  if [ "$TEST_MODE" = true ]; then
    echo "Test mode: Would reset testnet to release $1"
    # In test mode, just update the mock genesis file
    echo '{"genesis_time": "'$(date +%s)'", "release": "'$1'"}' > "${CONFIG_DIR}/genesis.json"
    echo "ITERATION_RELEASE=$1" > "${CONFIG_DIR}/retention.vars"
    echo "GENESIS_RESET_INTERVAL=86400" >> "${CONFIG_DIR}/retention.vars"
    return
  fi
  
  # Orchestrate the reset process in proper sequence
  stop_clients
  clear_datadirs
  download_genesis_release "$1"
  setup_genesis
  start_clients
  echo "$(date) - Reset completed successfully"
}

# check_testnet()
# Purpose: Checks if the testnet needs to be reset based on genesis time
# Usage: check_testnet
check_testnet() {
  # Get current time as Unix timestamp
  current_time=$(date +%s)

  # Try to get genesis time from beacon node API or from file in test mode
  if [ "$TEST_MODE" = true ]; then
    # In test mode, get genesis time from the mock genesis file
    genesis_time=$(get_genesis_time)
    echo "Test mode: Using genesis time from file: ${genesis_time}"
    
    # In test mode, check if the genesis time file has changed
    if [ -f "${GENESIS_TIME_FILE}" ]; then
      file_genesis_time=$(cat "${GENESIS_TIME_FILE}")
      if [ "${file_genesis_time}" != "${genesis_time}" ]; then
        echo "Reset detected: Genesis time changed from ${genesis_time} to ${file_genesis_time}"
        reset_testnet "test-release-$(date +%s)"
        return
      fi
    fi
    
    # In test mode, if the genesis time is more than 1 day old, consider it a reset
    if [ $((current_time - genesis_time)) -gt 86400 ]; then
      echo "Reset detected: Genesis time is more than 1 day old"
      reset_testnet "test-release-$(date +%s)"
      return
    fi
  else
    # In normal mode, get genesis time from beacon node API
    genesis_time=$(curl -s http://localhost:${CL_PORT}/eth/v1/beacon/genesis \
      | sed 's/.*"genesis_time":"\{0,1\}\([^,"]*\)"\{0,1\}.*/\1/' 2>/dev/null)
  fi

  # If we can't get a valid genesis time, may need recovery or reset
  if ! [[ ${genesis_time} =~ ^[0-9]+$ ]]; then
    echo "$(date) - Could not get valid genesis time from beacon node, checking if reset needed..."
    # Check if we have a genesis file already
    if [ -f "${CONFIG_DIR}/genesis.json" ]; then
      # Try to restart the clients first
      stop_clients
      sleep 5
      start_clients
      sleep 10
      # Try again to get genesis time
      genesis_time=$(curl -s http://localhost:${CL_PORT}/eth/v1/beacon/genesis \
        | sed 's/.*"genesis_time":"\{0,1\}\([^,"]*\)"\{0,1\}.*/\1/' 2>/dev/null)
      if ! [[ ${genesis_time} =~ ^[0-9]+$ ]]; then
        # If still can't get genesis time, force a reset
        echo "$(date) - Still could not get genesis time after restart, forcing reset..."
        reset_testnet $(get_github_release ${GENESIS_REPO})
      fi
    else
      # No genesis file, need initial setup
      echo "$(date) - No genesis file found, performing initial setup..."
      reset_testnet $(get_github_release ${GENESIS_REPO})
    fi
    return
  fi

  # Check if retention vars file exists
  if ! [ -f "${CONFIG_DIR}/retention.vars" ]; then
    # Create default retention vars if missing
    echo "$(date) - Could not find retention.vars, creating default..."
    echo "CHAIN_ID=unknown" >"${CONFIG_DIR}/retention.vars"
    echo "ITERATION_RELEASE=unknown" >>"${CONFIG_DIR}/retention.vars"
    echo "GENESIS_RESET_INTERVAL=86400" >>"${CONFIG_DIR}/retention.vars" # Default 1 day
  fi

  # Source the retention vars file to get variables
  source "${CONFIG_DIR}/retention.vars"

  # Calculate timeout (5 minutes before actual reset)
  testnet_timeout=$(expr "${genesis_time}" + "${GENESIS_RESET_INTERVAL:-86400}" - 300)
  time_left=$(expr "${testnet_timeout}" - "${current_time}")
  echo "$(date) - Genesis timeout: ${time_left} seconds remaining"

  # Check if it's time to reset
  if [ "${testnet_timeout}" -le "${current_time}" ]; then
    echo "$(date) - Testnet timeout reached, checking for new genesis release..."
    genesis_release=$(get_github_release ${GENESIS_REPO})

    # Set default ITERATION_RELEASE if not defined
    if ! [ -n "${ITERATION_RELEASE}" ]; then
      ITERATION_RELEASE=${CHAIN_ID:-unknown}
    fi

    # Check if there's a new release
    if [ "${genesis_release}" = "${ITERATION_RELEASE}" ]; then
      echo "$(date) - Could not find new genesis release (current: ${genesis_release})"
      return
    fi

    # New release found, perform reset
    echo "$(date) - New genesis release found: ${genesis_release}, resetting..."
    reset_testnet "${genesis_release}"
  else
    echo "$(date) - No reset needed at this time"
  fi
}

# Function to clean up configuration directory
clean_config_dir() {
  echo "Cleaning configuration directory..."
  # Use ${var:?} to ensure CONFIG_DIR is not empty before removing files
  rm -rf "${CONFIG_DIR:?}/"*
}

# main()
# Purpose: Controls the overall script execution flow
# Usage: main
main() {
  echo "$(date) - Starting Ephemery retention check..."

  # Create necessary directories
  mkdir -p "${CONFIG_DIR}"
  mkdir -p "${DATA_DIR}"
  mkdir -p "${LOG_DIR}"

  # In test mode, skip actual client operations
  if [ "$TEST_MODE" = true ]; then
    echo "Running in test mode, skipping actual client operations"
    # Create a mock genesis file if it doesn't exist
    if ! [ -f "${CONFIG_DIR}/genesis.json" ]; then
      echo '{"genesis_time": "'$(date +%s)'"}' > "${CONFIG_DIR}/genesis.json"
    fi
  fi

  # Check if genesis file exists
  if ! [ -f "${CONFIG_DIR}/genesis.json" ]; then
    # No genesis file, need initial setup
    echo "$(date) - No genesis file found, performing initial setup..."
    if [ "$TEST_MODE" = true ]; then
      echo "Test mode: Would download genesis files and initialize clients"
    else
      reset_testnet $(get_github_release ${GENESIS_REPO})
    fi
  else
    # Genesis file exists, check if reset needed
    check_testnet
  fi

  echo "$(date) - Retention check completed"
}

# Run the main function
main
