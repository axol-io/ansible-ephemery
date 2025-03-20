#!/bin/bash

# install_dependencies.sh - Consolidated script for installing all dependencies
# This script installs all required Python packages and Ansible collections

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Import common functions
if [[ -f "${PROJECT_ROOT}/scripts/lib/common_basic.sh" ]]; then
  source "${PROJECT_ROOT}/scripts/lib/common_basic.sh"
else
  # Define colors for output if common library is not available
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  # Function to print colored messages
  print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
  }
fi

# Function to show help message
show_help() {
  echo "Install Dependencies - Consolidated dependency installation tool"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --python-only           Install only Python dependencies"
  echo "  --ansible-only          Install only Ansible collections"
  echo "  --dev                   Include development dependencies"
  echo "  --upgrade               Upgrade existing packages"
  echo "  --requirements <file>   Use alternative requirements file"
  echo "  --collections <file>    Use alternative collections file"
  echo "  --help                  Show this help message"
}

# Function to install Python dependencies
install_python_deps() {
  local requirements_file="$1"
  local dev_mode="$2"
  local upgrade="$3"

  print_status "$GREEN" "Installing Python dependencies..."

  if [[ ! -f "$requirements_file" ]]; then
    print_status "$RED" "Error: Requirements file not found: $requirements_file"
    return 1
  fi

  local pip_cmd="pip3 install"

  if [[ "$upgrade" == "true" ]]; then
    pip_cmd="$pip_cmd --upgrade"
  fi

  print_status "$BLUE" "Installing from: $requirements_file"
  $pip_cmd -r "$requirements_file"

  if [[ "$dev_mode" == "true" && -f "${PROJECT_ROOT}/requirements-dev.txt" ]]; then
    print_status "$BLUE" "Installing development dependencies from: ${PROJECT_ROOT}/requirements-dev.txt"
    $pip_cmd -r "${PROJECT_ROOT}/requirements-dev.txt"
  fi

  print_status "$GREEN" "Python dependencies installation completed."
  return 0
}

# Function to install Ansible collections
install_ansible_collections() {
  local collections_file="$1"
  local upgrade="$2"

  print_status "$GREEN" "Installing Ansible collections..."

  if [[ ! -f "$collections_file" ]]; then
    print_status "$RED" "Error: Collections file not found: $collections_file"
    return 1
  fi

  local ansible_cmd="ansible-galaxy collection install -r"

  if [[ "$upgrade" == "true" ]]; then
    ansible_cmd="$ansible_cmd --force"
  fi

  print_status "$BLUE" "Installing from: $collections_file"
  $ansible_cmd "$collections_file"

  print_status "$GREEN" "Ansible collections installation completed."
  return 0
}

# Main function
main() {
  # Default configuration
  local python_only=false
  local ansible_only=false
  local dev_mode=false
  local upgrade=false
  local requirements_file="${PROJECT_ROOT}/requirements.txt"
  local collections_file="${PROJECT_ROOT}/requirements.yaml"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --python-only)
        python_only=true
        shift
        ;;
      --ansible-only)
        ansible_only=true
        shift
        ;;
      --dev)
        dev_mode=true
        shift
        ;;
      --upgrade)
        upgrade=true
        shift
        ;;
      --requirements)
        requirements_file="$2"
        shift 2
        ;;
      --collections)
        collections_file="$2"
        shift 2
        ;;
      --help)
        show_help
        return 0
        ;;
      *)
        print_status "$RED" "Error: Unknown option: $1"
        show_help
        return 1
        ;;
    esac
  done

  print_status "$GREEN" "Starting dependency installation..."

  # Install dependencies based on options
  if [[ "$python_only" == "false" && "$ansible_only" == "false" ]]; then
    # Install both when no specific option is provided
    install_python_deps "$requirements_file" "$dev_mode" "$upgrade"
    install_ansible_collections "$collections_file" "$upgrade"
  elif [[ "$python_only" == "true" ]]; then
    install_python_deps "$requirements_file" "$dev_mode" "$upgrade"
  elif [[ "$ansible_only" == "true" ]]; then
    install_ansible_collections "$collections_file" "$upgrade"
  fi

  print_status "$GREEN" "Dependency installation complete."
  return 0
}

# Call main function with all arguments
main "$@"

exit $?
