#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Guided Configuration for Ephemery Deployment
# ===========================================
#
# This script provides a guided, interactive configuration workflow
# for Ephemery deployments, helping users create customized inventory files.
#

# Exit on error
set -e

# Colors for better readability in terminal output
NC='\033[0m' # No Color

# Default values
DEPLOY_TYPE="local"
OUTPUT_FILE="custom-inventory.yaml"
REMOTE_HOST=""
REMOTE_USER="ubuntu"
REMOTE_PORT="22"
BASE_DIR="/opt/ephemery"
DATA_DIR="/opt/ephemery/data"
LOGS_DIR="/opt/ephemery/logs"
GETH_IMAGE="pk910/ephemery-geth:latest"
LIGHTHOUSE_IMAGE="pk910/ephemery-lighthouse:latest"
VALIDATOR_IMAGE="sigp/lighthouse:latest"
GETH_CACHE=2048
GETH_MAX_PEERS=50
LIGHTHOUSE_TARGET_PEERS=30
ENABLE_VALIDATOR=false
VALIDATOR_KEY_COUNT=0
ENABLE_MONITORING=true
ENABLE_DASHBOARD=false
ENABLE_RETENTION=true
ADVANCED_CONFIG=false

# Show welcome banner
show_banner() {
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}       Guided Configuration for Ephemery Deployment              ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""
  echo -e "This script will guide you through configuring your Ephemery deployment."
  echo -e "It will ask a series of questions to customize your setup and generate"
  echo -e "an inventory file that can be used with the deployment scripts."
  echo ""
}

# Show help message
show_help() {
  echo -e "Usage: $0 [options]"
  echo ""
  echo -e "Options:"
  echo -e "  -h, --help                  Show this help message"
  echo -e "  -o, --output FILE           Output inventory file (default: custom-inventory.yaml)"
  echo -e "  -a, --advanced              Enable advanced configuration options"
  echo ""
  echo -e "Examples:"
  echo -e "  $0                                # Run guided configuration"
  echo -e "  $0 --output my-inventory.yaml     # Specify output file"
  echo -e "  $0 --advanced                     # Enable advanced configuration"
  echo ""
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
      -h | --help)
        show_help
        exit 0
        ;;
      -o | --output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      -a | --advanced)
        ADVANCED_CONFIG=true
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

# Ask a yes/no question with a default value
ask_yes_no() {
  local question="$1"
  local default="$2"
  local response

  if [[ "${default}" == "y" ]]; then
    read -p "${question} [Y/n]: " response
    if [[ -z "${response}" || "${response}" =~ ^[Yy]$ ]]; then
      return 0
    else
      return 1
    fi
  else
    read -p "${question} [y/N]: " response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
      return 0
    else
      return 1
    fi
  fi
}

# Ask a question with a default value
ask_with_default() {
  local question="$1"
  local default="$2"
  local response

  read -p "${question} [${default}]: " response
  if [[ -z "${response}" ]]; then
    echo "${default}"
  else
    echo "${response}"
  fi
}

# Ask for deployment type
ask_deployment_type() {
  echo -e "${BLUE}Deployment Type${NC}"
  echo -e "Select where you want to deploy Ephemery:"
  echo -e "1) Local - Deploy on this machine"
  echo -e "2) Remote - Deploy on a remote server"

  local choice
  read -p "Enter your choice (1/2): " choice
  case ${choice} in
    1)
      DEPLOY_TYPE="local"
      echo -e "${GREEN}✓ Selected local deployment${NC}"
      ;;
    2)
      DEPLOY_TYPE="remote"
      echo -e "${GREEN}✓ Selected remote deployment${NC}"
      ask_remote_details
      ;;
    *)
      echo -e "${RED}Invalid choice. Defaulting to local deployment.${NC}"
      DEPLOY_TYPE="local"
      ;;
  esac
}

# Ask for remote server details
ask_remote_details() {
  echo -e "${BLUE}Remote Server Details${NC}"

  REMOTE_HOST=$(ask_with_default "Enter remote server hostname or IP address" "localhost")
  REMOTE_USER=$(ask_with_default "Enter remote user" "ubuntu")
  REMOTE_PORT=$(ask_with_default "Enter SSH port" "22")

  echo -e "${GREEN}✓ Remote connection: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}${NC}"

  # Verify connection
  echo -e "${YELLOW}Verifying SSH connection...${NC}"
  if ssh -p "${REMOTE_PORT}" -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 2>&1" >/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
  else
    echo -e "${RED}✗ SSH connection failed. Please check your credentials and try again.${NC}"
    echo -e "${YELLOW}You can continue, but deployment might fail later.${NC}"

    if ! ask_yes_no "Continue anyway?" "n"; then
      exit 1
    fi
  fi
}

# Ask for directory paths
ask_directories() {
  if [[ "${ADVANCED_CONFIG}" == true ]]; then
    echo -e "${BLUE}Directory Configuration${NC}"

    BASE_DIR=$(ask_with_default "Enter base directory for Ephemery" "${BASE_DIR}")
    DATA_DIR=$(ask_with_default "Enter data directory" "${DATA_DIR}")
    LOGS_DIR=$(ask_with_default "Enter logs directory" "${LOGS_DIR}")

    echo -e "${GREEN}✓ Directory configuration completed${NC}"
  fi
}

# Ask for feature flags
ask_features() {
  echo -e "${BLUE}Feature Configuration${NC}"

  if ask_yes_no "Enable Ephemery retention system? (automatic genesis resets)" "y"; then
    ENABLE_RETENTION=true
  else
    ENABLE_RETENTION=false
  fi

  if ask_yes_no "Enable validator support?" "n"; then
    ENABLE_VALIDATOR=true
    VALIDATOR_KEY_COUNT=$(ask_with_default "Enter expected validator key count (0 to skip validation)" "0")
  else
    ENABLE_VALIDATOR=false
  fi

  if ask_yes_no "Enable sync monitoring?" "y"; then
    ENABLE_MONITORING=true

    if ask_yes_no "Enable web dashboard for sync status?" "n"; then
      ENABLE_DASHBOARD=true
    else
      ENABLE_DASHBOARD=false
    fi
  else
    ENABLE_MONITORING=false
    ENABLE_DASHBOARD=false
  fi

  echo -e "${GREEN}✓ Feature configuration completed${NC}"
}

# Ask for client configuration
ask_client_config() {
  if [[ "${ADVANCED_CONFIG}" == true ]]; then
    echo -e "${BLUE}Client Configuration${NC}"

    GETH_IMAGE=$(ask_with_default "Enter Geth Docker image" "${GETH_IMAGE}")
    LIGHTHOUSE_IMAGE=$(ask_with_default "Enter Lighthouse Docker image" "${LIGHTHOUSE_IMAGE}")

    if [[ "${ENABLE_VALIDATOR}" == true ]]; then
      VALIDATOR_IMAGE=$(ask_with_default "Enter Validator Docker image" "${VALIDATOR_IMAGE}")
    fi

    GETH_CACHE=$(ask_with_default "Enter Geth cache size (MB)" "${GETH_CACHE}")
    GETH_MAX_PEERS=$(ask_with_default "Enter Geth max peers" "${GETH_MAX_PEERS}")
    LIGHTHOUSE_TARGET_PEERS=$(ask_with_default "Enter Lighthouse target peers" "${LIGHTHOUSE_TARGET_PEERS}")

    echo -e "${GREEN}✓ Client configuration completed${NC}"
  fi
}

# Generate the inventory file
generate_inventory() {
  echo -e "${BLUE}Generating inventory file...${NC}"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "${OUTPUT_FILE}")"

  # Start generating the inventory file
  cat >"${OUTPUT_FILE}" <<EOF
---
# Ephemery Inventory File
# Generated by guided_config.sh on $(date)

# Deployment type
deployment_type: ${DEPLOY_TYPE}

EOF

  # Add remote details if applicable
  if [[ "${DEPLOY_TYPE}" == "remote" ]]; then
    cat >>"${OUTPUT_FILE}" <<EOF
# Remote connection details
remote:
  host: ${REMOTE_HOST}
  user: ${REMOTE_USER}
  port: ${REMOTE_PORT}

EOF
  fi

  # Add directory configuration
  cat >>"${OUTPUT_FILE}" <<EOF
# Directory paths
directories:
  base: ${BASE_DIR}
  data: ${DATA_DIR}
  logs: ${LOGS_DIR}

EOF

  # Add client configuration
  cat >>"${OUTPUT_FILE}" <<EOF
# Client configuration
clients:
  execution: geth
  consensus: lighthouse

geth:
  image: ${GETH_IMAGE}
  cache: ${GETH_CACHE}
  max_peers: ${GETH_MAX_PEERS}

lighthouse:
  image: ${LIGHTHOUSE_IMAGE}
  target_peers: ${LIGHTHOUSE_TARGET_PEERS}

EOF

  # Add validator configuration if enabled
  if [[ "${ENABLE_VALIDATOR}" == true ]]; then
    cat >>"${OUTPUT_FILE}" <<EOF
# Validator configuration
features:
  validator:
    enabled: true
    expected_key_count: ${VALIDATOR_KEY_COUNT}

validator:
  image: ${VALIDATOR_IMAGE}

EOF
  else
    cat >>"${OUTPUT_FILE}" <<EOF
# Validator configuration
features:
  validator:
    enabled: false

EOF
  fi

  # Add feature flags
  cat >>"${OUTPUT_FILE}" <<EOF
# Feature flags
features:
  retention:
    enabled: ${ENABLE_RETENTION}
  monitoring:
    enabled: ${ENABLE_MONITORING}
    dashboard: ${ENABLE_DASHBOARD}

EOF

  echo -e "${GREEN}✓ Inventory file generated: ${OUTPUT_FILE}${NC}"
}

# Review and confirm the configuration
review_config() {
  echo -e "${BLUE}Configuration Summary${NC}"
  echo -e "Please review your configuration:"
  echo -e ""
  echo -e "Deployment Type: ${DEPLOY_TYPE}"

  if [[ "${DEPLOY_TYPE}" == "remote" ]]; then
    echo -e "Remote Host: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
  fi

  echo -e ""
  echo -e "Directories:"
  echo -e "  Base: ${BASE_DIR}"
  echo -e "  Data: ${DATA_DIR}"
  echo -e "  Logs: ${LOGS_DIR}"

  echo -e ""
  echo -e "Client Configuration:"
  echo -e "  Geth Image: ${GETH_IMAGE}"
  echo -e "  Lighthouse Image: ${LIGHTHOUSE_IMAGE}"
  echo -e "  Geth Cache: ${GETH_CACHE} MB"
  echo -e "  Geth Max Peers: ${GETH_MAX_PEERS}"
  echo -e "  Lighthouse Target Peers: ${LIGHTHOUSE_TARGET_PEERS}"

  echo -e ""
  echo -e "Features:"
  echo -e "  Ephemery Retention: $(if [[ "${ENABLE_RETENTION}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "  Validator Support: $(if [[ "${ENABLE_VALIDATOR}" == true ]]; then echo "Enabled (${VALIDATOR_KEY_COUNT} keys)"; else echo "Disabled"; fi)"
  echo -e "  Sync Monitoring: $(if [[ "${ENABLE_MONITORING}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "  Web Dashboard: $(if [[ "${ENABLE_DASHBOARD}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"

  echo -e ""
  echo -e "Output File: ${OUTPUT_FILE}"
  echo -e ""

  if ! ask_yes_no "Is this configuration correct?" "y"; then
    echo -e "${YELLOW}Configuration not confirmed. Exiting without saving.${NC}"
    exit 1
  fi
}

# Main function
main() {
  show_banner
  parse_args "$@"

  ask_deployment_type
  ask_directories
  ask_features
  ask_client_config

  review_config
  generate_inventory

  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}       Configuration Complete                                   ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo -e ""
  echo -e "You can now deploy Ephemery using the generated inventory file:"
  echo -e ""
  echo -e "For local deployment:"
  echo -e "  ./scripts/deploy-ephemery.sh --inventory ${OUTPUT_FILE}"
  echo -e ""
  echo -e "For remote deployment:"
  echo -e "  ./scripts/deploy-ephemery.sh --inventory ${OUTPUT_FILE}"
  echo -e ""
  echo -e "Thank you for using Ephemery!"
}

# Execute main function
main "$@"
