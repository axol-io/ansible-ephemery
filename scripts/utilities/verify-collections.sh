#!/usr/bin/env bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0

# Script to verify that required Ansible collections are properly installed
# This script provides better path handling than simple find commands

set -e

# Determine the root of the repository
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Check if ANSIBLE_COLLECTIONS_PATH is set, use it if available
if [ -n "${ANSIBLE_COLLECTIONS_PATH}" ]; then
  # Check if the path contains a $ character (unexpanded variable)
  if [[ "${ANSIBLE_COLLECTIONS_PATH}" == *"$"* ]]; then
    echo "WARNING: ANSIBLE_COLLECTIONS_PATH contains unexpanded variables: ${ANSIBLE_COLLECTIONS_PATH}"
    echo "This usually means GitHub Actions didn't expand the shell variables."
    echo "Defaulting to repository-local collections directory instead."
    COLLECTIONS_DIR="${REPO_ROOT}/collections"
  else
    echo "Using ANSIBLE_COLLECTIONS_PATH from environment: ${ANSIBLE_COLLECTIONS_PATH}"
    COLLECTIONS_DIR="${ANSIBLE_COLLECTIONS_PATH}"
  fi
else
  # Define collections directory
  COLLECTIONS_DIR="${REPO_ROOT}/collections"
  echo "ANSIBLE_COLLECTIONS_PATH not set, using default: ${COLLECTIONS_DIR}"
fi

echo "Verifying collections at: ${COLLECTIONS_DIR}"

# Ensure collection directory exists
if [ ! -d "${COLLECTIONS_DIR}" ]; then
  echo "Error: Collections directory ${COLLECTIONS_DIR} does not exist."
  echo "This could be because:"
  echo "  1. ansible-galaxy collection install has not been run yet"
  echo "  2. The ANSIBLE_COLLECTIONS_PATH environment variable points to an invalid location"
  echo "  3. A shell variable like \$PWD was not expanded in GitHub Actions"
  echo ""
  echo "Current directory is: $(pwd)"
  echo "Collections should be in: ${REPO_ROOT}/collections"

  # Check if there are collections in the repository root
  if [ -d "${REPO_ROOT}/collections" ]; then
    echo "Found collections directory at repository root, using that instead."
    COLLECTIONS_DIR="${REPO_ROOT}/collections"
  else
    exit 1
  fi
fi

# Check for potential conflicting collections in system paths
SYSTEM_COLLECTIONS_PATH="/opt/hostedtoolcache/Python/3.10.16/x64/lib/python3.10/site-packages/ansible_collections"
if [ -d "${SYSTEM_COLLECTIONS_PATH}" ]; then
  echo "⚠️ WARNING: System-wide collections found at ${SYSTEM_COLLECTIONS_PATH}"
  echo "This may conflict with local collections and cause issues."
  echo "Consider setting ANSIBLE_COLLECTIONS_SCAN_SYS_PATH=false to ignore system collections."

  # Check if any of our required collections exist in system path
  for collection in "${required_collections[@]}"; do
    # Fix shellcheck warning SC2206 by using read for robust word splitting
    IFS='/' read -r namespace name <<<"${collection}"

    if [ -d "${SYSTEM_COLLECTIONS_PATH}/${namespace}/${name}" ]; then
      echo "⚠️ CONFLICT: ${namespace}.${name} exists in system path and may conflict with local collection"
    fi
  done
fi

# Array of required collections
required_collections=(
  "community/docker"
  "community/general"
  "ansible/netcommon"
  "ansible/utils"
  "ansible/posix"
)

missing_collections=0

for collection in "${required_collections[@]}"; do
  collection_path="${COLLECTIONS_DIR}/ansible_collections/${collection}"
  if [ -d "${collection_path}" ]; then
    echo "✅ ${collection} installed at ${collection_path}"
  else
    echo "❌ ${collection} NOT found at ${collection_path}"
    missing_collections=$((missing_collections + 1))
  fi
done

# Display detailed directory listing for debugging
echo ""
echo "Detailed directory listing of collections:"
find "${COLLECTIONS_DIR}" -type d -maxdepth 3 2>/dev/null | sort

# Verify specific collection (Docker) by checking for modules
if [ -d "${COLLECTIONS_DIR}/ansible_collections/community/docker" ]; then
  echo ""
  echo "Docker collection contents:"
  find "${COLLECTIONS_DIR}/ansible_collections/community/docker" -type f -name "*.py" | grep -v "__pycache__" | sort
fi

# Exit with appropriate status
if [ ${missing_collections} -eq 0 ]; then
  echo ""
  echo "All required collections are installed correctly."

  # Final environment recommendation
  echo ""
  echo "Recommended environment variables for consistent collection loading:"
  echo "export ANSIBLE_COLLECTIONS_PATH=${COLLECTIONS_DIR}"
  echo "export ANSIBLE_COLLECTIONS_SCAN_SYS_PATH=false"
  exit 0
else
  echo ""
  echo "Error: ${missing_collections} required collections are missing!"
  exit 1
fi
