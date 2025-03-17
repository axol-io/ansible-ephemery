#!/bin/bash
# Version: 1.0.0
#
# Setup Ephemery Cron Job
# =======================
#
# This script sets up a cron job to run the retention script every 5 minutes.
# It handles:
# - Validating that the retention script exists
# - Making the script executable if needed
# - Creating or updating the cron job entry
# - Running the script for immediate validation
#

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for better readability in terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Ephemery cron job...${NC}"

# ========================
# Configuration Variables
# ========================

# Path to the retention script
SCRIPT_PATH="/root/ephemery/scripts/ephemery_retention.sh"
# Path for the log file
LOG_PATH="/root/ephemery/logs/retention.log"

# ========================
# Script Validation
# ========================

# Check if retention script exists
if [ ! -f "${SCRIPT_PATH}" ]; then
  echo -e "${RED}Error: Retention script not found at ${SCRIPT_PATH}${NC}"
  echo -e "${YELLOW}Make sure you've created the script and it's in the correct location.${NC}"
  exit 1
fi

# Make script executable if it isn't already
if [ ! -x "${SCRIPT_PATH}" ]; then
  echo -e "${YELLOW}Making retention script executable...${NC}"
  chmod +x "${SCRIPT_PATH}"
fi

# ========================
# Cron Job Management
# ========================

# Create the cron job entry string
# Format: minute hour day_of_month month day_of_week command
# */5 means "every 5 minutes"
CRON_ENTRY="*/5 * * * * ${SCRIPT_PATH} > ${LOG_PATH} 2>&1"

# Check if cron job already exists to avoid duplicates
if crontab -l 2>/dev/null | grep -q "${SCRIPT_PATH}"; then
  echo -e "${YELLOW}Cron job for Ephemery already exists. Updating...${NC}"
  # Remove existing entry by grepping everything except the script path
  crontab -l 2>/dev/null | grep -v "${SCRIPT_PATH}" | crontab -
fi

# Add the new cron job
# Get existing crontab, append our entry, and write back
(
  crontab -l 2>/dev/null
  echo "${CRON_ENTRY}"
) | crontab -

echo -e "${GREEN}Cron job set up successfully!${NC}"
echo -e "The retention script will run every 5 minutes and log to: ${LOG_PATH}"
echo -e "${YELLOW}You can monitor the logs with: tail -f ${LOG_PATH}${NC}"

# ========================
# Initial Run
# ========================

# Run the script once immediately for validation
echo -e "${GREEN}Running the retention script for the first time...${NC}"
${SCRIPT_PATH}

echo -e "${GREEN}Setup complete!${NC}"
