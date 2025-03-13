#!/bin/bash

# Ephemery Node Setup Script
# This script automates the setup of Ephemery nodes based on best practices

# Source common configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [ -f "$SCRIPT_DIR/scripts/core/ephemery_config.sh" ]; then
  source "$SCRIPT_DIR/scripts/core/ephemery_config.sh"
else
  # Fallback to local definitions if common config not found
  # Color definitions
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
  
  # Define default settings
  EPHEMERY_BASE_DIR=~/ephemery
  EPHEMERY_GETH_CACHE=4096
  EPHEMERY_TARGET_PEERS=100
  EPHEMERY_EXECUTION_TIMEOUT=10
  EPHEMERY_DOCKER_NETWORK="ephemery-net"
  
  # Default checkpoint sync URLs in order of preference
  EPHEMERY_CHECKPOINT_URLS=(
    "https://checkpoint-sync.holesky.ethpandaops.io"
    "https://beaconstate-holesky.chainsafe.io"
    "https://checkpoint-sync.ephemery.dev"
    "https://checkpoint.ephemery.eth.limo"
  )
fi

# Color definitions if not defined by common config
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
RED=${RED:-'\033[0;31m'}
BLUE=${BLUE:-'\033[0;34m'}
NC=${NC:-'\033[0m'}

# Define script-specific settings
USE_CHECKPOINT_SYNC=true
RESET_DATABASE=false
CHECKPOINT_URL=""

# Function to show help
show_help() {
  echo -e "${BLUE}Ephemery Node Setup Script${NC}"
  echo ""
  echo "This script automates the setup of Ephemery nodes with optimized settings."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --checkpoint-sync       Enable checkpoint sync (default: enabled)"
  echo "  --no-checkpoint-sync    Disable checkpoint sync"
  echo "  --checkpoint-url URL    Specify a custom checkpoint sync URL"
  echo "  --reset                 Reset database before starting"
  echo "  --base-dir PATH         Specify a custom base directory (default: ~/ephemery)"
  echo "  --geth-cache SIZE       Specify Geth cache size in MB (default: 4096)"
  echo "  --target-peers COUNT    Specify target peer count (default: 100)"
  echo "  --help                  Display this help message"
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --checkpoint-sync)
      USE_CHECKPOINT_SYNC=true
      shift
      ;;
    --no-checkpoint-sync)
      USE_CHECKPOINT_SYNC=false
      shift
      ;;
    --checkpoint-url)
      CHECKPOINT_URL="$2"
      shift 2
      ;;
    --reset)
      RESET_DATABASE=true
      shift
      ;;
    --base-dir)
      EPHEMERY_BASE_DIR="$2"
      shift 2
      ;;
    --geth-cache)
      EPHEMERY_GETH_CACHE="$2"
      shift 2
      ;;
    --target-peers)
      EPHEMERY_TARGET_PEERS="$2"
      shift 2
      ;;
    --help)
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

echo -e "${BLUE}Setting up Ephemery node environment...${NC}"

# Create directories
if type ensure_directories &>/dev/null; then
  ensure_directories
else
  mkdir -p ${EPHEMERY_BASE_DIR}/data/geth
  mkdir -p ${EPHEMERY_BASE_DIR}/data/lighthouse
  mkdir -p ${EPHEMERY_BASE_DIR}/config
  mkdir -p ${EPHEMERY_BASE_DIR}/logs
  mkdir -p ${EPHEMERY_BASE_DIR}/secrets
fi

# Network Configuration
echo -e "${BLUE}Creating Docker network...${NC}"
if type ensure_network &>/dev/null; then
  ensure_network
else
  docker network create ${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"} || echo "Network already exists"
fi

# JWT Authentication
echo -e "${BLUE}Creating JWT secret...${NC}"
if type ensure_jwt_secret &>/dev/null; then
  ensure_jwt_secret
else
  if [ ! -f ${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"} ]; then
    openssl rand -hex 32 > ${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}
    chmod 600 ${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}
  fi
fi

# Checkpoint sync setup
if [ "$USE_CHECKPOINT_SYNC" = true ]; then
    echo -e "${BLUE}Setting up checkpoint sync...${NC}"
    
    # If no custom URL specified, test default URLs and find best one
    if [ -z "$CHECKPOINT_URL" ]; then
        echo -e "${YELLOW}Testing checkpoint sync URLs for availability...${NC}"
        for url in "${EPHEMERY_CHECKPOINT_URLS[@]}"; do
            echo -e "Testing $url..."
            if curl --connect-timeout 5 --max-time 10 -s "$url" > /dev/null; then
                echo -e "${GREEN}✓ URL is accessible${NC}"
                CHECKPOINT_URL="$url"
                break
            else
                echo -e "${RED}✗ URL is not accessible${NC}"
            fi
        done
        
        if [ -z "$CHECKPOINT_URL" ]; then
            echo -e "${RED}No accessible checkpoint sync URL found. Falling back to genesis sync.${NC}"
            USE_CHECKPOINT_SYNC=false
        else
            echo -e "${GREEN}Using checkpoint sync URL: $CHECKPOINT_URL${NC}"
        fi
    else
        echo -e "${BLUE}Using provided checkpoint sync URL: $CHECKPOINT_URL${NC}"
        # Verify the provided URL is accessible
        if ! curl --connect-timeout 5 --max-time 10 -s "$CHECKPOINT_URL" > /dev/null; then
            echo -e "${RED}Warning: Provided checkpoint URL doesn't seem to be accessible.${NC}"
            echo -e "${YELLOW}Will continue with this URL, but sync may fail.${NC}"
        fi
    fi
fi

# Reset database if requested
if [ "$RESET_DATABASE" = true ]; then
    echo -e "${YELLOW}Resetting database as requested...${NC}"
    rm -rf ${EPHEMERY_BASE_DIR}/data/geth/*
    rm -rf ${EPHEMERY_BASE_DIR}/data/lighthouse/*
    echo -e "${GREEN}Database reset complete${NC}"
fi

# Stop and remove any existing containers
echo -e "${BLUE}Cleaning up any existing containers...${NC}"
docker stop ephemery-geth ephemery-lighthouse 2>/dev/null || true
docker rm ephemery-geth ephemery-lighthouse 2>/dev/null || true

# Start Geth (Execution Layer) with optimized parameters
echo -e "${BLUE}Starting Geth execution layer...${NC}"
docker run -d --name ephemery-geth --network ${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"} \
  -v ${EPHEMERY_BASE_DIR}/data/geth:/ethdata \
  -v ${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}:/config/jwt-secret \
  -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
  ${EPHEMERY_GETH_IMAGE:-"pk910/ephemery-geth:latest"} \
  --http.addr 0.0.0.0 --authrpc.addr 0.0.0.0 --authrpc.vhosts "*" \
  --authrpc.jwtsecret /config/jwt-secret \
  --cache=${EPHEMERY_GETH_CACHE} --txlookuplimit=0 --syncmode=snap --maxpeers=${EPHEMERY_TARGET_PEERS}

echo -e "${BLUE}Waiting 10 seconds for Geth to initialize...${NC}"
sleep 10

# Prepare Lighthouse command with base parameters
LIGHTHOUSE_CMD="lighthouse beacon --datadir /ethdata --testnet-dir=/ephemery_config \
  --execution-jwt /config/jwt-secret --execution-endpoint http://ephemery-geth:8551 \
  --http --http-address 0.0.0.0 --http-port 5052 \
  --metrics --metrics-address 0.0.0.0 --metrics-port 8008 \
  --target-peers ${EPHEMERY_TARGET_PEERS} --execution-timeout-multiplier ${EPHEMERY_EXECUTION_TIMEOUT} \
  --disable-deposit-contract-sync"

# Add checkpoint sync if enabled
if [ "$USE_CHECKPOINT_SYNC" = true ] && [ ! -z "$CHECKPOINT_URL" ]; then
    LIGHTHOUSE_CMD="${LIGHTHOUSE_CMD} --checkpoint-sync-url=${CHECKPOINT_URL}"
else
    # Add genesis sync optimizations if not using checkpoint sync
    LIGHTHOUSE_CMD="${LIGHTHOUSE_CMD} --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
fi

# Start Lighthouse (Consensus Layer)
echo -e "${BLUE}Starting Lighthouse consensus layer...${NC}"
docker run -d --name ephemery-lighthouse --network ${EPHEMERY_DOCKER_NETWORK:-"ephemery-net"} \
  -v ${EPHEMERY_BASE_DIR}/data/lighthouse:/ethdata \
  -v ${EPHEMERY_JWT_SECRET:-"${EPHEMERY_BASE_DIR}/jwt.hex"}:/config/jwt-secret \
  -v ${EPHEMERY_BASE_DIR}/config:/ephemery_config \
  -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
  ${EPHEMERY_LIGHTHOUSE_IMAGE:-"pk910/ephemery-lighthouse:latest"} \
  ${LIGHTHOUSE_CMD}

# Save checkpoint URL for future reference
if [ "$USE_CHECKPOINT_SYNC" = true ] && [ ! -z "$CHECKPOINT_URL" ]; then
    echo "$CHECKPOINT_URL" > ${EPHEMERY_BASE_DIR}/checkpoint_url.txt
fi

echo -e "${GREEN}Ephemery node setup complete!${NC}"
echo ""
if [ "$USE_CHECKPOINT_SYNC" = true ] && [ ! -z "$CHECKPOINT_URL" ]; then
    echo -e "${GREEN}Checkpoint sync enabled with URL: ${CHECKPOINT_URL}${NC}"
    echo -e "${YELLOW}Initial sync should be significantly faster than genesis sync.${NC}"
else
    if [ "$USE_CHECKPOINT_SYNC" = true ]; then
        echo -e "${RED}Checkpoint sync was enabled but no working URL was found.${NC}"
        echo -e "${YELLOW}Falling back to genesis sync which will take longer.${NC}"
    else
        echo -e "${YELLOW}Running with genesis sync. This may take several hours.${NC}"
    fi
fi
echo ""
echo -e "${BLUE}Verification:${NC}"
echo "- Geth API (after initialization): curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:8545"
echo "- Lighthouse API: curl -X GET http://localhost:5052/eth/v1/node/syncing -H \"Content-Type: application/json\""
echo ""
echo -e "${BLUE}Monitor logs:${NC}"
echo "- Geth: docker logs -f ephemery-geth"
echo "- Lighthouse: docker logs -f ephemery-lighthouse"
echo ""
echo -e "${YELLOW}Initial sync may take several hours. During this time, it's normal to see errors related to execution payload.${NC}" 