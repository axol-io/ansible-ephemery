#!/bin/bash
# Version: 1.0.0

# Main demo script for Ephemery - runs a local instance for demonstration purposes
# For more advanced usage, see scripts in the scripts/ directory

set -e

echo "Ephemery Local Demo - Running a local Ephemery node"
echo "===================================================="
echo "This script will set up and run a local Ephemery node with Geth and Lighthouse"
echo "For remote deployment or advanced configuration, see the scripts/ directory"
echo

# Load configuration file if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo "Loading configuration from ${CONFIG_FILE}"
  source "${CONFIG_FILE}"
else
  echo "Configuration file not found, using default paths"
  # Define default paths
  EPHEMERY_BASE_DIR=${HOME}/ephemery-demo
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi

mkdir -p "${EPHEMERY_BASE_DIR}"
mkdir -p "${EPHEMERY_DATA_DIR}"/geth
mkdir -p "${EPHEMERY_DATA_DIR}"/lighthouse
mkdir -p "${EPHEMERY_LOGS_DIR}"
mkdir -p "${EPHEMERY_CONFIG_DIR}"

# Generate JWT secret
if [ ! -f "${EPHEMERY_JWT_SECRET}" ]; then
  echo "Generating JWT secret..."
  mkdir -p "$(dirname "${EPHEMERY_JWT_SECRET}")"
  openssl rand -hex 32 | tr -d "\n" >"${EPHEMERY_JWT_SECRET}"
  chmod 600 "${EPHEMERY_JWT_SECRET}"
fi

# Create Docker network
if ! docker network inspect ephemery &>/dev/null; then
  echo "Creating Docker network..."
  docker network create ephemery
fi

# Clean existing containers
echo "Removing any existing containers..."
docker rm -f ephemery-geth 2>/dev/null || true
docker rm -f ephemery-lighthouse 2>/dev/null || true

# Start Geth
echo "Starting Geth execution client..."
docker run -d --name ephemery-geth \
  --network ephemery \
  -v "${EPHEMERY_DATA_DIR}"/geth:/ethdata \
  -v "${EPHEMERY_JWT_SECRET}":/config/jwt-secret \
  -p 8545:8545 -p 8551:8551 \
  pk910/ephemery-geth:v1.15.3 \
  --datadir /ethdata \
  --http --http.api eth,net,engine,admin --http.addr 0.0.0.0 \
  --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /config/jwt-secret

# Wait for Geth
echo "Waiting for Geth to initialize..."
sleep 5

# Start Lighthouse
echo "Starting Lighthouse consensus client..."
docker run -d --name ephemery-lighthouse \
  --network ephemery \
  -v "${EPHEMERY_DATA_DIR}"/lighthouse:/ethdata \
  -v "${EPHEMERY_JWT_SECRET}":/config/jwt-secret \
  -p 5052:5052 \
  pk910/ephemery-lighthouse:latest \
  lighthouse beacon \
  --datadir /ethdata \
  --testnet-dir /ephemery_config \
  --execution-jwt /config/jwt-secret \
  --execution-endpoint http://ephemery-geth:8551 \
  --http --http-address 0.0.0.0 --http-port 5052 \
  --allow-insecure-genesis-sync

echo "===================================================="
echo "Ephemery demo node is running!"
echo "Geth execution API: http://localhost:8545"
echo "Lighthouse consensus API: http://localhost:5052"
echo
echo "For more advanced configurations, see the scripts in scripts/ directory"
echo "Documentation available in docs/ directory"
echo
echo "To monitor logs:"
echo "  docker logs -f ephemery-geth"
echo "  docker logs -f ephemery-lighthouse"
echo
echo "To stop the demo:"
echo "  docker stop ephemery-geth ephemery-lighthouse"
echo "===================================================="
