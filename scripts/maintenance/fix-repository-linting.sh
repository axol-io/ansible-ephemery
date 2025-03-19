#!/usr/bin/env bash
# Version: 1.0.0
# =============================================================================
# fix-repository-linting.sh
# =============================================================================
# A comprehensive script to fix common linting issues in the repository:
# - Trailing whitespace
# - Missing end-of-file newlines
# - YAML file extensions (.yml -> .yaml)
# - Python formatting (using isort and black)
#
# Usage:
#   ./scripts/maintenance/fix-repository-linting.sh [--no-python-format]
#
# Options:
#   --no-python-format   Skip Python formatting (if isort/black aren't installed)
# =============================================================================

set -e

# Load common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${REPO_ROOT}/scripts/utilities/common.sh" ]]; then
  # shellcheck source=/dev/null
source "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"
fi

# Default configuration
SKIP_PYTHON_FORMAT=false
CHANGED_FILES=0

# Process command line arguments
for arg in "$@"; do
  case ${arg} in
    --no-python-format)
      SKIP_PYTHON_FORMAT=true
      shift
      ;;
    --help | -h)
      echo "Usage: $0 [--no-python-format]"
      echo ""
      echo "Options:"
      echo "  --no-python-format   Skip Python formatting (if isort/black aren't installed)"
      echo "  --help, -h           Show this help message"
      exit 0
      ;;
    *)
      # Unknown option
      shift
      ;;
  esac
done

# Print section headers
section() {
  echo ""
  echo "==================================================================="
  echo "$1"
  echo "==================================================================="
}

# Check that we're running from the repository root
if [[ ! -d .git ]]; then
  echo "Error: This script must be run from the repository root directory"
  echo "Current directory: $(pwd)"
  exit 1
fi

# Check for required commands
check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "Warning: $1 could not be found"
    return 1
  fi
  return 0
}

section "Checking for required commands"
FIND_AVAILABLE=true
SED_AVAILABLE=true
GIT_AVAILABLE=true
ISORT_AVAILABLE=true
BLACK_AVAILABLE=true

check_command find || FIND_AVAILABLE=false
check_command sed || SED_AVAILABLE=false
check_command git || GIT_AVAILABLE=false

if [[ "${SKIP_PYTHON_FORMAT}" == "false" ]]; then
  check_command isort || ISORT_AVAILABLE=false
  check_command black || BLACK_AVAILABLE=false

  if [[ "${ISORT_AVAILABLE}" == "false" || "${BLACK_AVAILABLE}" == "false" ]]; then
    echo "Warning: Python formatting tools are not available. Skipping Python formatting."
    echo "You can install them with: pip install isort black"
    SKIP_PYTHON_FORMAT=true
  fi
fi

if [[ "${FIND_AVAILABLE}" == "false" || "${SED_AVAILABLE}" == "false" || "${GIT_AVAILABLE}" == "false" ]]; then
  echo "Error: Basic tools (find, sed, git) are required to run this script"
  exit 1
fi

# Detect platform-specific sed behavior
section "Configuring for your platform"
if [[ "$(uname)" == "Darwin" ]]; then
  echo "Detected macOS, adjusting sed commands"
  SED_IN_PLACE="sed -i ''"
  SED_EXT="-E"
else
  echo "Detected Linux or other system, using standard sed behavior"
  SED_IN_PLACE="sed -i"
  SED_EXT="-r"
fi

# Fix trailing whitespace
section "Fixing trailing whitespace"
echo "Finding files with trailing whitespace..."
if [[ -n "$(find . -type f -not -path "*/\.*" -not -path "*/\.git/*" -not -path "*/node_modules/*" -exec grep -l "[[:space:]]$" {} \;)" ]]; then
  find . -type f -not -path "*/\.*" -not -path "*/\.git/*" -not -path "*/node_modules/*" -exec grep -l "[[:space:]]$" {} \; \
    | while read -r file; do
      echo "Fixing trailing whitespace in ${file}"
      ${SED_IN_PLACE} "s/[[:space:]]*$//" "${file}"
      CHANGED_FILES=$((CHANGED_FILES + 1))
    done
else
  echo "No files with trailing whitespace found"
fi

# Fix end of file newlines
section "Fixing end of file newlines"
echo "Finding files without end-of-file newlines..."
# This is more complex - we need to check the last character of each file
find . -type f -not -path "*/\.*" -not -path "*/\.git/*" -not -path "*/node_modules/*" -not -path "*/\.DS_Store" \
  | while read -r file; do
    if [[ -s "${file}" ]]; then # Only for non-empty files
      if [[ "$(tail -c 1 "${file}" | xxd -p)" != "0a" ]]; then
        echo "Fixing end-of-file newline in ${file}"
        echo "" >>"${file}"
        CHANGED_FILES=$((CHANGED_FILES + 1))
      fi
    fi
  done

# Fix YAML file extensions
section "Fixing YAML file extensions (.yml -> .yaml)"
echo "Finding YAML files with .yml extension..."
find . -name "*.yml" -type f -not -path "*/\.*" -not -path "*/\.git/*" -not -path "*/node_modules/*" \
  | while read -r file; do
    new_file="${file%.yml}.yaml"
    if [[ -f "${new_file}" ]]; then
      echo "Warning: Cannot rename ${file} to ${new_file} - file already exists"
    else
      echo "Renaming ${file} to ${new_file}"
      git mv "${file}" "${new_file}" || mv "${file}" "${new_file}"
      CHANGED_FILES=$((CHANGED_FILES + 1))
    fi
  done

# Format Python files
if [[ "${SKIP_PYTHON_FORMAT}" == "false" ]]; then
  section "Formatting Python files"
  echo "Finding Python files..."
  python_files=$(find . -name "*.py" -type f -not -path "*/\.*" -not -path "*/\.git/*" -not -path "*/node_modules/*" -not -path "*/venv/*")

  if [[ -n "${python_files}" ]]; then
    echo "Running isort on Python files..."
    echo "${python_files}" | xargs isort

    echo "Running black on Python files..."
    echo "${python_files}" | xargs black

    CHANGED_FILES=$((CHANGED_FILES + 1))
  else
    echo "No Python files found"
  fi
fi

# Report results
section "Summary"
echo "Fixed ${CHANGED_FILES} files."

if [[ "${CHANGED_FILES}" -gt 0 ]]; then
  echo ""
  echo "To commit these changes:"
  echo "  git add ."
  echo "  git commit -m 'Fix linting issues across repository'"
fi

echo ""
echo "Script completed successfully!"
