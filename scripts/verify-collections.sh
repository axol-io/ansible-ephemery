#!/usr/bin/env bash

# Script to verify that required Ansible collections are properly installed
# This script provides better path handling than simple find commands

set -e

# Determine the root of the repository
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Check if ANSIBLE_COLLECTIONS_PATH is set, use it if available
if [ -n "$ANSIBLE_COLLECTIONS_PATH" ]; then
  echo "Using ANSIBLE_COLLECTIONS_PATH from environment: $ANSIBLE_COLLECTIONS_PATH"
  COLLECTIONS_DIR="$ANSIBLE_COLLECTIONS_PATH"
else
  # Define collections directory
  COLLECTIONS_DIR="$REPO_ROOT/collections"
  echo "ANSIBLE_COLLECTIONS_PATH not set, using default: $COLLECTIONS_DIR"
fi

echo "Verifying collections at: $COLLECTIONS_DIR"

# Ensure collection directory exists
if [ ! -d "$COLLECTIONS_DIR" ]; then
  echo "Error: Collections directory $COLLECTIONS_DIR does not exist."
  echo "Has ansible-galaxy collection install been run?"
  exit 1
fi

# Array of required collections
required_collections=(
  "community/docker"
  "community/general"
  "ansible/netcommon"
  "ansible/utils"
)

missing_collections=0

for collection in "${required_collections[@]}"; do
  collection_path="$COLLECTIONS_DIR/ansible_collections/$collection"
  if [ -d "$collection_path" ]; then
    echo "✅ $collection installed at $collection_path"
  else
    echo "❌ $collection NOT found at $collection_path"
    missing_collections=$((missing_collections + 1))
  fi
done

# Display detailed directory listing for debugging
echo ""
echo "Detailed directory listing of collections:"
find "$COLLECTIONS_DIR" -type d -maxdepth 3 2>/dev/null | sort

# Verify specific collection (Docker) by checking for modules
if [ -d "$COLLECTIONS_DIR/ansible_collections/community/docker" ]; then
  echo ""
  echo "Docker collection contents:"
  find "$COLLECTIONS_DIR/ansible_collections/community/docker" -type f -name "*.py" | grep -v "__pycache__" | sort
fi

# Exit with appropriate status
if [ $missing_collections -eq 0 ]; then
  echo ""
  echo "All required collections are installed correctly."
  exit 0
else
  echo ""
  echo "Error: $missing_collections required collections are missing!"
  exit 1
fi
