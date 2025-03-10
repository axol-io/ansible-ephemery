#!/bin/bash

# Script to run Ephemery with Geth and Lighthouse locally
# For more advanced options, use with a local-inventory.yaml file

set -e

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -i, --inventory FILE     Optional: Specify inventory file"
    echo "  -h, --help               Display this help message"
    echo
    echo "Examples:"
    echo "  $0"
    echo "  $0 --inventory config/local-inventory.yaml"
    echo
    echo "You can create an inventory file based on the example in config/local-inventory.yaml.example"
}

# Parse command line options
INVENTORY_FILE=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Source the inventory parser utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/parse_inventory.sh"

# Parse inventory file if provided
if [ -n "$INVENTORY_FILE" ]; then
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "Error: Inventory file '$INVENTORY_FILE' not found"
        exit 1
    fi

    echo "Loading configuration from $INVENTORY_FILE"
    parse_local_inventory "$INVENTORY_FILE"
fi

# Set default values if not provided by inventory
EPHEMERY_BASE_DIR=${EPHEMERY_BASE_DIR:-$HOME/ephemery-local}
EPHEMERY_DATA_DIR=${EPHEMERY_DATA_DIR:-$EPHEMERY_BASE_DIR/data}
EPHEMERY_LOGS_DIR=${EPHEMERY_LOGS_DIR:-$EPHEMERY_BASE_DIR/logs}
JWT_SECRET_PATH=${JWT_SECRET_PATH:-$EPHEMERY_BASE_DIR/jwt.hex}

# Set default client images and parameters
GETH_IMAGE=${GETH_IMAGE:-pk910/ephemery-geth:v1.15.3}
GETH_CACHE=${GETH_CACHE:-4096}
GETH_MAX_PEERS=${GETH_MAX_PEERS:-100}
LIGHTHOUSE_IMAGE=${LIGHTHOUSE_IMAGE:-pk910/ephemery-lighthouse:latest}
LIGHTHOUSE_TARGET_PEERS=${LIGHTHOUSE_TARGET_PEERS:-100}

echo "Setting up Ephemery with Geth and Lighthouse locally"
echo "--------------------------------------------------------------"

# Create directories
mkdir -p $EPHEMERY_BASE_DIR
mkdir -p $EPHEMERY_DATA_DIR/geth
mkdir -p $EPHEMERY_DATA_DIR/lighthouse
mkdir -p $EPHEMERY_LOGS_DIR

# Generate JWT secret
if [ ! -f $JWT_SECRET_PATH ]; then
    echo "Generating JWT secret..."
    openssl rand -hex 32 | tr -d "\n" > $JWT_SECRET_PATH
    chmod 600 $JWT_SECRET_PATH
fi

# Create Docker network
if ! docker network inspect ephemery &>/dev/null; then
    docker network create ephemery
fi

# Clean existing containers
echo "Removing any existing containers..."
docker rm -f ephemery-geth 2>/dev/null || true
docker rm -f ephemery-lighthouse 2>/dev/null || true

# Start Geth with optimizations
echo "Starting Geth execution client with optimizations..."
docker run -d --name ephemery-geth \
    --network ephemery \
    -v $EPHEMERY_DATA_DIR/geth:/ethdata \
    -v $JWT_SECRET_PATH:/config/jwt-secret \
    -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
    $GETH_IMAGE \
    --datadir /ethdata \
    --http --http.api eth,net,engine,admin --http.addr 0.0.0.0 \
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /config/jwt-secret \
    --cache=$GETH_CACHE \
    --txlookuplimit=0 \
    --syncmode=snap \
    --maxpeers=$GETH_MAX_PEERS \
    --db.engine=pebble

# Wait for Geth
echo "Waiting for Geth to initialize..."
sleep 10

# Start Lighthouse with optimizations
echo "Starting Lighthouse consensus client with optimizations..."
docker run -d --name ephemery-lighthouse \
    --network ephemery \
    -v $EPHEMERY_DATA_DIR/lighthouse:/ethdata \
    -v $JWT_SECRET_PATH:/config/jwt-secret \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    $LIGHTHOUSE_IMAGE \
    lighthouse beacon \
    --datadir /ethdata \
    --testnet-dir /ephemery_config \
    --execution-jwt /config/jwt-secret \
    --execution-endpoint http://ephemery-geth:8551 \
    --http --http-address 0.0.0.0 --http-port 5052 \
    --target-peers=$LIGHTHOUSE_TARGET_PEERS \
    --execution-timeout-multiplier=5 \
    --allow-insecure-genesis-sync \
    --genesis-backfill \
    --disable-backfill-rate-limiting \
    --disable-deposit-contract-sync

echo "--------------------------------------------------------------"
echo "Ephemery node is running locally with optimized settings"
echo "Geth execution API: http://localhost:8545"
echo "Lighthouse consensus API: http://localhost:5052"
echo
echo "To monitor the sync status:"
echo "  - Execution client: docker logs -f ephemery-geth"
echo "  - Consensus client: docker logs -f ephemery-lighthouse"
echo
echo "To stop the nodes:"
echo "  docker stop ephemery-geth ephemery-lighthouse"
echo "--------------------------------------------------------------"
