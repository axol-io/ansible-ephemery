#!/bin/bash
# Version: 1.0.0
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Project root directory
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

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
    case ${key} in
      -h | --help)
        show_help
        exit 0
        ;;
      -t | --type)
        DEPLOYMENT_TYPE="$2"
        shift 2
        ;;
      -i | --inventory)
        INVENTORY_FILE="$2"
        CUSTOM_CONFIG=true
        shift 2
        ;;
      -H | --host)
        REMOTE_HOST="$2"
        shift 2
        ;;
      -u | --user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -p | --port)
        REMOTE_PORT="$2"
        shift 2
        ;;
      -r | --retention)
        SETUP_RETENTION=true
        shift
        ;;
      -v | --validator)
        ENABLE_VALIDATOR=true
        shift
        ;;
      -m | --monitoring)
        ENABLE_MONITORING=true
        shift
        ;;
      -d | --dashboard)
        ENABLE_DASHBOARD=true
        shift
        ;;
      --skip-verify)
        VERIFY_DEPLOYMENT=false
        shift
        ;;
      -y | --yes)
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
  if [ ! -f "${PROJECT_ROOT}/inventory.yaml" ]; then
    echo -e "${RED}Error: This script must be run from the ansible-ephemery directory${NC}"
    echo -e "${YELLOW}Change to the ansible-ephemery directory and try again${NC}"
    exit 1
  fi

  # Check if required scripts exist
  if [ ! -d "${PROJECT_ROOT}/scripts/utils" ]; then
    echo -e "${RED}Error: Required utility scripts not found${NC}"
    exit 1
  fi

  # Check for docker if local deployment
  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    if ! command -v docker &>/dev/null; then
      echo -e "${RED}Error: Docker is required for local deployment but not found${NC}"
      echo -e "${YELLOW}Please install Docker and try again${NC}"
      exit 1
    fi
  fi

  # Check for ssh if remote deployment
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    if ! command -v ssh &>/dev/null; then
      echo -e "${RED}Error: SSH is required for remote deployment but not found${NC}"
      exit 1
    fi

    # We'll check for remote host after get_remote_details() is called
  fi

  echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Interactive deployment type selection
select_deployment_type() {
  if [[ -z "${DEPLOYMENT_TYPE}" && "${SKIP_PROMPTS}" == false ]]; then
    echo -e "${BLUE}Select deployment type:${NC}"
    echo -e "1) Local - Deploy on this machine"
    echo -e "2) Remote - Deploy on a remote server"

    read -p "Enter your choice (1/2): " choice
    case ${choice} in
      1) DEPLOYMENT_TYPE="local" ;;
      2) DEPLOYMENT_TYPE="remote" ;;
      *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
    esac
  elif [[ -z "${DEPLOYMENT_TYPE}" && "${SKIP_PROMPTS}" == true ]]; then
    # Default to local if not specified with --yes flag
    DEPLOYMENT_TYPE="local"
  fi

  echo -e "${GREEN}✓ Deployment type: ${DEPLOYMENT_TYPE}${NC}"
}

# Get remote connection details
get_remote_details() {
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    if [[ -z "${REMOTE_HOST}" && "${SKIP_PROMPTS}" == false ]]; then
      # Prompt for remote host with validation
      while true; do
        read -p "Enter remote host (IP or hostname): " input_host

        # Sanitize input: remove leading/trailing whitespace
        REMOTE_HOST=$(echo "${input_host}" | xargs)

        # Validate hostname/IP format
        if [[ -z "${REMOTE_HOST}" ]]; then
          echo -e "${RED}Error: Hostname cannot be empty${NC}"
        elif [[ "${REMOTE_HOST}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          # Basic IPv4 validation
          if [[ $(echo "${REMOTE_HOST}" | awk -F. '$1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255 {print "valid"}') == "valid" ]]; then
            break
          else
            echo -e "${RED}Error: Invalid IPv4 address format${NC}"
          fi
        elif [[ "${REMOTE_HOST}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-\.]+)?[a-zA-Z0-9](\.[a-zA-Z]{2,})+$ ]]; then
          # Basic hostname validation
          break
        else
          # Accept other formats with a warning
          echo -e "${YELLOW}Warning: Hostname format is unusual but will be accepted${NC}"
          break
        fi
      done
    fi

    if [[ -z "${REMOTE_USER}" && "${SKIP_PROMPTS}" == false ]]; then
      # Provide OS-specific default user suggestions and rootless/rootful warning
      echo -e "${BLUE}Common default users by OS:${NC}"
      echo -e "  - Ubuntu: ubuntu"
      echo -e "  - Debian: debian"
      echo -e "  - CentOS/RHEL: ec2-user or centos"
      echo -e "  - Amazon Linux: ec2-user"
      echo -e "  - OpenSUSE: opensuse"
      echo -e "  - Fedora: fedora"
      echo -e ""
      echo -e "${YELLOW}=== Rootless vs. Rootful Deployment ====${NC}"
      echo -e "Running as ${YELLOW}root${NC} provides:"
      echo -e "  + Full system access"
      echo -e "  + No permission issues with Docker"
      echo -e "  - Less security (higher risk if compromised)"
      echo -e ""
      echo -e "Running as a ${YELLOW}regular user${NC} provides:"
      echo -e "  + Better security through privilege separation"
      echo -e "  + Follows best practices"
      echo -e "  - Requires proper Docker group permissions setup"
      echo -e "  - May need additional configurations"
      echo -e ""
      echo -e "${BLUE}Recommendation${NC}: Use a regular user with proper Docker permissions for production environments."
      echo -e ""

      read -p "Enter remote user (default: ubuntu): " REMOTE_USER
      REMOTE_USER=${REMOTE_USER:-ubuntu}

      # If user entered 'root', show an additional confirmation
      if [[ "${REMOTE_USER}" == "root" ]]; then
        echo -e "${YELLOW}Warning: You are deploying as root user. This is not recommended for production environments.${NC}"
        read -p "Are you sure you want to continue with root user? (y/n): " root_confirm
        if [[ "${root_confirm}" != "y" && "${root_confirm}" != "Y" ]]; then
          read -p "Enter a different remote user: " REMOTE_USER
          REMOTE_USER=${REMOTE_USER:-ubuntu}
        fi
      fi
    elif [[ -z "${REMOTE_USER}" && "${SKIP_PROMPTS}" == true ]]; then
      REMOTE_USER="ubuntu"
    fi

    echo -e "${GREEN}✓ Remote connection: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}${NC}"
  fi
}

# Configure deployment options
configure_deployment() {
  if [[ "${CUSTOM_CONFIG}" == false && "${SKIP_PROMPTS}" == false ]]; then
    echo -e "${BLUE}Configure deployment options:${NC}"

    read -p "Enable Ephemery retention system? (y/n, default: y): " retention
    if [[ "${retention}" == "y" || "${retention}" == "Y" || -z "${retention}" ]]; then
      SETUP_RETENTION=true
    fi

    read -p "Enable validator support? (y/n, default: n): " validator
    if [[ "${validator}" == "y" || "${validator}" == "Y" ]]; then
      ENABLE_VALIDATOR=true
    fi

    read -p "Enable sync monitoring? (y/n, default: y): " monitoring
    if [[ "${monitoring}" == "y" || "${monitoring}" == "Y" || -z "${monitoring}" ]]; then
      ENABLE_MONITORING=true
    fi

    if [[ "${ENABLE_MONITORING}" == true ]]; then
      read -p "Enable web dashboard? (y/n, default: n): " dashboard
      if [[ "${dashboard}" == "y" || "${dashboard}" == "Y" ]]; then
        ENABLE_DASHBOARD=true
      fi
    fi
  elif [[ "${CUSTOM_CONFIG}" == false && "${SKIP_PROMPTS}" == true ]]; then
    # Set defaults when using --yes flag
    SETUP_RETENTION=true
    ENABLE_MONITORING=true
  fi

  echo -e "${GREEN}Configuration summary:${NC}"
  echo -e "- Ephemery retention: $(if [[ "${SETUP_RETENTION}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Validator support: $(if [[ "${ENABLE_VALIDATOR}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Sync monitoring: $(if [[ "${ENABLE_MONITORING}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo -e "- Web dashboard: $(if [[ "${ENABLE_DASHBOARD}" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
}

# Generate a default inventory file based on input parameters
generate_default_inventory() {
  log_info "Generating default inventory file..."

  # Set default values
  : "${DEPLOYMENT_TYPE:=local}"
  : "${REMOTE_USER:=ubuntu}"
  : "${REMOTE_PORT:=22}"

  local output_file="${PROJECT_ROOT}/ansible/inventory/ephemery-${DEPLOYMENT_TYPE}-$(date +%Y%m%d%H%M%S).yaml"
  local hostname="localhost"

  # If deployment type is remote, ensure we have a host
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    if [[ -z "${REMOTE_HOST}" ]]; then
      log_error "Remote host is required for remote deployment"
      return 1
    fi
    hostname="${REMOTE_HOST}"
  fi

  log_info "Creating inventory for ${DEPLOYMENT_TYPE} deployment ${hostname}..."

  # Use the consolidated inventory_manager.sh script instead of the deprecated generate_inventory.sh
  GEN_CMD="${PROJECT_ROOT}/scripts/core/inventory_manager.sh generate --type ${DEPLOYMENT_TYPE}"

  # Add options based on input parameters
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    GEN_CMD="${GEN_CMD} --host ${REMOTE_HOST} --user ${REMOTE_USER} --port ${REMOTE_PORT}"
  fi

  # Add validator option if enabled
  if [[ "${ENABLE_VALIDATOR}" == "true" ]]; then
    GEN_CMD="${GEN_CMD} --validator"
  fi

  # Add monitoring option if enabled
  if [[ "${ENABLE_MONITORING}" == "true" ]]; then
    GEN_CMD="${GEN_CMD} --monitoring"
  fi

  # Add dashboard option if enabled
  if [[ "${ENABLE_DASHBOARD}" == "true" ]]; then
    GEN_CMD="${GEN_CMD} --dashboard"
  fi

  # Add output file
  GEN_CMD="${GEN_CMD} --output ${output_file}"

  # Execute the command
  log_debug "Executing: ${GEN_CMD}"
  eval "${GEN_CMD}"

  if [[ ! -f "${output_file}" ]]; then
    log_error "Failed to generate inventory file"
    return 1
  fi

  log_success "Inventory file generated successfully: ${output_file}"
  INVENTORY_FILE="${output_file}"
  return 0
}

# Validate the inventory file
validate_inventory() {
  log_info "Validating inventory file: ${INVENTORY_FILE}"

  if [[ ! -f "${INVENTORY_FILE}" ]]; then
    log_error "Inventory file not found: ${INVENTORY_FILE}"
    return 1
  fi

  # Use the consolidated inventory_manager.sh script instead of validate_inventory.sh
  "${PROJECT_ROOT}/scripts/core/inventory_manager.sh" validate --file "${INVENTORY_FILE}"

  return $?
}

# Run deployment
run_deployment() {
  echo -e "${BLUE}Starting deployment...${NC}"

  # Create deployment log
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  LOG_DIR="${PROJECT_ROOT}/logs"
  mkdir -p "${LOG_DIR}"
  DEPLOYMENT_LOG="${LOG_DIR}/deployment_${TIMESTAMP}.log"
  echo "Ephemery Deployment Log - ${TIMESTAMP}" >"${DEPLOYMENT_LOG}"
  echo "=================================" >>"${DEPLOYMENT_LOG}"
  echo "Deployment Type: ${DEPLOYMENT_TYPE}" >>"${DEPLOYMENT_LOG}"
  echo "Validator Enabled: ${ENABLE_VALIDATOR}" >>"${DEPLOYMENT_LOG}"
  echo "Monitoring Enabled: ${ENABLE_MONITORING}" >>"${DEPLOYMENT_LOG}"
  echo "Dashboard Enabled: ${ENABLE_DASHBOARD}" >>"${DEPLOYMENT_LOG}"
  echo "=================================" >>"${DEPLOYMENT_LOG}"

  # Create backup of current state for rollback
  if [[ -f "${INVENTORY_FILE}" ]]; then
    echo -e "${BLUE}Creating backup of current inventory for potential rollback...${NC}"
    BACKUP_DIR="${PROJECT_ROOT}/inventory_backups"
    mkdir -p "${BACKUP_DIR}"
    cp "${INVENTORY_FILE}" "${BACKUP_DIR}/inventory_backup_${TIMESTAMP}.yaml"
    echo "Created inventory backup at ${BACKUP_DIR}/inventory_backup_${TIMESTAMP}.yaml" >>"${DEPLOYMENT_LOG}"
  fi

  # Run Ansible playbook
  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    echo -e "${BLUE}Running local deployment...${NC}"
    echo "Starting local deployment..." >>"${DEPLOYMENT_LOG}"

    # Run the playbook with error handling
    ansible-playbook "${PROJECT_ROOT}/ansible/playbooks/main.yaml" -i "${INVENTORY_FILE}" 2>&1 | tee -a "${DEPLOYMENT_LOG}"
    ANSIBLE_EXIT_CODE=${PIPESTATUS[0]}

    if [[ ${ANSIBLE_EXIT_CODE} -ne 0 ]]; then
      echo -e "${RED}Error: Ansible playbook failed with exit code ${ANSIBLE_EXIT_CODE}${NC}"
      echo -e "${YELLOW}Check the deployment log at ${DEPLOYMENT_LOG} for details${NC}"
      echo "Ansible playbook failed with exit code ${ANSIBLE_EXIT_CODE}" >>"${DEPLOYMENT_LOG}"

      handle_deployment_failure
      return 1
    fi
  elif [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    echo -e "${BLUE}Running remote deployment...${NC}"
    echo "Starting remote deployment to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}..." >>"${DEPLOYMENT_LOG}"

    # Verify SSH connection before proceeding
    echo -e "${BLUE}Verifying SSH connection to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}...${NC}"
    ssh -p "${REMOTE_PORT}" -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "echo SSH connection successful" >>"${DEPLOYMENT_LOG}" 2>&1

    if [[ $? -ne 0 ]]; then
      echo -e "${RED}Error: Failed to establish SSH connection to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}${NC}"
      echo -e "${YELLOW}Please check your SSH credentials and ensure the remote host is reachable${NC}"
      echo "SSH connection test failed" >>"${DEPLOYMENT_LOG}"

      # Provide specific error handling for common SSH issues
      ssh -p "${REMOTE_PORT}" -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "echo" 2>&1 | tee -a "${DEPLOYMENT_LOG}" | grep -q "Permission denied"
      if [[ $? -eq 0 ]]; then
        echo -e "${YELLOW}Permission denied. SSH key may not be properly set up.${NC}"
        echo -e "Try: ssh-copy-id -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}"
      fi

      handle_deployment_failure
      return 1
    fi

    echo -e "${GREEN}✓ SSH connection successful${NC}"
    echo "SSH connection successful" >>"${DEPLOYMENT_LOG}"

    # Ensure host and user variables are sanitized (remove any whitespace)
    REMOTE_HOST=$(echo "${REMOTE_HOST}" | xargs)
    REMOTE_USER=$(echo "${REMOTE_USER}" | xargs)

    # Extract current inventory values
    extract_inventory_info

    # Get current values with whitespace removed
    CURRENT_HOST=$(echo "${INV_HOST}" | xargs)
    CURRENT_USER=$(echo "${INV_USER}" | xargs)

    # Update host if different
    if [[ ! -z "${CURRENT_HOST}" && "${CURRENT_HOST}" != "${REMOTE_HOST}" ]]; then
      echo -e "${YELLOW}Updating remote host in inventory file from ${CURRENT_HOST} to ${REMOTE_HOST}...${NC}"
      echo "Updating remote host in inventory from ${CURRENT_HOST} to ${REMOTE_HOST}" >>"${DEPLOYMENT_LOG}"

      if grep -q "ansible_host:" "${INVENTORY_FILE}"; then
        # New format - Ansible style
        if [[ "$(uname)" == "Darwin" ]]; then
          sed -i '' "s/ansible_host: ${CURRENT_HOST}/ansible_host: ${REMOTE_HOST}/" "${INVENTORY_FILE}"
        else
          sed -i "s/ansible_host: ${CURRENT_HOST}/ansible_host: ${REMOTE_HOST}/" "${INVENTORY_FILE}"
        fi
      else
        # Old format
        if [[ "$(uname)" == "Darwin" ]]; then
          sed -i '' "s/host: ${CURRENT_HOST}/host: ${REMOTE_HOST}/" "${INVENTORY_FILE}"
        else
          sed -i "s/host: ${CURRENT_HOST}/host: ${REMOTE_HOST}/" "${INVENTORY_FILE}"
        fi
      fi
    fi

    # Update user if different
    if [[ ! -z "${CURRENT_USER}" && "${CURRENT_USER}" != "${REMOTE_USER}" ]]; then
      echo -e "${YELLOW}Updating remote user in inventory file from ${CURRENT_USER} to ${REMOTE_USER}...${NC}"
      echo "Updating remote user in inventory from ${CURRENT_USER} to ${REMOTE_USER}" >>"${DEPLOYMENT_LOG}"

      if grep -q "ansible_user:" "${INVENTORY_FILE}"; then
        # New format - Ansible style
        if [[ "$(uname)" == "Darwin" ]]; then
          sed -i '' "s/ansible_user: ${CURRENT_USER}/ansible_user: ${REMOTE_USER}/" "${INVENTORY_FILE}"
        else
          sed -i "s/ansible_user: ${CURRENT_USER}/ansible_user: ${REMOTE_USER}/" "${INVENTORY_FILE}"
        fi
      else
        # Old format
        if [[ "$(uname)" == "Darwin" ]]; then
          sed -i '' "s/user: ${CURRENT_USER}/user: ${REMOTE_USER}/" "${INVENTORY_FILE}"
        else
          sed -i "s/user: ${CURRENT_USER}/user: ${REMOTE_USER}/" "${INVENTORY_FILE}"
        fi
      fi
    fi

    # Run the playbook with error handling
    ansible-playbook "${PROJECT_ROOT}/ansible/playbooks/main.yaml" -i "${INVENTORY_FILE}" --ssh-common-args="-p ${REMOTE_PORT}" 2>&1 | tee -a "${DEPLOYMENT_LOG}"
    ANSIBLE_EXIT_CODE=${PIPESTATUS[0]}

    if [[ ${ANSIBLE_EXIT_CODE} -ne 0 ]]; then
      echo -e "${RED}Error: Ansible playbook failed with exit code ${ANSIBLE_EXIT_CODE}${NC}"
      echo -e "${YELLOW}Check the deployment log at ${DEPLOYMENT_LOG} for details${NC}"
      echo "Ansible playbook failed with exit code ${ANSIBLE_EXIT_CODE}" >>"${DEPLOYMENT_LOG}"

      handle_deployment_failure
      return 1
    fi
  fi

  echo -e "${GREEN}✓ Deployment completed successfully${NC}"
  echo "Deployment completed successfully" >>"${DEPLOYMENT_LOG}"
  echo -e "${BLUE}Deployment log saved to: ${DEPLOYMENT_LOG}${NC}"
  return 0
}

# Handle deployment failures
handle_deployment_failure() {
  echo -e "${RED}Deployment has failed. Taking recovery actions...${NC}"
  echo "Deployment failure detected. Taking recovery actions..." >>"${DEPLOYMENT_LOG}"

  # Ask user whether to attempt recovery
  if [[ "${SKIP_PROMPTS}" == false ]]; then
    echo -e "${YELLOW}Select recovery option:${NC}"
    echo -e "1) Try to fix issues and continue"
    echo -e "2) Rollback to previous state"
    echo -e "3) Exit without further action"

    read -p "Enter your choice (1/2/3): " recovery_choice
    case ${recovery_choice} in
      1) attempt_deployment_recovery ;;
      2) rollback_deployment ;;
      3) echo -e "${YELLOW}Exiting without further action${NC}" ;;
      *) echo -e "${RED}Invalid choice. Exiting.${NC}" ;;
    esac
  else
    # Auto recovery in --yes mode
    echo -e "${YELLOW}Automatically attempting recovery...${NC}"
    attempt_deployment_recovery
  fi
}

# Attempt to recover from deployment failure
attempt_deployment_recovery() {
  echo -e "${BLUE}Attempting to recover from deployment failure...${NC}"
  echo "Attempting recovery from deployment failure..." >>"${DEPLOYMENT_LOG}"

  # Check for common issues
  ISSUE_FOUND=false

  # Check for Docker issues
  if grep -q "docker" "${DEPLOYMENT_LOG}" && grep -q "failed" "${DEPLOYMENT_LOG}"; then
    echo -e "${YELLOW}Detected potential Docker issues. Checking Docker service...${NC}"
    echo "Detected potential Docker issues" >>"${DEPLOYMENT_LOG}"

    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      # Check local Docker service
      if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
        echo -e "${RED}Docker service appears to be unavailable locally.${NC}"
        echo -e "${YELLOW}Try restarting Docker with: 'sudo systemctl restart docker' or equivalent for your OS${NC}"
        echo "Docker service unavailable locally" >>"${DEPLOYMENT_LOG}"
        ISSUE_FOUND=true
      fi
    elif [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
      # Check remote Docker service
      if ! ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "command -v docker && docker info" &>/dev/null; then
        echo -e "${RED}Docker service appears to be unavailable on the remote host.${NC}"
        echo -e "${YELLOW}Try connecting to the remote host and restarting Docker with: 'sudo systemctl restart docker'${NC}"
        echo "Docker service unavailable on remote host" >>"${DEPLOYMENT_LOG}"
        ISSUE_FOUND=true
      fi
    fi
  fi

  # Check for disk space issues
  if grep -q "No space left on device" "${DEPLOYMENT_LOG}"; then
    echo -e "${RED}Detected disk space issues.${NC}"
    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      df -h | tee -a "${DEPLOYMENT_LOG}"
    else
      ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "df -h" | tee -a "${DEPLOYMENT_LOG}"
    fi
    echo -e "${YELLOW}Consider freeing up disk space before retrying deployment.${NC}"
    ISSUE_FOUND=true
  fi

  # Check for permission issues
  if grep -q "Permission denied" "${DEPLOYMENT_LOG}"; then
    echo -e "${RED}Detected permission issues.${NC}"
    echo -e "${YELLOW}Ensure the user has appropriate permissions to directories and Docker.${NC}"
    echo "Permission issues detected" >>"${DEPLOYMENT_LOG}"
    ISSUE_FOUND=true
  fi

  # If no specific issues found or after addressing them, offer to retry
  if [[ "${ISSUE_FOUND}" == true ]]; then
    echo -e "${BLUE}Would you like to retry the deployment after addressing these issues?${NC}"
    if [[ "${SKIP_PROMPTS}" == false ]]; then
      read -p "Retry deployment? (y/n): " retry
      if [[ "${retry}" == "y" || "${retry}" == "Y" ]]; then
        echo -e "${BLUE}Retrying deployment...${NC}"
        echo "Retrying deployment" >>"${DEPLOYMENT_LOG}"
        run_deployment
      else
        echo -e "${YELLOW}Deployment retry skipped. Exiting.${NC}"
        echo "Deployment retry skipped by user" >>"${DEPLOYMENT_LOG}"
      fi
    else
      echo -e "${BLUE}Automatically retrying deployment...${NC}"
      echo "Automatically retrying deployment" >>"${DEPLOYMENT_LOG}"
      run_deployment
    fi
  else
    echo -e "${YELLOW}No specific issues identified. Consider checking the deployment log for details.${NC}"
    echo "No specific issues identified for recovery" >>"${DEPLOYMENT_LOG}"

    if [[ "${SKIP_PROMPTS}" == false ]]; then
      read -p "Would you like to retry the deployment anyway? (y/n): " retry
      if [[ "${retry}" == "y" || "${retry}" == "Y" ]]; then
        echo -e "${BLUE}Retrying deployment...${NC}"
        echo "Retrying deployment" >>"${DEPLOYMENT_LOG}"
        run_deployment
      else
        echo -e "${YELLOW}Deployment retry skipped. Exiting.${NC}"
        echo "Deployment retry skipped by user" >>"${DEPLOYMENT_LOG}"
      fi
    fi
  fi
}

# Rollback to previous state
rollback_deployment() {
  echo -e "${BLUE}Attempting to rollback deployment...${NC}"
  echo "Attempting to rollback deployment..." >>"${DEPLOYMENT_LOG}"

  # Find the latest backup
  BACKUP_DIR="${PROJECT_ROOT}/inventory_backups"
  LATEST_BACKUP=$(find "${BACKUP_DIR}" -name "inventory_backup_*.yaml" -type f -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)

  if [[ -z "${LATEST_BACKUP}" ]]; then
    echo -e "${RED}No backup inventory found for rollback.${NC}"
    echo "No backup inventory found for rollback" >>"${DEPLOYMENT_LOG}"
    return 1
  fi

  echo -e "${BLUE}Found backup inventory: ${LATEST_BACKUP}${NC}"
  echo "Found backup inventory: ${LATEST_BACKUP}" >>"${DEPLOYMENT_LOG}"

  # Restore the inventory file
  cp "${LATEST_BACKUP}" "${INVENTORY_FILE}"
  echo -e "${GREEN}✓ Restored inventory file from backup${NC}"
  echo "Restored inventory file from backup" >>"${DEPLOYMENT_LOG}"

  # For remote deployment, stop any running services
  if [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    echo -e "${BLUE}Attempting to stop any running services on remote host...${NC}"
    echo "Attempting to stop services on remote host" >>"${DEPLOYMENT_LOG}"

    # Try to connect and stop services safely
    ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "
      if command -v docker &> /dev/null; then
        echo 'Stopping Docker containers...'
        docker ps -a --format '{{.Names}}' | grep -E 'ephemery|geth|lighthouse|prysm|teku|nimbus|nethermind|besu|erigon' | xargs -r docker stop
        echo 'Done stopping containers'
      else
        echo 'Docker not found on remote system'
      fi
    " >>"${DEPLOYMENT_LOG}" 2>&1

    if [[ $? -ne 0 ]]; then
      echo -e "${YELLOW}Warning: Could not stop services on remote host.${NC}"
      echo "Warning: Failed to stop services on remote host" >>"${DEPLOYMENT_LOG}"
    else
      echo -e "${GREEN}✓ Successfully stopped services on remote host${NC}"
      echo "Successfully stopped services on remote host" >>"${DEPLOYMENT_LOG}"
    fi
  fi

  echo -e "${GREEN}Rollback completed.${NC}"
  echo "Rollback completed" >>"${DEPLOYMENT_LOG}"

  # Ask if user wants to retry deployment
  if [[ "${SKIP_PROMPTS}" == false ]]; then
    read -p "Would you like to retry the deployment with the rolled back configuration? (y/n): " retry
    if [[ "${retry}" == "y" || "${retry}" == "Y" ]]; then
      echo -e "${BLUE}Retrying deployment with rolled back configuration...${NC}"
      echo "Retrying deployment with rolled back configuration" >>"${DEPLOYMENT_LOG}"
      run_deployment
    else
      echo -e "${YELLOW}Deployment retry skipped. Exiting.${NC}"
      echo "Deployment retry skipped by user" >>"${DEPLOYMENT_LOG}"
    fi
  fi
}

# Setup retention if enabled
setup_retention() {
  if [[ "${SETUP_RETENTION}" == true ]]; then
    echo -e "${BLUE}Setting up Ephemery retention system...${NC}"
    "${PROJECT_ROOT}/scripts/deployment/deploy_ephemery_retention.sh"
    echo -e "${GREEN}✓ Ephemery retention system set up${NC}"
  fi
}

# Verify deployment
verify_deployment() {
  if [[ "${VERIFY_DEPLOYMENT}" == true ]]; then
    echo -e "${BLUE}Verifying deployment...${NC}"

    # Ensure host and user variables are sanitized (remove any whitespace)
    REMOTE_HOST=$(echo "${REMOTE_HOST}" | xargs)
    REMOTE_USER=$(echo "${REMOTE_USER}" | xargs)
    REMOTE_PORT=$(echo "${REMOTE_PORT}" | xargs)

    # Get latest values from inventory file
    extract_inventory_info

    # Implement verification tests here
    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      # Local verification
      echo -e "${YELLOW}Checking Docker containers...${NC}"

      # Check execution and consensus clients
      if docker ps | grep -q "ephemery-geth" && docker ps | grep -q "ephemery-lighthouse"; then
        echo -e "${GREEN}✓ Core Docker containers running${NC}"
      else
        echo -e "${RED}✗ Some core Docker containers are not running${NC}"
        echo -e "${YELLOW}Troubleshooting: Check logs with 'docker logs ephemery-geth' and 'docker logs ephemery-lighthouse'${NC}"
      fi

      # Check validator if enabled
      if [[ "${ENABLE_VALIDATOR}" == true ]]; then
        echo -e "${YELLOW}Checking validator container...${NC}"
        if docker ps | grep -q "ephemery-validator"; then
          echo -e "${GREEN}✓ Validator container running${NC}"

          # Check validator keys
          if docker exec ephemery-validator ls -la /var/lib/lighthouse/validators/keys/ 2>/dev/null | grep -q ".json"; then
            echo -e "${GREEN}✓ Validator keys found${NC}"
          else
            echo -e "${YELLOW}⚠ No validator keys found in container${NC}"
            echo -e "${YELLOW}Troubleshooting: Check if keys were properly imported${NC}"
          fi
        else
          echo -e "${RED}✗ Validator container is not running${NC}"
          echo -e "${YELLOW}Troubleshooting: Check logs with 'docker logs ephemery-validator'${NC}"
        fi
      fi

      # Check monitoring if enabled
      if [[ "${ENABLE_MONITORING}" == true ]]; then
        echo -e "${YELLOW}Checking monitoring containers...${NC}"
        if docker ps | grep -q "ephemery-prometheus" && docker ps | grep -q "ephemery-grafana"; then
          echo -e "${GREEN}✓ Monitoring containers running${NC}"
        else
          echo -e "${RED}✗ Some monitoring containers are not running${NC}"
          echo -e "${YELLOW}Troubleshooting: Check logs with 'docker logs ephemery-prometheus' and 'docker logs ephemery-grafana'${NC}"
        fi
      fi

    elif [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
      # Remote verification
      echo -e "${YELLOW}Checking remote services...${NC}"

      # Use a timeout to prevent hanging on SSH connection issues
      if timeout 10 ssh -o ConnectTimeout=5 -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps | grep -q ephemery-geth && docker ps | grep -q ephemery-lighthouse"; then
        echo -e "${GREEN}✓ Core remote services running${NC}"

        # Check validator if enabled
        if [[ "${ENABLE_VALIDATOR}" == true ]]; then
          echo -e "${YELLOW}Checking remote validator container...${NC}"
          if timeout 10 ssh -o ConnectTimeout=5 -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps | grep -q ephemery-validator"; then
            echo -e "${GREEN}✓ Remote validator container running${NC}"

            # Check validator keys
            if timeout 10 ssh -o ConnectTimeout=5 -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker exec ephemery-validator ls -la /var/lib/lighthouse/validators/keys/ 2>/dev/null | grep -q '.json'"; then
              echo -e "${GREEN}✓ Remote validator keys found${NC}"
            else
              echo -e "${YELLOW}⚠ No validator keys found in remote container${NC}"
              echo -e "${YELLOW}Troubleshooting: Check if keys were properly imported${NC}"
            fi
          else
            echo -e "${RED}✗ Remote validator container is not running${NC}"
            echo -e "${YELLOW}Troubleshooting: Check logs with 'ssh ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT} \"docker logs ephemery-validator\"'${NC}"
          fi
        fi

        # Check monitoring if enabled
        if [[ "${ENABLE_MONITORING}" == true ]]; then
          echo -e "${YELLOW}Checking remote monitoring containers...${NC}"
          if timeout 10 ssh -o ConnectTimeout=5 -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps | grep -q ephemery-prometheus && docker ps | grep -q ephemery-grafana"; then
            echo -e "${GREEN}✓ Remote monitoring containers running${NC}"
          else
            echo -e "${RED}✗ Some remote monitoring containers are not running${NC}"
            echo -e "${YELLOW}Troubleshooting: Check logs with 'ssh ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT} \"docker logs ephemery-prometheus\"' and 'ssh ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT} \"docker logs ephemery-grafana\"'${NC}"
          fi
        fi
      else
        echo -e "${RED}✗ Some remote services are not running or SSH connection failed${NC}"
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "  - Check SSH connection: ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}"
        echo -e "  - Check Docker service: ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} 'sudo systemctl status docker'"
        echo -e "  - Check container status: ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} 'docker ps'"
        echo -e "  - View container logs:"
        echo -e "    ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} 'docker logs ephemery-geth'"
        echo -e "    ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} 'docker logs ephemery-lighthouse'"
      fi
    fi

    echo -e "${GREEN}✓ Deployment verification completed${NC}"
  fi
}

# Display final information
show_final_info() {
  # Ensure host and user variables are sanitized (remove any whitespace)
  REMOTE_HOST=$(echo "${REMOTE_HOST}" | xargs)
  REMOTE_USER=$(echo "${REMOTE_USER}" | xargs)
  REMOTE_PORT=$(echo "${REMOTE_PORT}" | xargs)

  # Get latest values from inventory file
  extract_inventory_info

  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}       Ephemery Deployment Completed Successfully               ${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo ""

  if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
    echo -e "Geth API: http://localhost:8545"
    echo -e "Lighthouse API: http://localhost:5052"

    if [[ "${ENABLE_VALIDATOR}" == true ]]; then
      echo -e "Validator API: http://localhost:5062"
      echo -e "Validator Metrics: http://localhost:5064/metrics"
    fi

    if [[ "${ENABLE_DASHBOARD}" == true ]]; then
      echo -e "Dashboard: http://localhost/ephemery-status/"
    fi

    if [[ "${ENABLE_MONITORING}" == true ]]; then
      echo -e "Prometheus: http://localhost:9090"
      echo -e "Grafana: http://localhost:3000 (admin/admin)"
    fi

    echo -e "\nTo monitor the sync status:"
    echo -e "  docker logs -f ephemery-geth"
    echo -e "  docker logs -f ephemery-lighthouse"

    if [[ "${ENABLE_VALIDATOR}" == true ]]; then
      echo -e "\nTo monitor validator status:"
      echo -e "  docker logs -f ephemery-validator"
      echo -e "  curl http://localhost:5064/metrics | grep -i validator"
    fi
  elif [[ "${DEPLOYMENT_TYPE}" == "remote" ]]; then
    echo -e "Geth API: http://${REMOTE_HOST}:8545"
    echo -e "Lighthouse API: http://${REMOTE_HOST}:5052"

    if [[ "${ENABLE_VALIDATOR}" == true ]]; then
      echo -e "Validator API: http://${REMOTE_HOST}:5062"
      echo -e "Validator Metrics: http://${REMOTE_HOST}:5064/metrics"
    fi

    if [[ "${ENABLE_DASHBOARD}" == true ]]; then
      echo -e "Dashboard: http://${REMOTE_HOST}/ephemery-status/"
    fi

    if [[ "${ENABLE_MONITORING}" == true ]]; then
      echo -e "Prometheus: http://${REMOTE_HOST}:9090"
      echo -e "Grafana: http://${REMOTE_HOST}:3000 (admin/admin)"
    fi

    echo -e "\nTo monitor the sync status:"
    echo -e "  ssh ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT}"
    echo -e "  docker logs -f ephemery-geth"
    echo -e "  docker logs -f ephemery-lighthouse"

    if [[ "${ENABLE_VALIDATOR}" == true ]]; then
      echo -e "\nTo monitor validator status:"
      echo -e "  ssh ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT}"
      echo -e "  docker logs -f ephemery-validator"
      echo -e "  curl http://${REMOTE_HOST}:5064/metrics | grep -i validator"
    fi
  fi

  echo -e "\nFor troubleshooting, run:"
  echo -e "  ${PROJECT_ROOT}/scripts/troubleshoot-ephemery.sh"

  echo -e "\nTo check sync status, run:"
  echo -e "  ${PROJECT_ROOT}/scripts/check_sync_status.sh"

  if [[ "${SETUP_RETENTION}" == true ]]; then
    echo -e "\nEphemery retention is enabled. The system will automatically detect and handle weekly resets."
  fi

  if [[ "${ENABLE_VALIDATOR}" == true ]]; then
    echo -e "\nValidator is enabled. To check validator status:"
    if [[ "${DEPLOYMENT_TYPE}" == "local" ]]; then
      echo -e "  curl -s http://localhost:5064/metrics | grep -i validator_active"
    else
      echo -e "  curl -s http://${REMOTE_HOST}:5064/metrics | grep -i validator_active"
    fi
    echo -e "\nTo manage validator keys:"
    echo -e "  ${PROJECT_ROOT}/scripts/validator/manage_validator_keys.sh"
  fi

  echo -e "\nThank you for using Ephemery!"
}

# Main function
main() {
  # Show welcome banner
  show_banner

  # Parse command line arguments
  parse_args "$@"

  if [[ "${DEPLOYMENT_TYPE}" == "help" ]]; then
    show_help
    exit 0
  fi

  # Select deployment type
  select_deployment_type

  # Check prerequisites
  check_prerequisites

  # Get remote connection details
  get_remote_details

  # Validate remote host is specified
  if [[ "${DEPLOYMENT_TYPE}" == "remote" && -z "${REMOTE_HOST}" ]]; then
    echo -e "${RED}Error: Remote host is required for remote deployment${NC}"
    exit 1
  fi

  # Configure deployment
  configure_deployment

  # Generate or validate inventory file
  if [[ "${CUSTOM_CONFIG}" == true ]]; then
    echo -e "${BLUE}Using custom inventory file: ${INVENTORY_FILE}${NC}"
    echo -e "${BLUE}Validating inventory...${NC}"
    "${PROJECT_ROOT}/scripts/utils/validate_inventory.sh" "${INVENTORY_FILE}"
    echo -e "${GREEN}✓ Inventory validation passed${NC}"
  else
    generate_default_inventory || {
      log_error "Failed to generate default inventory"
      exit 1
    }
  fi

  # Final inventory validation before actual deployment
  log_info "Performing final inventory validation..."
  "${PROJECT_ROOT}/scripts/core/inventory_manager.sh" validate --file "${INVENTORY_FILE}"
  if [[ $? -ne 0 ]]; then
    log_error "Final inventory validation failed. Aborting deployment."
    exit 1
  fi

  # Run deployment
  run_deployment

  # Setup retention if enabled
  setup_retention

  # Verify deployment
  if [[ "${VERIFY_DEPLOYMENT}" == true ]]; then
    verify_deployment
  fi

  # Show final information
  show_final_info
}

# Execute main function
main "$@"
