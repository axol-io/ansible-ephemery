#!/bin/bash
# Validator Key Restore Wrapper Script
# This is a simple wrapper to run the validator key restore playbook

set -e  # Exit on error

# Default variables
INVENTORY="local-inventory.yaml"
PLAYBOOK="playbooks/restore_validator_keys.yml"
BACKUP="latest"
FORCE="no"
EXTRA_ARGS=""

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display banner
function show_banner() {
    echo -e "${BLUE}"
    echo "════════════════════════════════════════════════════════════════════"
    echo "                Validator Key Restore Utility                       "
    echo "════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Function to display usage
function show_usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [options]"
    echo ""
    echo "Options:"
    echo "  -i, --inventory FILE    Specify inventory file (default: $INVENTORY)"
    echo "  -b, --backup TIMESTAMP  Specify backup timestamp (default: latest)"
    echo "  -f, --force             Force restore without confirmation"
    echo "  -h, --help              Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 --backup 20230415_120000"
    echo "  $0 --inventory production-inventory.yaml"
    echo "  $0 --force"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--inventory)
            INVENTORY="$2"
            shift
            shift
            ;;
        -b|--backup)
            BACKUP="$2"
            shift
            shift
            ;;
        -f|--force)
            FORCE="yes"
            shift
            ;;
        -h|--help)
            show_banner
            show_usage
            exit 0
            ;;
        *)
            # Add to extra args for ansible
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
    esac
done

# Display banner
show_banner

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook command not found${NC}"
    echo "Please make sure Ansible is installed and in your PATH"
    exit 1
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}Error: Inventory file not found: $INVENTORY${NC}"
    echo "Please specify a valid inventory file with --inventory option"
    exit 1
fi

# Check if playbook file exists
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}Error: Playbook file not found: $PLAYBOOK${NC}"
    echo "Please make sure you are running this script from the ansible-ephemery root directory"
    exit 1
fi

# Display restore information
echo -e "${BLUE}Validator Key Restore Operation${NC}"
echo -e "Inventory: ${YELLOW}$INVENTORY${NC}"
echo -e "Backup to restore: ${YELLOW}$BACKUP${NC}"
echo -e "Force mode: ${YELLOW}$FORCE${NC}"
echo ""

# Ask for confirmation
if [ "$FORCE" != "yes" ]; then
    read -p "Are you sure you want to restore validator keys? This will replace existing keys! (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation aborted by user${NC}"
        exit 0
    fi
fi

# Run the ansible playbook
echo -e "${GREEN}Running validator key restore playbook...${NC}"
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" -e "backup_timestamp=$BACKUP force_restore=$FORCE" $EXTRA_ARGS

# Display success banner
echo -e "${GREEN}"
echo "════════════════════════════════════════════════════════════════════"
echo "                 Restore Operation Completed                         "
echo "════════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo -e "Next steps:"
echo -e "1. Verify that the validator client is running properly"
echo -e "2. Check validator status in monitoring dashboard"
echo -e "3. Verify validator performance over the next few hours"

exit 0
