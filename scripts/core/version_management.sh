#!/bin/bash

# Ephemery Version Management Script
# This script provides standardized version tracking for all Ephemery scripts
# Version: 1.0.0

# Prevent sourcing more than once
[[ -n "${_EPHEMERY_VERSION_MANAGEMENT_LOADED}" ]] && return 0
readonly _EPHEMERY_VERSION_MANAGEMENT_LOADED=1

# Source path configuration if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if [[ -z "${_EPHEMERY_PATH_CONFIG_LOADED}" && -f "${SCRIPT_DIR}/path_config.sh" ]]; then
  source "${SCRIPT_DIR}/path_config.sh"
fi

# Ephemery version
EPHEMERY_VERSION="1.2.0"

# Dependency versions - centralized to ensure consistency
declare -A EPHEMERY_DEPENDENCY_VERSIONS=(
  # Container client tools
  [DOCKER]="24.0.0"
  [DOCKER_COMPOSE]="2.24.0"
  
  # Ethereum client versions
  [GETH]="1.13.14"
  [LIGHTHOUSE]="4.5.0"
  [PRYSM]="4.1.1"
  [TEKU]="24.3.0"
  [NETHERMIND]="1.25.0"
  [ERIGON]="2.57.0"
  
  # Utility tools
  [TMUX]="3.3"
  [JQ]="1.6"
  [YQ]="4.35.1"
  [OPENSSL]="1.1.1"
  [GPG]="2.2.0"
  [CURL]="7.88.1"
  [WGET]="1.21.0"
  [RSYNC]="3.2.7"
  [GIT]="2.41.0"
  
  # Python dependencies
  [PYTHON]="3.10.0"
  [PIP]="23.0.0"
  [ANSIBLE]="8.1.0"
  
  # Shell tools
  [SHELLCHECK]="0.9.0"
  [SHFMT]="3.7.0"
)

# Function to check if a tool is at least the minimum required version
# Usage: check_version "docker" "${EPHEMERY_DEPENDENCY_VERSIONS[DOCKER]}"
check_version() {
  local tool_name="$1"
  local min_version="$2"
  local actual_version=""
  
  case "$tool_name" in
    docker)
      actual_version=$(docker --version | sed -n 's/Docker version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    docker-compose)
      actual_version=$(docker-compose --version | sed -n 's/.*version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    tmux)
      actual_version=$(tmux -V | sed -n 's/tmux \([0-9]*\.[0-9]*\).*/\1/p')
      ;;
    jq)
      actual_version=$(jq --version | sed -n 's/jq-\([0-9]*\.[0-9]*\).*/\1/p')
      ;;
    yq)
      actual_version=$(yq --version | sed -n 's/.*version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    openssl)
      actual_version=$(openssl version | sed -n 's/OpenSSL \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    gpg)
      actual_version=$(gpg --version | head -n1 | sed -n 's/gpg (GnuPG) \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    curl)
      actual_version=$(curl --version | head -n1 | sed -n 's/curl \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    wget)
      actual_version=$(wget --version | head -n1 | sed -n 's/GNU Wget \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    rsync)
      actual_version=$(rsync --version | head -n1 | sed -n 's/rsync *version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    git)
      actual_version=$(git --version | sed -n 's/git version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    python)
      actual_version=$(python3 --version 2>&1 | sed -n 's/Python \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    pip)
      actual_version=$(pip3 --version | sed -n 's/pip \([0-9]*\.[0-9]*\).*/\1/p')
      ;;
    ansible)
      actual_version=$(ansible --version | head -n1 | sed -n 's/ansible \[core \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    shellcheck)
      actual_version=$(shellcheck --version | sed -n 's/version: \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
      ;;
    shfmt)
      actual_version=$(shfmt --version)
      ;;
    *)
      echo "Unknown tool: $tool_name"
      return 1
      ;;
  esac
  
  if [ -z "$actual_version" ]; then
    echo "Could not determine version of $tool_name"
    return 1
  fi
  
  # Compare versions
  version_greater_equal "$actual_version" "$min_version"
  return $?
}

# Helper function to compare versions
version_greater_equal() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
  return $?
}

# Helper function to check if a tool is installed
is_installed() {
  command -v "$1" &> /dev/null
  return $?
}

# Function to check all required dependencies for a given script
# Usage: check_dependencies "tmux jq docker"
check_dependencies() {
  local required_tools="$1"
  local missing_deps=false
  
  for tool in $required_tools; do
    if ! is_installed "$tool"; then
      echo "Error: $tool is not installed. Please install $tool v${EPHEMERY_DEPENDENCY_VERSIONS[${tool^^}]} or later."
      missing_deps=true
    else
      if check_version "$tool" "${EPHEMERY_DEPENDENCY_VERSIONS[${tool^^}]}"; then
        echo "✓ $tool is installed with an acceptable version"
      else
        echo "Warning: $tool is installed but may be outdated. Recommended version: ${EPHEMERY_DEPENDENCY_VERSIONS[${tool^^}]} or later."
      fi
    fi
  done
  
  if [ "$missing_deps" = true ]; then
    echo "Missing required dependencies. Please install them and try again."
    return 1
  fi
  
  return 0
} 