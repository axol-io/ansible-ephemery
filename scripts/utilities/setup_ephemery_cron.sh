#!/bin/bash
# setup_ephemery_cron.sh - Set up a cron job to periodically run the Ephemery reset handler
#
# This script creates a cron job that runs the reset handler at a specified interval,
# ensuring that network resets are detected and handled automatically.

# Strict error handling
set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
CORE_DIR="${PARENT_DIR}/core"
RESET_HANDLER="${CORE_DIR}/ephemery_reset_handler.sh"

# Default settings
INTERVAL="hourly"  # Options: hourly, daily, custom
CUSTOM_SCHEDULE="*/15 * * * *"  # Every 15 minutes
CRON_USER="${USER}"
FORCE_INSTALL=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
function print_usage() {
    echo -e "${BLUE}Ephemery Cron Setup${NC}"
    echo 
    echo "This script sets up a cron job to periodically run the Ephemery reset handler."
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 [options]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  -i, --interval TYPE    Interval type: hourly, daily, custom (default: hourly)"
    echo "  -s, --schedule CRON    Custom cron schedule (default: '*/15 * * * *')"
    echo "  -u, --user USER        User to install cron job for (default: current user)"
    echo "  -f, --force            Force install without confirmation"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -h, --help             Show this help message"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Install hourly cron job"
    echo "  $0 --interval hourly"
    echo
    echo "  # Install custom cron job (every 5 minutes)"
    echo "  $0 --interval custom --schedule '*/5 * * * *'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 0
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift
            shift
            ;;
        -s|--schedule)
            CUSTOM_SCHEDULE="$2"
            shift
            shift
            ;;
        -u|--user)
            CRON_USER="$2"
            shift
            shift
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Validate reset handler script
if [[ ! -f "${RESET_HANDLER}" ]]; then
    echo -e "${RED}Error: Reset handler script not found: ${RESET_HANDLER}${NC}"
    exit 1
fi

if [[ ! -x "${RESET_HANDLER}" ]]; then
    echo -e "${YELLOW}Warning: Reset handler script is not executable. Setting executable permission...${NC}"
    chmod +x "${RESET_HANDLER}" || {
        echo -e "${RED}Error: Could not make reset handler executable. Please check permissions.${NC}"
        exit 1
    }
fi

# Determine cron schedule
CRON_SCHEDULE=""
case "${INTERVAL}" in
    hourly)
        CRON_SCHEDULE="0 * * * *"  # At the start of each hour
        ;;
    daily)
        CRON_SCHEDULE="0 0 * * *"  # At midnight each day
        ;;
    custom)
        CRON_SCHEDULE="${CUSTOM_SCHEDULE}"
        ;;
    *)
        echo -e "${RED}Error: Invalid interval type: ${INTERVAL}${NC}"
        echo "Valid options: hourly, daily, custom"
        exit 1
        ;;
esac

# Create cron job line
LOG_REDIRECT="/dev/null"
if [[ "${VERBOSE}" == "true" ]]; then
    LOG_REDIRECT="\$HOME/ephemery/data/logs/cron_reset_handler.log"
fi

CRON_LINE="${CRON_SCHEDULE} ${RESET_HANDLER} >> ${LOG_REDIRECT} 2>&1"

# Display preview
echo -e "${BLUE}Ephemery Reset Handler Cron Configuration:${NC}"
echo "  Reset handler: ${RESET_HANDLER}"
echo "  Cron schedule: ${CRON_SCHEDULE}"
echo "  Cron user: ${CRON_USER}"
echo "  Log output: ${LOG_REDIRECT}"
echo
echo -e "${YELLOW}Cron entry to be added:${NC}"
echo "${CRON_LINE}"
echo

# Confirm installation
if [[ "${FORCE_INSTALL}" != "true" ]]; then
    read -p "Install cron job? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cron job installation cancelled.${NC}"
        exit 0
    fi
fi

# Install cron job
(crontab -l 2>/dev/null || echo "") | grep -v "${RESET_HANDLER}" | { cat; echo "${CRON_LINE}"; } | crontab -

# Verify installation
if crontab -l | grep -q "${RESET_HANDLER}"; then
    echo -e "${GREEN}Cron job installed successfully.${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Monitor logs at: ${LOG_REDIRECT}"
    echo "2. Test the reset handler: ${RESET_HANDLER} --force"
    exit 0
else
    echo -e "${RED}Error: Failed to install cron job.${NC}"
    exit 1
fi 