#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Ephemery Reset Script
# This script resets the Ephemery testnet nodes to the latest iteration.
# Recommended usage: Set up a daily cron job to run this script
# Example cron: 0 0 * * * /opt/ephemery/scripts/reset_ephemery.sh > /opt/ephemery/logs/reset.log 2>&1
#

set -e

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo "Loading configuration from ${CONFIG_FILE}"
  source "${CONFIG_FILE}"
else
  echo "Configuration file not found, using default paths"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
fi

# Configuration
GENESIS_REPO="ephemery-testnet/ephemery-genesis"

# Create log directory if it doesn't exist
mkdir -p "${EPHEMERY_LOGS_DIR}"

echo "$(date) - Starting Ephemery reset process"

# Stop containers
echo "Stopping containers..."
docker stop ephemery-geth ephemery-lighthouse || true

# Clear data directories
echo "Clearing data directories..."
rm -rf "${EPHEMERY_DATA_DIR}/geth/"* "${EPHEMERY_DATA_DIR}/beacon/"*

# Download latest genesis files
echo "Downloading latest genesis files..."
LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/${GENESIS_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)

echo "Latest release: ${LATEST_RELEASE}"
mkdir -p "${EPHEMERY_CONFIG_DIR}"
wget -qO- "https://github.com/${GENESIS_REPO}/releases/download/${LATEST_RELEASE}/testnet-all.tar.gz" | tar xvz -C "${EPHEMERY_CONFIG_DIR}"

# Initialize execution client (Geth)
echo "Initializing Geth with new genesis..."
docker run --rm -v "${EPHEMERY_DATA_DIR}/geth:/data" -v "${EPHEMERY_CONFIG_DIR}:/config" pk910/ephemery-geth geth init --datadir=/data /config/genesis.json

# Start containers
echo "Starting containers..."
docker start ephemery-geth
sleep 10 # Wait for Geth to start
docker start ephemery-lighthouse

# Restart monitoring
echo "Restarting monitoring services..."
docker restart prometheus grafana-agent || true

echo "$(date) - Ephemery reset completed successfully"
