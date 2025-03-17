#!/bin/bash
# Version: 1.0.0

# Shell Script Version Validator
# This script checks that shell scripts have a consistent version pattern
# and helps enforce standardized versioning across the codebase

# Exit on any error
set -e

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Version pattern to look for
VERSION_PATTERN="# Version: [0-9]+\.[0-9]+\.[0-9]+"

# Files to check - either from arguments or defaulting to all shell scripts
if [ $# -gt 0 ]; then
  FILES_TO_CHECK=("$@")
else
  # Find all shell scripts in the project
  mapfile -t FILES_TO_CHECK < <(find . -type f -name "*.sh" -not -path "*/\.*" -not -path "*/collections/*")
fi

echo -e "${YELLOW}Checking version strings in shell scripts...${NC}"

# Initialize counters
SCRIPTS_CHECKED=0
SCRIPTS_MISSING_VERSION=0
SCRIPTS_WITH_VERSION=0

# Process each file
for file in "${FILES_TO_CHECK[@]}"; do
  SCRIPTS_CHECKED=$((SCRIPTS_CHECKED + 1))

  # Check if file exists and is readable
  if [ ! -r "${file}" ]; then
    echo -e "${RED}Error: Cannot read file ${file}${NC}"
    continue
  fi

  # Look for version string in first 20 lines
  if head -n 20 "${file}" | grep -q -E "${VERSION_PATTERN}"; then
    VERSION=$(head -n 20 "${file}" | grep -E "${VERSION_PATTERN}" | sed -E 's/.*Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    echo -e "${GREEN}✓ ${file}${NC} - Version: ${VERSION}"
    SCRIPTS_WITH_VERSION=$((SCRIPTS_WITH_VERSION + 1))
  else
    echo -e "${RED}✗ ${file}${NC} - No version string found (expected pattern: '# Version: X.Y.Z')"
    SCRIPTS_MISSING_VERSION=$((SCRIPTS_MISSING_VERSION + 1))
  fi
done

# Print summary
echo
echo -e "${YELLOW}Summary:${NC}"
echo "Scripts checked: ${SCRIPTS_CHECKED}"
echo "Scripts with version: ${SCRIPTS_WITH_VERSION}"
echo "Scripts missing version: ${SCRIPTS_MISSING_VERSION}"

# Determine exit code
if [ ${SCRIPTS_MISSING_VERSION} -gt 0 ]; then
  echo -e "${RED}Error: ${SCRIPTS_MISSING_VERSION} script(s) are missing proper version strings${NC}"
  echo "Please add a version string in the format '# Version: X.Y.Z' to each script header"
  exit 1
else
  echo -e "${GREEN}All scripts have proper version strings!${NC}"
  exit 0
fi
