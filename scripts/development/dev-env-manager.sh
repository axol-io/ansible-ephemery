#!/bin/bash
# Version: 1.0.0
# dev-env-manager.sh - Consolidated script for development environment management
# Combines functionality from:
# - setup-dev-env.sh
# - install-collections.sh
# - test-collections.sh

set -e

# Print main usage information
function usage {
  echo "Usage: $0 <command> [options]"
  echo
  echo "Commands:"
  echo "  setup               Set up a complete development environment"
  echo "  install-collections Install Ansible collections from requirements.yaml"
  echo "  test-collections    Test if all required collections are installed"
  echo "  help                Show this help message"
  echo
  echo "Options:"
  echo "  -v, --verbose       Enable verbose output"
  echo "  -h, --help          Show command-specific help"
}

# Print setup command usage
function usage_setup {
  echo "Usage: $0 setup [options]"
  echo
  echo "Set up a complete development environment."
  echo
  echo "Options:"
  echo "  -s, --skip-virtualenv  Skip virtual environment creation"
  echo "  -c, --skip-collections Skip collection installation"
  echo "  -p, --skip-packages    Skip Python package installation"
  echo "  -v, --verbose          Enable verbose output"
}

# Print install-collections usage
function usage_install_collections {
  echo "Usage: $0 install-collections [options]"
  echo
  echo "Install Ansible collections from requirements.yaml file."
  echo
  echo "Options:"
  echo "  -f, --force         Force reinstallation of collections"
  echo "  -c, --check         Just check if collections need to be installed"
  echo "  -v, --verbose       Enable verbose output"
}

# Print test-collections usage
function usage_test_collections {
  echo "Usage: $0 test-collections [options]"
  echo
  echo "Test if all required collections from requirements.yaml are installed."
  echo
  echo "Options:"
  echo "  -v, --verbose       Enable verbose output"
}

# Function to set up the development environment
function setup_dev_env {
  local skip_virtualenv=0
  local skip_collections=0
  local skip_packages=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s | --skip-virtualenv)
        skip_virtualenv=1
        shift
        ;;
      -c | --skip-collections)
        skip_collections=1
        shift
        ;;
      -p | --skip-packages)
        skip_packages=1
        shift
        ;;
      -v | --verbose)
        verbose=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage_setup
        exit 1
        ;;
    esac
  done

  echo "Setting up development environment..."

  # Create virtual environment
  if [ ${skip_virtualenv} -eq 0 ]; then
    echo "Creating Python virtual environment..."
    if [ -d "venv" ]; then
      echo "Virtual environment already exists. Skipping creation."
    else
      python3 -m venv venv
      echo "Virtual environment created successfully."
    fi

    # Activate virtual environment
    echo "Activating virtual environment..."
    source venv/bin/activate
  else
    echo "Skipping virtual environment creation."
  fi

  # Install Python packages
  if [ ${skip_packages} -eq 0 ]; then
    echo "Installing required Python packages..."
    pip install -r requirements.txt
    pip install -r requirements-dev.txt
    echo "Python packages installed successfully."
  else
    echo "Skipping Python package installation."
  fi

  # Install Ansible collections
  if [ ${skip_collections} -eq 0 ]; then
    echo "Installing Ansible collections..."
    install_collections --force
  else
    echo "Skipping Ansible collection installation."
  fi

  # Install pre-commit hooks
  echo "Installing pre-commit hooks..."
  pre-commit install

  echo "Development environment setup complete!"
  echo ""
  echo "To activate this environment:"
  echo "  source venv/bin/activate"
  echo ""
  echo "To run linting and tests:"
  echo "  ansible-lint"
  echo "  $0 test-collections"
  echo "  molecule test -s default"
}

# Function to install Ansible collections
function install_collections {
  local force=0
  local check=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f | --force)
        force=1
        shift
        ;;
      -c | --check)
        check=1
        shift
        ;;
      -v | --verbose)
        verbose=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage_install_collections
        exit 1
        ;;
    esac
  done

  # Check if requirements.yaml exists
  if [ ! -f "requirements.yaml" ]; then
    echo "Error: requirements.yaml file not found."
    exit 1
  fi

  echo "Processing Ansible collections from requirements.yaml..."

  # Extract collections from requirements.yaml
  collections=$(grep -A 100 "collections:" requirements.yaml | grep -B 100 -m 1 -e "^[a-z]*:" -e "^$" | grep "name:" | cut -d ':' -f 2 | sed 's/ //g')

  if [ -z "${collections}" ]; then
    echo "No collections found in requirements.yaml."
    exit 1
  fi

  # Check or install collections
  if [ ${check} -eq 1 ]; then
    echo "Checking if collections are installed..."

    for collection in ${collections}; do
      if ansible-galaxy collection list | grep -q "${collection}"; then
        echo "✓ ${collection} is installed."
      else
        echo "✗ ${collection} is NOT installed."
      fi
    done
  else
    # Install collections
    installation_opts=""
    if [ ${force} -eq 1 ]; then
      installation_opts="--force"
    fi

    if [ ${verbose} -eq 1 ]; then
      installation_opts="${installation_opts} -v"
    fi

    echo "Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yaml "${installation_opts}"
    echo "Collections installed successfully."
  fi
}

# Function to test Ansible collections
function test_collections {
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v | --verbose)
        verbose=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage_test_collections
        exit 1
        ;;
    esac
  done

  # Check if requirements.yaml exists
  if [ ! -f "requirements.yaml" ]; then
    echo "Error: requirements.yaml file not found."
    exit 1
  fi

  echo "Testing Ansible collections from requirements.yaml..."

  # Extract collections from requirements.yaml
  collections=$(grep -A 100 "collections:" requirements.yaml | grep -B 100 -m 1 -e "^[a-z]*:" -e "^$" | grep "name:" | cut -d ':' -f 2 | sed 's/ //g')

  if [ -z "${collections}" ]; then
    echo "No collections found in requirements.yaml."
    exit 1
  fi

  # Test collections
  local all_installed=1
  local missing_collections=""

  for collection in ${collections}; do
    if ansible-galaxy collection list | grep -q "${collection}"; then
      if [ ${verbose} -eq 1 ]; then
        echo "✓ ${collection} is installed."
      fi
    else
      echo "✗ ${collection} is NOT installed."
      all_installed=0
      missing_collections="${missing_collections}\n  - ${collection}"
    fi
  done

  # Print summary
  echo ""
  if [ ${all_installed} -eq 1 ]; then
    echo "All required collections are installed."
    return 0
  else
    echo "Missing collections:${missing_collections}"
    echo ""
    echo "To install missing collections, run:"
    echo "  $0 install-collections"
    return 1
  fi
}

# Main command processing
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

case "${COMMAND}" in
  setup)
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_setup
      exit 0
    fi

    setup_dev_env "$@"
    ;;

  install-collections)
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_install_collections
      exit 0
    fi

    install_collections "$@"
    ;;

  test-collections)
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_test_collections
      exit 0
    fi

    test_collections "$@"
    ;;

  help)
    usage
    exit 0
    ;;

  *)
    echo "Unknown command: ${COMMAND}"
    usage
    exit 1
    ;;
esac
