#!/bin/bash
#
# Ephemery Reset Script
# This script resets the Ephemery testnet nodes to the latest iteration.
# Recommended usage: Set up a daily cron job to run this script
# Example cron: 0 0 * * * /opt/ephemery/scripts/reset_ephemery.sh > /opt/ephemery/logs/reset.log 2>&1
#

set -e

# Configuration
HOME_DIR="/root/ephemery"
DATA_DIR="$HOME_DIR/data"
CONFIG_DIR="$HOME_DIR/config"
LOG_DIR="$HOME_DIR/logs"
GENESIS_REPO="ephemery-testnet/ephemery-genesis"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

echo "$(date) - Starting Ephemery reset process"

# Stop containers
echo "Stopping containers..."
docker stop ephemery-geth ephemery-lighthouse || true

# Clear data directories
echo "Clearing data directories..."
rm -rf "${DATA_DIR}/geth/"* "${DATA_DIR}/beacon/"*

# Download latest genesis files
echo "Downloading latest genesis files..."
LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/$GENESIS_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)

echo "Latest release: $LATEST_RELEASE"
mkdir -p "$CONFIG_DIR"
wget -qO- "https://github.com/$GENESIS_REPO/releases/download/$LATEST_RELEASE/testnet-all.tar.gz" | tar xvz -C "$CONFIG_DIR"

# Initialize execution client (Geth)
echo "Initializing Geth with new genesis..."
docker run --rm -v "${DATA_DIR}/geth:/data" -v "${CONFIG_DIR}:/config" pk910/ephemery-geth geth init --datadir=/data /config/genesis.json

# Start containers
echo "Starting containers..."
docker start ephemery-geth
sleep 10  # Wait for Geth to start
docker start ephemery-lighthouse

# Restart monitoring
echo "Restarting monitoring services..."
docker restart prometheus grafana-agent || true

echo "$(date) - Ephemery reset completed successfully"
