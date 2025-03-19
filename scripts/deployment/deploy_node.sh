#!/usr/bin/env bash
#
# =============================================================================
# Script Name: deploy_node.sh
# Description: Deploy an Ephemery node with specified client combination
# Usage: ./deploy_node.sh [options]
# Parameters:
#   -h, --help                Display this help message
#   -i, --inventory           Path to inventory file
#   -e, --execution-client    Execution client (geth, nethermind, besu, erigon)
#   -c, --consensus-client    Consensus client (lighthouse, prysm, teku, nimbus, lodestar)
#   -d, --data-dir            Data directory (default: /opt/ephemery)
#   -n, --network             Network ID (default: 13337)
#   -v, --verbose             Enable verbose output
# Author: Ephemery Team
# Creation Date: $(date +%Y-%m-%d)
# =============================================================================

# Exit on error, undefined variables, and propagate pipe failures
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_DIR}/../utilities/common_functions.sh" ]]; then
    source "${SCRIPT_DIR}/../utilities/common_functions.sh"
fi

# Default values
INVENTORY=""
EL_CLIENT="geth"
CL_CLIENT="lighthouse"
DATA_DIR="/opt/ephemery"
NETWORK_ID="13337"
VERBOSE=false
EPHEMERY_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
PLAYBOOK="${EPHEMERY_ROOT}/playbooks/deploy_ephemery.yaml"

# Function to display usage information
function display_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help                Display this help message"
    echo "  -i, --inventory           Path to inventory file"
    echo "  -e, --execution-client    Execution client (geth, nethermind, besu, erigon)"
    echo "  -c, --consensus-client    Consensus client (lighthouse, prysm, teku, nimbus, lodestar)"
    echo "  -d, --data-dir            Data directory (default: /opt/ephemery)"
    echo "  -n, --network             Network ID (default: 13337)"
    echo "  -v, --verbose             Enable verbose output"
    exit 0
}

# Parse command line arguments
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_usage
                ;;
            -i|--inventory)
                INVENTORY="$2"
                shift 2
                ;;
            -e|--execution-client)
                EL_CLIENT="$2"
                shift 2
                ;;
            -c|--consensus-client)
                CL_CLIENT="$2"
                shift 2
                ;;
            -d|--data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            -n|--network)
                NETWORK_ID="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                log_error "Unknown parameter: $1"
                display_usage
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "${INVENTORY}" ]]; then
        log_error "Inventory file is required"
        display_usage
    fi

    # Validate clients
    if ! validate_client "${EL_CLIENT}" "execution"; then
        log_error "Invalid execution client: ${EL_CLIENT}"
        exit 1
    fi

    if ! validate_client "${CL_CLIENT}" "consensus"; then
        log_error "Invalid consensus client: ${CL_CLIENT}"
        exit 1
    fi
}

# Function to check prerequisites
function check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "ansible-playbook command not found"
        log_info "Please install Ansible with: pip install ansible"
        exit 1
    fi
    
    # Check if playbook exists
    if [[ ! -f "${PLAYBOOK}" ]]; then
        log_error "Playbook not found at: ${PLAYBOOK}"
        exit 1
    fi
    
    # Check if inventory file exists
    if [[ ! -f "${INVENTORY}" ]]; then
        log_error "Inventory file not found at: ${INVENTORY}"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Function to deploy the node
function deploy_node() {
    local ansible_args=()
    local extra_vars="el_client_name=${EL_CLIENT} cl_client_name=${CL_CLIENT} data_dir=${DATA_DIR} network_id=${NETWORK_ID}"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        ansible_args+=(-v)
    fi
    
    log_info "Deploying Ephemery node with:"
    log_info "  Execution Client: ${EL_CLIENT}"
    log_info "  Consensus Client: ${CL_CLIENT}"
    log_info "  Data Directory: ${DATA_DIR}"
    log_info "  Network ID: ${NETWORK_ID}"
    
    log_info "Running Ansible playbook..."
    # shellcheck disable=SC2086
    ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" -e "${extra_vars}" "${ansible_args[@]}"
    
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Deployment failed with exit code ${exit_code}"
        return ${exit_code}
    fi
    
    log_info "Deployment completed successfully"
    log_info "Run the following to check node status:"
    log_info "  ${SCRIPT_DIR}/../maintenance/check_sync_status.sh -i ${INVENTORY}"
}

# Main function
function main() {
    log_info "Starting Ephemery node deployment"
    
    check_prerequisites
    deploy_node
    
    log_info "Deployment process completed"
    return 0
}

# Parse arguments
parse_arguments "$@"

# Execute main function
main 