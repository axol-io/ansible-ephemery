#!/usr/bin/env bash
# ==============================================================================
# Script: common_functions.sh
# ------------------------------------------------------------------------------
# Purpose: Common utility functions for Ephemery scripts
#
# Usage:
#   source common_functions.sh
#
# Author: Ephemery Team
# Creation Date: $(date +%Y-%m-%d)
# ==============================================================================

# Exit on error if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is meant to be sourced, not executed directly."
  exit 1
fi

# Global constants
readonly EPHEMERY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DEFAULT_ANSIBLE_PATH="${EPHEMERY_ROOT}/ansible"
readonly DEFAULT_PLAYBOOKS_PATH="${EPHEMERY_ROOT}/playbooks"
readonly DEFAULT_CONFIG_PATH="${EPHEMERY_ROOT}/config"

# Color definitions for better output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
function log_info() {
  echo -e "[${GREEN}INFO${NC}] [$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

function log_warning() {
  echo -e "[${YELLOW}WARNING${NC}] [$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

function log_error() {
  echo -e "[${RED}ERROR${NC}] [$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

function log_debug() {
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    echo -e "[${BLUE}DEBUG${NC}] [$(date +'%Y-%m-%d %H:%M:%S')] $*"
  fi
}

# Error handling function
function handle_error() {
  local error_code=$?
  local line_number=$1
  log_error "Error occurred at line ${line_number} with exit code ${error_code}"
  exit "${error_code}"
}

# Function to check required commands
function check_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log_error "Required command '${cmd}' not found. Please install it and try again."
    return 1
  fi
  return 0
}

# Function to check required commands for Ephemery
function check_ephemery_dependencies() {
  local dependencies=("ansible" "ansible-playbook" "python3" "docker" "git")
  local missing_deps=()

  for dep in "${dependencies[@]}"; do
    if ! check_command "${dep}"; then
      missing_deps+=("${dep}")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    return 1
  fi

  log_info "All required dependencies are installed"
  return 0
}

# Function to validate IP address
function validate_ip() {
  local ip="$1"
  if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  else
    log_error "Invalid IP address format: ${ip}"
    return 1
  fi
}

# Function to validate client name
function validate_client() {
  local client="$1"
  local client_type="$2"
  local valid_clients=()

  case "${client_type}" in
    "execution")
      valid_clients=("geth" "nethermind" "besu" "erigon")
      ;;
    "consensus")
      valid_clients=("lighthouse" "prysm" "teku" "nimbus" "lodestar")
      ;;
    *)
      log_error "Invalid client type: ${client_type}"
      return 1
      ;;
  esac

  for valid_client in "${valid_clients[@]}"; do
    if [[ "${client}" == "${valid_client}" ]]; then
      return 0
    fi
  done

  log_error "Invalid ${client_type} client: ${client}"
  log_info "Valid ${client_type} clients are: ${valid_clients[*]}"
  return 1
}

# Function to run Ansible playbook
function run_ansible_playbook() {
  local playbook="$1"
  local inventory="$2"
  shift 2

  log_info "Running Ansible playbook: ${playbook}"
  log_info "Using inventory: ${inventory}"

  if [[ "${VERBOSE:-false}" == "true" ]]; then
    ansible-playbook -i "${inventory}" "${playbook}" "$@"
  else
    ansible-playbook -i "${inventory}" "${playbook}" "$@" >/dev/null
  fi

  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Ansible playbook execution failed with exit code ${exit_code}"
    return ${exit_code}
  fi

  log_info "Ansible playbook execution completed successfully"
  return 0
}

# Function to check node health
function check_node_health() {
  local node_ip="$1"
  local port="${2:-22}"

  log_info "Checking health of node at ${node_ip}:${port}"

  if ! ping -c 1 "${node_ip}" >/dev/null 2>&1; then
    log_error "Node at ${node_ip} is not responding to ping"
    return 1
  fi

  if ! nc -z "${node_ip}" "${port}" >/dev/null 2>&1; then
    log_error "Node at ${node_ip} is not listening on port ${port}"
    return 1
  fi

  log_info "Node at ${node_ip} is healthy"
  return 0
}

# Function to find available port
function find_available_port() {
  local start_port="${1:-8000}"
  local end_port="${2:-9000}"
  local ip="${3:-127.0.0.1}"

  for port in $(seq "${start_port}" "${end_port}"); do
    if ! nc -z "${ip}" "${port}" >/dev/null 2>&1; then
      echo "${port}"
      return 0
    fi
  done

  log_error "No available ports found in range ${start_port}-${end_port}"
  return 1
}

# Set up error trap if not already set
if [[ "${TRAP_ERRORS:-false}" != "true" ]]; then
  trap 'handle_error $LINENO' ERR
  readonly TRAP_ERRORS="true"
fi

# Utility Functions
# -----------------------------------------------------------------------------

# Check if command exists
function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Print colored output
function print_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

# Print success message
function print_success() {
  print_color "$GREEN" "✓ $1"
}

# Print error message
function print_error() {
  print_color "$RED" "✗ $1" >&2
}

# Print warning message
function print_warning() {
  print_color "$YELLOW" "⚠ $1" >&2
}

# Print info message
function print_info() {
  print_color "$BLUE" "ℹ $1"
}

# Check required commands
function check_required_commands() {
  local missing_commands=0
  
  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      print_error "Required command not found: $cmd"
      missing_commands=$((missing_commands+1))
    fi
  done
  
  if [ $missing_commands -gt 0 ]; then
    return 1
  fi
  
  return 0
}

# Create a backup of a file
function backup_file() {
  local file="$1"
  local backup="${file}.$(date +%Y%m%d%H%M%S).bak"
  
  if [[ -f "$file" ]]; then
    cp "$file" "$backup"
    print_info "Created backup: $backup"
    return 0
  else
    print_warning "File does not exist, cannot create backup: $file"
    return 1
  fi
}

# Check if running as root
function is_root() {
  if [[ $EUID -ne 0 ]]; then
    return 1
  fi
  return 0
}

# Check if a variable is set
function is_set() {
  [[ -n "${!1:-}" ]]
}

# Check if a port is in use
function is_port_in_use() {
  local port="$1"
  if command_exists "nc"; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
    return $?
  elif command_exists "lsof"; then
    lsof -i:"$port" >/dev/null 2>&1
    return $?
  else
    print_warning "Cannot check if port is in use (nc or lsof not found)"
    return 2
  fi
}

# Wait for a service to be available on a port
function wait_for_port() {
  local port="$1"
  local timeout="${2:-30}"
  local sleep_time="${3:-1}"
  local elapsed=0
  
  print_info "Waiting for port $port to be available..."
  
  while ! is_port_in_use "$port"; do
    if [ "$elapsed" -ge "$timeout" ]; then
      print_error "Timeout reached waiting for port $port"
      return 1
    fi
    
    sleep "$sleep_time"
    elapsed=$((elapsed + sleep_time))
  done
  
  print_success "Port $port is now available"
  return 0
}

# Integration with Ansible
# -----------------------------------------------------------------------------

# Get Ansible installation path
function get_ansible_path() {
  if command_exists "ansible"; then
    which ansible
  else
    print_error "Ansible is not installed"
    return 1
  fi
}

# Check if JWT secret file exists and has correct permissions
function check_jwt_secret() {
  local jwt_path="${1:-/etc/ethereum/jwt.hex}"
  
  if [[ ! -f "$jwt_path" ]]; then
    print_error "JWT secret file not found: $jwt_path"
    return 1
  fi
  
  local perms
  perms=$(stat -c "%a" "$jwt_path" 2>/dev/null || stat -f "%Lp" "$jwt_path" 2>/dev/null)
  
  if [[ "$perms" != "600" ]]; then
    print_warning "JWT secret file has incorrect permissions: $perms (should be 600)"
    return 2
  fi
  
  print_success "JWT secret file exists with correct permissions"
  return 0
}

# Check client sync status
function check_client_sync_status() {
  local client_type="$1"  # 'execution' or 'consensus'
  local endpoint="$2"     # RPC endpoint
  
  case "$client_type" in
    execution)
      # Call appropriate RPC method for execution client sync status
      curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' "$endpoint"
      ;;
    consensus)
      # Call appropriate RPC method for consensus client sync status
      curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"lighthouse_head","params":[],"id":1}' "$endpoint"
      ;;
    *)
      print_error "Unknown client type: $client_type"
      return 1
      ;;
  esac
  
  return 0
} 