#!/bin/bash
# check_ephemery_status.sh - Script to verify checkpoint sync and resetter functionality

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display banner
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Ephemery Status Verification Tool    ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Check if SSH key and server info is provided
if [ $# -lt 1 ]; then
  echo -e "${RED}Error: Missing required parameters${NC}"
  echo -e "Usage: $0 <server_address> [ssh_key_path]"
  echo -e "Example: $0 user@103.214.23.174 ~/.ssh/id_rsa"
  exit 1
fi

SERVER=$1
SSH_KEY=""

# If SSH key is provided, use it
if [ $# -gt 1 ]; then
  SSH_KEY="-i $2"
fi

# Function to run remote commands
run_remote() {
  ssh $SSH_KEY $SERVER "$1"
}

echo -e "${YELLOW}Connecting to server ${SERVER}...${NC}"

# Test connection
if ! run_remote "echo Connection successful"; then
  echo -e "${RED}Failed to connect to server.${NC}"
  exit 1
fi

echo -e "${GREEN}Connection successful.${NC}"

# Step 1: Check Checkpoint Sync
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Checking Checkpoint Sync Status    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check if checkpoint sync is enabled in inventory
echo -e "${YELLOW}Checking if checkpoint sync is enabled in inventory...${NC}"
run_remote "grep -r 'use_checkpoint_sync' /root/ephemery/inventory.yaml || echo 'Inventory file not found'"

# Check Lighthouse logs for checkpoint sync
echo -e "${YELLOW}Checking Lighthouse logs for checkpoint sync information...${NC}"
run_remote "docker logs ephemery-lighthouse 2>&1 | grep -i 'checkpoint' | tail -10 || echo 'No checkpoint sync information found'"

# Test checkpoint sync URLs
echo -e "${YELLOW}Testing checkpoint sync URLs...${NC}"
run_remote "curl -s https://checkpoint-sync.holesky.ethpandaops.io/eth/v1/beacon/states/finalized -o /dev/null -w 'Status: %{http_code}\n' || echo 'Failed to test URL'"
run_remote "curl -s https://beaconstate-holesky.chainsafe.io/eth/v1/beacon/states/finalized -o /dev/null -w 'Status: %{http_code}\n' || echo 'Failed to test URL'"
run_remote "curl -s https://checkpoint-sync.ephemery.dev/eth/v1/beacon/states/finalized -o /dev/null -w 'Status: %{http_code}\n' || echo 'Failed to test URL'"

# Check Lighthouse sync status
echo -e "${YELLOW}Checking Lighthouse sync status...${NC}"
run_remote "docker logs ephemery-lighthouse 2>&1 | grep -E 'slot|sync|distance' | tail -10 || echo 'No sync information found'"

# Step 2: Check Resetter Functionality
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Checking Ephemery Resetter Functionality    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check if retention script exists
echo -e "${YELLOW}Checking if retention script exists...${NC}"
run_remote "ls -la /root/ephemery/scripts/ephemery_retention.sh || echo 'Retention script not found'"

# Check cron job
echo -e "${YELLOW}Checking if cron job is set up...${NC}"
run_remote "crontab -l | grep -E 'ephemery|retention' || echo 'No cron job found'"

# Check retention logs
echo -e "${YELLOW}Checking retention logs...${NC}"
run_remote "cat /root/ephemery/logs/retention.log | tail -20 || echo 'No retention logs found'"

# Step 3: Summary
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Status Summary    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check if Lighthouse is running
echo -e "${YELLOW}Checking if Lighthouse container is running...${NC}"
LIGHTHOUSE_RUNNING=$(run_remote "docker ps | grep ephemery-lighthouse" || echo "")
if [ -n "$LIGHTHOUSE_RUNNING" ]; then
  echo -e "${GREEN}Lighthouse container is running.${NC}"
else
  echo -e "${RED}Lighthouse container is not running!${NC}"
fi

# Check if Geth is running
echo -e "${YELLOW}Checking if Geth container is running...${NC}"
GETH_RUNNING=$(run_remote "docker ps | grep ephemery-geth" || echo "")
if [ -n "$GETH_RUNNING" ]; then
  echo -e "${GREEN}Geth container is running.${NC}"
else
  echo -e "${RED}Geth container is not running!${NC}"
fi

# Check if validator is running (if enabled)
echo -e "${YELLOW}Checking if validator container is running (if enabled)...${NC}"
VALIDATOR_RUNNING=$(run_remote "docker ps | grep ephemery-validator" || echo "")
if [ -n "$VALIDATOR_RUNNING" ]; then
  echo -e "${GREEN}Validator container is running.${NC}"
else
  echo -e "${YELLOW}Validator container is not running. This may be expected if validators are not enabled.${NC}"
fi

echo -e "${BLUE}======================================================${NC}"
echo -e "${YELLOW}For any issues found, consider running:${NC}"
echo -e "${GREEN}1. Fix checkpoint sync: /root/ephemery/scripts/fix_checkpoint_sync.sh${NC}"
echo -e "${GREEN}2. Fix resetter: /root/ephemery/scripts/deploy_ephemery_retention.sh${NC}"
echo -e "${BLUE}======================================================${NC}" 