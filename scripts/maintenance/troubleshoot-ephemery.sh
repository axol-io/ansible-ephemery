#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Ephemery Testnet Node Troubleshooting Script
# This script helps diagnose and fix common issues with Ephemery testnet nodes

# Color codes for better readability

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "${BLUE}Loading configuration from ${CONFIG_FILE}${NC}"
  source "${CONFIG_FILE}"
else
  echo -e "${YELLOW}Configuration file not found, using default paths${NC}"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
  EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi

echo -e "${GREEN}=======================================${NC}"
echo -e "${BLUE}Ephemery Testnet Troubleshooting Script${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo -e "${RED}This script must be run as root${NC}"
  exit 1
fi

# Function to check if a directory exists
check_dir() {
  if [ -d "$1" ]; then
    echo -e "${GREEN}✓ Directory $1 exists${NC}"
  else
    echo -e "${RED}✗ Directory $1 does not exist${NC}"
    echo -e "${YELLOW}Creating directory $1${NC}"
    mkdir -p "$1"
  fi
}

# Function to check if a file exists
check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}✓ File $1 exists${NC}"
  else
    echo -e "${RED}✗ File $1 does not exist${NC}"
    return 1
  fi
  return 0
}

# Function to check sync issues and optimize sync performance
check_sync_issues() {
  echo -e "${YELLOW}Checking for consensus client sync issues...${NC}"

  # Check if lighthouse container exists and is running
  LIGHTHOUSE_CONTAINER=$(docker ps -a --format "{{.Names}}" | grep -E "ephemery-lighthouse|lighthouse")
  if [ -z "${LIGHTHOUSE_CONTAINER}" ]; then
    echo -e "${RED}✗ No Lighthouse container found${NC}"
    return
  fi

  echo -e "${GREEN}✓ Found Lighthouse container: ${LIGHTHOUSE_CONTAINER}${NC}"

  # Check container status
  CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "${LIGHTHOUSE_CONTAINER}")
  if [ "${CONTAINER_STATUS}" != "running" ]; then
    echo -e "${RED}✗ Lighthouse container is not running (status: ${CONTAINER_STATUS})${NC}"

    # Check for recent errors in logs
    echo -e "${YELLOW}Recent errors in logs:${NC}"
    docker logs --tail 20 "${LIGHTHOUSE_CONTAINER}" | grep -E "ERROR|WARN|CRIT"

    # Check for common bootstrap node issues
    BOOTSTRAP_ERRORS=$(docker logs --tail 50 "${LIGHTHOUSE_CONTAINER}" | grep -i "Missing UDP in Multiaddr")
    if [ -n "${BOOTSTRAP_ERRORS}" ]; then
      echo -e "${RED}✗ Bootstrap node address format errors detected${NC}"
      echo -e "${YELLOW}Bootstrap addresses need UDP protocol information${NC}"
      echo -e "${GREEN}Recommendation: Use format: /ip4/IP/tcp/9000/udp/9000/p2p/ID${NC}"
    fi

    # Check for SSZ issues
    SSZ_ERRORS=$(docker logs --tail 50 "${LIGHTHOUSE_CONTAINER}" | grep -i "InvalidSsz")
    if [ -n "${SSZ_ERRORS}" ]; then
      echo -e "${RED}✗ Checkpoint state loading errors detected${NC}"
      echo -e "${YELLOW}Remote checkpoint data may be invalid${NC}"
      echo -e "${GREEN}Recommendation: Try genesis sync with --allow-insecure-genesis-sync flag${NC}"
    fi

    # Check for duplicate arguments
    DUPLICATE_ERRORS=$(docker logs --tail 50 "${LIGHTHOUSE_CONTAINER}" | grep -i "cannot be used multiple times")
    if [ -n "${DUPLICATE_ERRORS}" ]; then
      echo -e "${RED}✗ Duplicate command line parameters detected${NC}"
      echo -e "${GREEN}Recommendation: Remove duplicate parameters in the container command${NC}"
    fi
  else
    echo -e "${GREEN}✓ Lighthouse container is running${NC}"

    # Check sync status
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
      SYNC_STATUS=$(curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null)
      PEER_COUNT=$(curl -s http://localhost:5052/eth/v1/node/peer_count 2>/dev/null)

      if [ -n "${SYNC_STATUS}" ]; then
        echo -e "${GREEN}Sync status:${NC}"
        echo "${SYNC_STATUS}" | jq 2>/dev/null || echo "${SYNC_STATUS}"

        # Extract sync information
        IS_SYNCING=$(echo "${SYNC_STATUS}" | grep -o '"is_syncing":[^,]*' | cut -d':' -f2 | tr -d ' "')
        HEAD_SLOT=$(echo "${SYNC_STATUS}" | grep -o '"head_slot":"[^"]*"' | cut -d'"' -f4)
        SYNC_DISTANCE=$(echo "${SYNC_STATUS}" | grep -o '"sync_distance":"[^"]*"' | cut -d'"' -f4)

        # Extract peer count
        CONNECTED_PEERS=$(echo "${PEER_COUNT}" | grep -o '"connected":"[^"]*"' | cut -d'"' -f4)

        if [ "${CONNECTED_PEERS}" -lt 10 ]; then
          echo -e "${RED}✗ Low peer count (${CONNECTED_PEERS} peers) - this will slow sync${NC}"
          echo -e "${GREEN}Recommendation: Optimize bootstrap nodes and increase target peers${NC}"
        else
          echo -e "${GREEN}✓ Good peer count: ${CONNECTED_PEERS} peers${NC}"
        fi

        if [ "${IS_SYNCING}" = "true" ] && [ "${HEAD_SLOT}" -eq 0 ]; then
          echo -e "${RED}✗ Sync stuck at genesis (head slot: ${HEAD_SLOT}, distance: ${SYNC_DISTANCE})${NC}"
          echo -e "${GREEN}Recommendation: Clear database and try checkpoint sync or genesis sync${NC}"
        fi
      else
        echo -e "${RED}✗ Unable to get sync status from API${NC}"
      fi
    else
      echo -e "${RED}✗ curl or jq not installed, can't check sync status${NC}"
    fi
  fi

  echo -e "\n${YELLOW}Sync Optimization Recommendations:${NC}"
  echo -e "1. ${GREEN}Clear database and restart:${NC}"
  echo -e "   rm -rf /opt/ephemery/ephemery/data/lighthouse/beacon"
  echo -e "2. ${GREEN}Ensure bootstrap nodes have UDP format:${NC}"
  echo -e "   /ip4/IP/tcp/9000/udp/9000/p2p/ID"
  echo -e "3. ${GREEN}For genesis sync issues:${NC}"
  echo -e "   Add --allow-insecure-genesis-sync flag"
  echo -e "4. ${GREEN}For better performance:${NC}"
  echo -e "   --target-peers=150 --disable-deposit-contract-sync --import-all-attestations --disable-backfill-rate-limiting"
}

# Check directory structure
echo -e "${YELLOW}Checking directory structure...${NC}"
check_dir "/opt/ephemery"
check_dir "/opt/ephemery/data"
check_dir "/opt/ephemery/data/geth"
check_dir "/opt/ephemery/data/lighthouse"
check_dir "/opt/ephemery/data/validator"
check_dir "/opt/ephemery/config/ephemery_network"

# Check JWT token
echo -e "\n${YELLOW}Checking JWT token...${NC}"
if ! check_file "/opt/ephemery/jwt.hex"; then
  echo -e "${YELLOW}Creating new JWT token...${NC}"
  openssl rand -hex 32 >/opt/ephemery/jwt.hex
  echo -e "${GREEN}Created new JWT token${NC}"
fi

# Check Docker
echo -e "\n${YELLOW}Checking Docker...${NC}"
if command -v docker &>/dev/null; then
  echo -e "${GREEN}✓ Docker is installed${NC}"
else
  echo -e "${RED}✗ Docker is not installed${NC}"
  echo -e "${YELLOW}Please install Docker before proceeding${NC}"
  exit 1
fi

# Check running containers
echo -e "\n${YELLOW}Checking running containers...${NC}"
GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)
VALIDATOR_RUNNING=$(docker ps -q -f name=ephemery-validator-lighthouse)

if [ -z "${GETH_RUNNING}" ]; then
  echo -e "${RED}✗ Geth container is not running${NC}"
else
  echo -e "${GREEN}✓ Geth container is running${NC}"
fi

if [ -z "${LIGHTHOUSE_RUNNING}" ]; then
  echo -e "${RED}✗ Lighthouse container is not running${NC}"
else
  echo -e "${GREEN}✓ Lighthouse container is running${NC}"
fi

if [ -z "${VALIDATOR_RUNNING}" ]; then
  echo -e "${RED}✗ Validator container is not running${NC}"
else
  echo -e "${GREEN}✓ Validator container is running${NC}"
fi

# Check network connectivity
echo -e "\n${YELLOW}Checking network connectivity...${NC}"
if [ ! -z "${GETH_RUNNING}" ]; then
  PEER_COUNT=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

  if [ -z "${PEER_COUNT}" ]; then
    echo -e "${RED}✗ Could not get peer count from Geth${NC}"
  else
    PEER_COUNT_DEC=$((16#${PEER_COUNT:2}))
    if [ "${PEER_COUNT_DEC}" -eq 0 ]; then
      echo -e "${RED}✗ Geth has no peers (count: ${PEER_COUNT_DEC})${NC}"
      echo -e "${YELLOW}Suggestion: Check firewall settings and internet connectivity${NC}"
    else
      echo -e "${GREEN}✓ Geth has ${PEER_COUNT_DEC} peers${NC}"
    fi
  fi
fi

if [ ! -z "${LIGHTHOUSE_RUNNING}" ]; then
  LH_PEER_COUNT=$(curl -s http://localhost:5052/eth/v1/node/peer_count 2>/dev/null | grep -o '"connected":"[^"]*"' | cut -d'"' -f4)

  if [ -z "${LH_PEER_COUNT}" ]; then
    echo -e "${RED}✗ Could not get peer count from Lighthouse${NC}"
  else
    if [ "${LH_PEER_COUNT}" -eq 0 ]; then
      echo -e "${RED}✗ Lighthouse has no peers (count: ${LH_PEER_COUNT})${NC}"
      echo -e "${YELLOW}Suggestion: Check boot nodes configuration${NC}"
    else
      echo -e "${GREEN}✓ Lighthouse has ${LH_PEER_COUNT} peers${NC}"
    fi
  fi

  # Check sync status
  LH_SYNC_STATUS=$(curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null)
  IS_SYNCING=$(echo "${LH_SYNC_STATUS}" | grep -o '"is_syncing":[^,]*' | cut -d':' -f2)
  HEAD_SLOT=$(echo "${LH_SYNC_STATUS}" | grep -o '"head_slot":"[^"]*"' | cut -d'"' -f4)
  SYNC_DISTANCE=$(echo "${LH_SYNC_STATUS}" | grep -o '"sync_distance":"[^"]*"' | cut -d'"' -f4)

  if [ -z "${IS_SYNCING}" ]; then
    echo -e "${RED}✗ Could not get sync status from Lighthouse${NC}"
  else
    if [ "${IS_SYNCING}" = "true" ]; then
      echo -e "${YELLOW}⚠ Lighthouse is syncing - Head slot: ${HEAD_SLOT}, Sync distance: ${SYNC_DISTANCE}${NC}"
    else
      echo -e "${GREEN}✓ Lighthouse is synced${NC}"
    fi
  fi
fi

# Check for common error patterns in logs
echo -e "\n${YELLOW}Checking for common errors in logs...${NC}"

if [ ! -z "${GETH_RUNNING}" ]; then
  echo -e "\n${YELLOW}Analyzing Geth logs...${NC}"
  CHAIN_ID_LOGS=$(docker logs ephemery-geth 2>&1 | grep -i "chain id" | tail -5)
  echo -e "${GREEN}Chain ID information:${NC}"
  echo "${CHAIN_ID_LOGS}"

  ERROR_LOGS=$(docker logs ephemery-geth 2>&1 | grep -i "error\|fatal\|panic" | tail -5)
  if [ ! -z "${ERROR_LOGS}" ]; then
    echo -e "${RED}Found errors in Geth logs:${NC}"
    echo "${ERROR_LOGS}"
  else
    echo -e "${GREEN}No recent errors found in Geth logs${NC}"
  fi
fi

if [ ! -z "${LIGHTHOUSE_RUNNING}" ]; then
  echo -e "\n${YELLOW}Analyzing Lighthouse logs...${NC}"
  ELECTRA_LOGS=$(docker logs ephemery-lighthouse 2>&1 | grep -i "electra" | tail -5)
  if [ ! -z "${ELECTRA_LOGS}" ]; then
    echo -e "${GREEN}Electra information:${NC}"
    echo "${ELECTRA_LOGS}"
  else
    echo -e "${YELLOW}No Electra references found in logs. Might not be using Electra fork.${NC}"
  fi

  LH_ERROR_LOGS=$(docker logs ephemery-lighthouse 2>&1 | grep -i "error\|fatal\|panic\|crit" | tail -5)
  if [ ! -z "${LH_ERROR_LOGS}" ]; then
    echo -e "${RED}Found errors in Lighthouse logs:${NC}"
    echo "${LH_ERROR_LOGS}"
  else
    echo -e "${GREEN}No recent errors found in Lighthouse logs${NC}"
  fi
fi

# Provide fix options
echo -e "\n${YELLOW}Fix options:${NC}"
echo "1. Restart Geth"
echo "2. Restart Lighthouse Beacon"
echo "3. Restart Validator"
echo "4. Recreate JWT token"
echo "5. Reset and rebuild (WARNING: Will clear all data)"
echo "6. Exit"

read -p "Select an option (1-6): " option

case ${option} in
  1)
    echo -e "${YELLOW}Restarting Geth...${NC}"
    docker restart ephemery-geth
    echo -e "${GREEN}Geth restarted${NC}"
    ;;
  2)
    echo -e "${YELLOW}Restarting Lighthouse Beacon...${NC}"
    docker restart ephemery-lighthouse
    echo -e "${GREEN}Lighthouse Beacon restarted${NC}"
    ;;
  3)
    echo -e "${YELLOW}Restarting Validator...${NC}"
    docker restart ephemery-validator-lighthouse
    echo -e "${GREEN}Validator restarted${NC}"
    ;;
  4)
    echo -e "${YELLOW}Recreating JWT token...${NC}"
    openssl rand -hex 32 >/opt/ephemery/jwt.hex
    echo -e "${GREEN}JWT token recreated${NC}"
    echo -e "${YELLOW}You need to restart both Geth and Lighthouse to apply the new token${NC}"
    ;;
  5)
    echo -e "${RED}WARNING: This will remove all data and containers!${NC}"
    read -p "Are you sure you want to proceed? (y/n): " confirm
    if [[ ${confirm} == [yY] || ${confirm} == [yY][eE][sS] ]]; then
      echo -e "${YELLOW}Stopping and removing containers...${NC}"
      docker stop ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null
      docker rm ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null

      echo -e "${YELLOW}Clearing data directories...${NC}"
      rm -rf /opt/ephemery/data/geth/*
      rm -rf /opt/ephemery/data/lighthouse/*

      echo -e "${YELLOW}Creating new JWT token...${NC}"
      openssl rand -hex 32 >/opt/ephemery/jwt.hex

      echo -e "${GREEN}Reset complete${NC}"
      echo -e "${YELLOW}Please follow the setup guide to rebuild your node${NC}"
    else
      echo -e "${YELLOW}Reset cancelled${NC}"
    fi
    ;;
  6)
    echo -e "${GREEN}Exiting...${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid option${NC}"
    ;;
esac

# Run sync optimization checks
echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}Running Sync Optimization Diagnostics${NC}"
echo -e "${GREEN}=======================================${NC}"
check_sync_issues

# Final recommendations and summary
echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}Troubleshooting Complete${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "\nFor additional assistance:"
echo -e "1. Check the Ephemery documentation: https://github.com/hydepwns/ansible-ephemery"
echo -e "2. Run the specialized checkpoint diagnostic script: ./ephemery_checkpoint_diagnose.sh"
echo -e "3. For sync optimization, refer to: sync-optimization-guide.md"
