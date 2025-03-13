#!/bin/bash
#
# Unified Ephemery Deployment System
# ==================================
#
# This script provides a unified deployment system for Ephemery nodes.
# It guides users through configuration and deployment options with a
# simplified, interactive workflow.
#

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for better readability in terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration variables
DEPLOYMENT_TYPE=""
INVENTORY_FILE=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT="22"
SETUP_RETENTION=false
ENABLE_VALIDATOR=false
ENABLE_MONITORING=false
ENABLE_DASHBOARD=false
CUSTOM_CONFIG=false
VERIFY_DEPLOYMENT=true
SKIP_PROMPTS=false

# Show welcome banner
show_banner() {
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}            Ephemery Unified Deployment System                  ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""
  echo -e "This script provides a unified interface for deploying Ephemery nodes,"
  echo -e "with guided configuration and automated verification."
  echo ""
}

# Show help message
show_help() {
  echo -e "Usage: $0 [options]"
  echo ""
  echo -e "Options:"
  echo -e "  -h, --help                  Show this help message"
  echo -e "  -t, --type TYPE             Deployment type (local|remote)"
  echo -e "  -i, --inventory FILE        Use custom inventory file"
  echo -e "  -H, --host HOST             Remote host (for remote deployment)"
  echo -e "  -u, --user USER             Remote user (for remote deployment)"
  echo -e "  -p, --port PORT             SSH port (default: 22)"
  echo -e "  -r, --retention             Setup Ephemery retention system"
  echo -e "  -v, --validator             Enable validator support"
  echo -e "  -m, --monitoring            Enable sync monitoring"
  echo -e "  -d, --dashboard             Enable web dashboard"
  echo -e "  --skip-verify               Skip deployment verification"
  echo -e "  -y, --yes                   Skip all prompts, use defaults"
  echo ""
  echo -e "Examples:"
  echo -e "  $0 --type local                     # Deploy locally with guided setup"
  echo -e "  $0 --type remote --host my-server   # Deploy to remote server with guided setup"
  echo -e "  $0 --inventory my-inventory.yaml    # Deploy using custom inventory"
  echo ""
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -h|--help)
        show_help
        exit 0
        ;;
      -t|--type)
        DEPLOYMENT_TYPE="$2"
        shift 2
        ;;
      -i|--inventory)
        INVENTORY_FILE="$2"
        CUSTOM_CONFIG=true
        shift 2
        ;;
      -H|--host)
        REMOTE_HOST="$2"
        shift 2
        ;;
      -u|--user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -p|--port)
        REMOTE_PORT="$2"
        shift 2
        ;;
      -r|--retention)
        SETUP_RETENTION=true
        shift
        ;;
      -v|--validator)
        ENABLE_VALIDATOR=true
        shift
        ;;
      -m|--monitoring)
        ENABLE_MONITORING=true
        shift
        ;;
      -d|--dashboard)
        ENABLE_DASHBOARD=true
        shift
        ;;
      --skip-verify)
        VERIFY_DEPLOYMENT=false
        shift
        ;;
      -y|--yes)
        SKIP_PROMPTS=true
        shift
        ;;
      *)
        echo -e "${RED}Error: Unknown option $1${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Check prerequisites
check_prerequisites() {
  echo -e "${BLUE}Checking prerequisites...${NC}"

  # Check if we're in the correct directory
  if [ ! -f "$PROJECT_ROOT/inventory.yaml" ]; then
    echo -e "${RED}Error: This script must be run from the ansible-ephemery directory${NC}"
    echo -e "${YELLOW}Change to the ansible-ephemery directory and try again${NC}"
    exit 1
  fi

  # Check if required scripts exist
  if [ ! -d "$PROJECT_ROOT/scripts/utils" ]; then
    echo -e "${RED}Error: Required utility scripts not found${NC}"
    exit 1
  fi

  # Check for docker if local deployment
  if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
    if ! command -v docker &> /dev/null; then
      echo -e "${RED}Error: Docker is required for local deployment but not found${NC}"
      echo -e "${YELLOW}Please install Docker and try again${NC}"
      exit 1
    fi
  fi

  # Check for ssh if remote deployment
  if [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
    if ! command -v ssh &> /dev/null; then
      echo -e "${RED}Error: SSH is required for remote deployment but not found${NC}"
      exit 1
    fi

    if [[ -z "$REMOTE_HOST" ]]; then
      echo -e "${RED}Error: Remote host is required for remote deployment${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Interactive deployment type selection
select_deployment_type() {
  if [[ -z "$DEPLOYMENT_TYPE" && "$SKIP_PROMPTS" == false ]]; then
    echo -e "${BLUE}Select deployment type:${NC}"
    echo -e "1) Local - Deploy on this machine"
    echo -e "2) Remote - Deploy on a remote server"

    read -p "Enter your choice (1/2): " choice
    case $choice in
      1) DEPLOYMENT_TYPE="local" ;;
      2) DEPLOYMENT_TYPE="remote" ;;
      *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
    esac
  elif [[ -z "$DEPLOYMENT_TYPE" && "$SKIP_PROMPTS" == true ]]; then
    # Default to local if not specified with --yes flag
    DEPLOYMENT_TYPE="local"
  fi

  echo -e "${GREEN}✓ Deployment type: ${DEPLOYMENT_TYPE}${NC}"
}

# Get remote connection details
get_remote_details() {
  if [[ "$DEPLOYMENT_TYPE" == "remote" && "$CUSTOM_CONFIG" == false ]]; then
    if [[ -z "$REMOTE_HOST" && "$SKIP_PROMPTS" == false ]]; then
      read -p "Enter remote host (IP or hostname): " REMOTE_HOST
    fi

    if [[ -z "$REMOTE_USER" && "$SKIP_PROMPTS" == false ]]; then
      read -p "Enter remote user (default: ubuntu): " REMOTE_USER
      REMOTE_USER=${REMOTE_USER:-ubuntu}
    elif [[ -z "$REMOTE_USER" && "$SKIP_PROMPTS" == true ]]; then
      REMOTE_USER="ubuntu"
    fi

    echo -e "${GREEN}✓ Remote connection: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}${NC}"
  fi
}

# Configure deployment options
configure_deployment() {
  if [[ "$CUSTOM_CONFIG" == false && "$SKIP_PROMPTS" == false ]]; then
    echo -e "${BLUE}Configure deployment options:${NC}"

    read -p "Enable Ephemery retention system? (y/n, default: y): " retention
    if [[ "$retention" == "y" || "$retention" == "Y" || -z "$retention" ]]; then
      SETUP_RETENTION=true
    fi

    read -p "Enable validator support? (y/n, default: n): " validator
    if [[ "$validator" == "y" || "$validator" == "Y" ]]; then
      ENABLE_VALIDATOR=true
    fi

    read -p "Enable sync monitoring? (y/n, default: y): " monitoring
    if [[ "$monitoring" == "y" || "$monitoring" == "Y" || -z "$monitoring" ]]; then
      ENABLE_MONITORING=true
    fi

    if [[ "$ENABLE_MONITORING" == true ]]; then
      read -p "Enable web dashboard? (y/n, default: n): " dashboard
      if [[ "$dashboard" == "y" || "$dashboard" == "Y" ]]; then
        ENABLE_DASHBOARD=true
      fi
    fi
  elif [[ "$CUSTOM_CONFIG" == false && "$SKIP_PROMPTS" == true ]]; then
    # Set defaults when using --yes flag
    SETUP_RETENTION=true
    ENABLE_MONITORING=true
  fi

  echo -e "${GREEN}Configuration summary:${NC}"
  echo -e "- Ephemery retention: $(if [[ "$SETUP_RETENTION" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Validator support: $(if [[ "$ENABLE_VALIDATOR" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Sync monitoring: $(if [[ "$ENABLE_MONITORING" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Web dashboard: $(if [[ "$ENABLE_DASHBOARD" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
}

# Generate inventory file
generate_inventory() {
  if [[ "$CUSTOM_CONFIG" == false ]]; then
    echo -e "${BLUE}Generating inventory file...${NC}"

    INVENTORY_FILE="$PROJECT_ROOT/generated-inventory-$(date +%s).yaml"

    GEN_CMD="$PROJECT_ROOT/scripts/utils/generate_inventory.sh --type $DEPLOYMENT_TYPE --output $INVENTORY_FILE"

    # Add remote-specific options
    if [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
      GEN_CMD="$GEN_CMD --remote-host $REMOTE_HOST --remote-user $REMOTE_USER --remote-port $REMOTE_PORT"
    fi

    # Add feature flags
    if [[ "$ENABLE_VALIDATOR" == true ]]; then
      GEN_CMD="$GEN_CMD --enable-validator"
    fi

    if [[ "$ENABLE_MONITORING" == true ]]; then
      GEN_CMD="$GEN_CMD --enable-monitoring"
    fi

    if [[ "$ENABLE_DASHBOARD" == true ]]; then
      GEN_CMD="$GEN_CMD --enable-dashboard"
    fi

    # Execute the inventory generation command
    eval $GEN_CMD

    echo -e "${GREEN}✓ Generated inventory file: $INVENTORY_FILE${NC}"

    # Validate the inventory
    echo -e "${BLUE}Validating inventory...${NC}"
    "$PROJECT_ROOT/scripts/utils/validate_inventory.sh" "$INVENTORY_FILE"
    echo -e "${GREEN}✓ Inventory validation passed${NC}"
  else
    echo -e "${BLUE}Using custom inventory file: $INVENTORY_FILE${NC}"

    # Validate the custom inventory
    echo -e "${BLUE}Validating inventory...${NC}"
    "$PROJECT_ROOT/scripts/utils/validate_inventory.sh" "$INVENTORY_FILE"
    echo -e "${GREEN}✓ Inventory validation passed${NC}"
  fi
}

# Run deployment
run_deployment() {
  echo -e "${BLUE}Starting deployment...${NC}"

  if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
    # Run local deployment
    echo -e "${YELLOW}Deploying Ephemery locally...${NC}"
    "$PROJECT_ROOT/scripts/local/run-ephemery-local.sh" --inventory "$INVENTORY_FILE"
  elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
    # Run remote deployment
    echo -e "${YELLOW}Deploying Ephemery to remote server...${NC}"
    "$PROJECT_ROOT/scripts/remote/run-ephemery-remote.sh" --inventory "$INVENTORY_FILE"
  fi

  echo -e "${GREEN}✓ Basic deployment completed${NC}"
}

# Setup retention if enabled
setup_retention() {
  if [[ "$SETUP_RETENTION" == true ]]; then
    echo -e "${BLUE}Setting up Ephemery retention system...${NC}"
    "$PROJECT_ROOT/scripts/deploy_ephemery_retention.sh"
    echo -e "${GREEN}✓ Retention system deployed${NC}"
  fi
}

# Verify deployment
verify_deployment() {
  if [[ "$VERIFY_DEPLOYMENT" == true ]]; then
    echo -e "${BLUE}Verifying deployment...${NC}"

    # Implement verification tests here
    if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
      # Local verification
      echo -e "${YELLOW}Checking Docker containers...${NC}"
      if docker ps | grep -q "ephemery-geth" && docker ps | grep -q "ephemery-lighthouse"; then
        echo -e "${GREEN}✓ Docker containers running${NC}"
      else
        echo -e "${RED}✗ Some Docker containers are not running${NC}"
      fi
    elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
      # Remote verification
      echo -e "${YELLOW}Checking remote services...${NC}"
      if ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "docker ps | grep -q ephemery-geth && docker ps | grep -q ephemery-lighthouse"; then
        echo -e "${GREEN}✓ Remote services running${NC}"
      else
        echo -e "${RED}✗ Some remote services are not running${NC}"
      fi
    fi

    echo -e "${GREEN}✓ Deployment verification completed${NC}"
  fi
}

# Display final information
show_final_info() {
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}       Ephemery Deployment Completed Successfully               ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""

  if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
    echo -e "Geth API: http://localhost:8545"
    echo -e "Lighthouse API: http://localhost:5052"

    if [[ "$ENABLE_DASHBOARD" == true ]]; then
      echo -e "Dashboard: http://localhost/ephemery-status/"
    fi

    echo -e "\nTo monitor the sync status:"
    echo -e "  docker logs -f ephemery-geth"
    echo -e "  docker logs -f ephemery-lighthouse"
  elif [[ "$DEPLOYMENT_TYPE" == "remote" ]]; then
    echo -e "Geth API: http://$REMOTE_HOST:8545"
    echo -e "Lighthouse API: http://$REMOTE_HOST:5052"

    if [[ "$ENABLE_DASHBOARD" == true ]]; then
      echo -e "Dashboard: http://$REMOTE_HOST/ephemery-status/"
    fi

    echo -e "\nTo monitor the sync status:"
    echo -e "  ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT"
    echo -e "  docker logs -f ephemery-geth"
    echo -e "  docker logs -f ephemery-lighthouse"
  fi

  echo -e "\nFor troubleshooting, run:"
  echo -e "  $PROJECT_ROOT/scripts/troubleshoot-ephemery.sh"

  echo -e "\nTo check sync status, run:"
  echo -e "  $PROJECT_ROOT/scripts/check_sync_status.sh"

  if [[ "$SETUP_RETENTION" == true ]]; then
    echo -e "\nEphemery retention is enabled. The system will automatically detect and handle weekly resets."
  fi

  echo -e "\nThank you for using Ephemery!"
}

# Main function
main() {
  show_banner
  parse_args "$@"

  if [[ "$DEPLOYMENT_TYPE" == "help" ]]; then
    show_help
    exit 0
  fi

  select_deployment_type
  get_remote_details
  check_prerequisites
  configure_deployment
  generate_inventory
  run_deployment
  setup_retention
  verify_deployment
  show_final_info
}

# Execute main function
main "$@"
