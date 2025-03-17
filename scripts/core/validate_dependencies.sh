#!/bin/bash
# Version: 1.0.0
# validate_dependencies.sh - Validates dependency version pinning across the project
#
# Usage:
#   ./scripts/core/validate_dependencies.sh [--fix] [--report] [--verbose]
#
# Options:
#   --fix       Attempt to automatically fix dependency version pinning issues
#   --report    Generate a detailed report of dependency version pinning
#   --verbose   Show detailed output during validation
#
# Description:
#   This script validates that all dependency version pinning across the project
#   follows the standardized format defined in the dependency management plan.
#   It checks both Python requirements.txt files and Ansible requirements.yaml files.

# Source common functions and path configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Source with error handling in case files don't exist
source "${SCRIPT_DIR}/error_handling.sh" 2>/dev/null || echo "Warning: error_handling.sh not found"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || echo "Warning: common.sh not found"
source "${SCRIPT_DIR}/path_config.sh" 2>/dev/null || echo "Warning: path_config.sh not found"

# Set default options
FIX_MODE=false
REPORT_MODE=false
VERBOSE_MODE=false

# Parse command line arguments
for arg in "$@"; do
  case ${arg} in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --report)
      REPORT_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE_MODE=true
      shift
      ;;
    --help)
      echo "Usage: ./scripts/core/validate_dependencies.sh [--fix] [--report] [--verbose]"
      echo ""
      echo "Options:"
      echo "  --fix       Attempt to automatically fix dependency version pinning issues"
      echo "  --report    Generate a detailed report of dependency version pinning"
      echo "  --verbose   Show detailed output during validation"
      exit 0
      ;;
    *)
      # Unknown option
      echo "Unknown option: ${arg}"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

# Function to get workspace root directory - define locally to avoid dependency
get_workspace_root() {
  git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)"
}

# Function to print verbose messages
echo_verbose() {
  if [ "${VERBOSE_MODE}" = true ]; then
    echo "$@"
  fi
}

# Configuration
WORKSPACE_ROOT="$(get_workspace_root)"
REPORT_FILE="${WORKSPACE_ROOT}/dependency_validation_report.md"
TMP_DIR="/tmp/dependency_validation"

# Ensure tmp directory exists
mkdir -p "${TMP_DIR}" 2>/dev/null || echo "Warning: Could not create temp directory"

# Find all requirements files
find_requirements_files() {
  echo_verbose "Finding requirements files..."

  # Find Python requirements
  python_files=$(find "${WORKSPACE_ROOT}" -name "requirements.txt" -type f 2>/dev/null || echo "")

  # Find Ansible requirements
  ansible_files=$(find "${WORKSPACE_ROOT}" -name "requirements.yaml" -type f 2>/dev/null || echo "")

  # Return both lists
  echo "${python_files}"
  echo "${ansible_files}"
}

# Function to check Python requirements file
check_python_requirements() {
  local file="$1"
  local issues=0
  local issues_list=""

  echo_verbose "Checking Python requirements file: ${file}"

  # Read the file line by line
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "${line}" || "${line}" =~ ^# ]]; then
      continue
    fi

    # Check if package has exact version pin (==)
    if [[ "${line}" =~ ^[a-zA-Z0-9_-]+ ]] && ! [[ "${line}" =~ ==|~= ]]; then
      issues=$((issues + 1))
      package_name=$(echo "${line}" | grep -oE "^[a-zA-Z0-9_-]+")
      issues_list="${issues_list}  - Package '${package_name}' does not have proper version pinning\n"

      if [ "${FIX_MODE}" = true ]; then
        # Try to fix by replacing >= with ==
        if [[ "${line}" =~ ">=" ]]; then
          new_line=$(echo "${line}" | sed 's/>=/==/g')
          sed -i "s#${line}#${new_line}#g" "${file}" 2>/dev/null || echo "Warning: Could not modify file ${file}"
          echo_verbose "  Fixed: ${line} -> ${new_line}"
        fi
      fi
    fi
  done <"${file}"

  # Return results
  if [ ${issues} -gt 0 ]; then
    echo "Found ${issues} issues in ${file}:"
    echo -e "${issues_list}"
    return 1
  else
    echo_verbose "No issues found in ${file}"
    return 0
  fi
}

# Function to check Ansible requirements file
check_ansible_requirements() {
  local file="$1"
  local issues=0
  local issues_list=""

  echo_verbose "Checking Ansible requirements file: ${file}"

  # Simple YAML parsing for requirements.yaml
  while IFS= read -r line; do
    # Check if it's a collection line with version
    if [[ "${line}" =~ "version:" ]]; then
      # Extract version constraint
      version_constraint=$(echo "${line}" | grep -oE '".*"' | tr -d '"')

      # Check if version constraint is exact (==) or bounded (>=x.y.z,<a.b.c)
      if ! [[ "${version_constraint}" =~ ^== || "${version_constraint}" =~ ^">=".+",<".+ ]]; then
        issues=$((issues + 1))
        collection_name=$(grep -B 1 "${line}" "${file}" | grep "name:" | grep -oE '[^[:space:]]+$')
        issues_list="${issues_list}  - Collection '${collection_name}' does not have proper version pinning\n"

        if [ "${FIX_MODE}" = true ]; then
          # Try to fix by replacing >= with == for core collections
          if [[ "${version_constraint}" =~ ^">=" ]]; then
            version_number=$(echo "${version_constraint}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
            if [ -n "${version_number}" ]; then
              new_version="\"==${version_number}\""
              sed -i "s/version: ${version_constraint}/version: ${new_version}/g" "${file}" 2>/dev/null || echo "Warning: Could not modify file ${file}"
              echo_verbose "  Fixed: ${version_constraint} -> ${new_version}"
            fi
          fi
        fi
      fi
    fi
  done <"${file}"

  # Return results
  if [ ${issues} -gt 0 ]; then
    echo "Found ${issues} issues in ${file}:"
    echo -e "${issues_list}"
    return 1
  else
    echo_verbose "No issues found in ${file}"
    return 0
  fi
}

# Function to generate a detailed report
generate_report() {
  local requirements_files=()
  local python_files=()
  local ansible_files=()

  # Convert to array without using readarray (for sh compatibility)
  while IFS= read -r file; do
    if [ -n "${file}" ]; then
      requirements_files+=("${file}")

      # Categorize files
      if [[ "${file}" == *requirements.yaml ]]; then
        ansible_files+=("${file}")
      else
        python_files+=("${file}")
      fi
    fi
  done < <(find_requirements_files)

  # Create report directory
  mkdir -p "$(dirname "${REPORT_FILE}")" 2>/dev/null || {
    echo "Error: Cannot create directory for report file. Using temporary file."
    REPORT_FILE="${TMP_DIR}/dependency_validation_report.md"
  }

  # Generate report header
  cat >"${REPORT_FILE}" 2>/dev/null || {
    echo "Error: Cannot write to report file. Printing to console instead."
    echo "# Dependency Validation Report"
    echo
    echo "Generated on: $(date)"
    echo
    echo "## Summary"
    echo
    echo "- Total Python requirements files: ${#python_files[@]}"
    echo "- Total Ansible requirements files: ${#ansible_files[@]}"
    return 1
  }

  echo "# Dependency Validation Report" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "Generated on: $(date)" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "## Summary" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "- Total Python requirements files: ${#python_files[@]}" >>"${REPORT_FILE}"
  echo "- Total Ansible requirements files: ${#ansible_files[@]}" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "## Python Requirements" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "| File | Status | Issues |" >>"${REPORT_FILE}"
  echo "|------|--------|--------|" >>"${REPORT_FILE}"

  # Add Python requirements files to report
  for file in "${python_files[@]}"; do
    rel_path=$(realpath --relative-to="${WORKSPACE_ROOT}" "${file}" 2>/dev/null || echo "${file}")
    issues=$(check_python_requirements "${file}" 2>&1 | grep -v "Checking" || true)

    if [ -z "${issues}" ]; then
      status="✅ Compliant"
      issues="None"
    else
      status="❌ Non-compliant"
      issues=$(echo "${issues}" | tr '\n' ' ' | sed 's/Found [0-9]* issues in.*//')
    fi

    echo "| \`${rel_path}\` | ${status} | ${issues} |" >>"${REPORT_FILE}"
  done

  # Add Ansible requirements section
  echo >>"${REPORT_FILE}"
  echo "## Ansible Requirements" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "| File | Status | Issues |" >>"${REPORT_FILE}"
  echo "|------|--------|--------|" >>"${REPORT_FILE}"

  # Add Ansible requirements files to report
  for file in "${ansible_files[@]}"; do
    rel_path=$(realpath --relative-to="${WORKSPACE_ROOT}" "${file}" 2>/dev/null || echo "${file}")
    issues=$(check_ansible_requirements "${file}" 2>&1 | grep -v "Checking" || true)

    if [ -z "${issues}" ]; then
      status="✅ Compliant"
      issues="None"
    else
      status="❌ Non-compliant"
      issues=$(echo "${issues}" | tr '\n' ' ' | sed 's/Found [0-9]* issues in.*//')
    fi

    echo "| \`${rel_path}\` | ${status} | ${issues} |" >>"${REPORT_FILE}"
  done

  # Add recommendations section
  echo >>"${REPORT_FILE}"
  echo "## Recommendations" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "### Python Dependencies" >>"${REPORT_FILE}"
  echo "- Core dependencies should use exact version pinning: \`package==1.2.3\`" >>"${REPORT_FILE}"
  echo "- Development dependencies can use compatible release operator: \`package~=1.2.3\`" >>"${REPORT_FILE}"
  echo "- All dependencies should have a version constraint" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "### Ansible Collections" >>"${REPORT_FILE}"
  echo "- Core collections should use exact version pinning: \`version: \"==1.2.3\"\`" >>"${REPORT_FILE}"
  echo "- Less critical collections can use bounded range: \`version: \">=1.2.3,<2.0.0\"\`" >>"${REPORT_FILE}"
  echo >>"${REPORT_FILE}"
  echo "To automatically fix these issues, run:" >>"${REPORT_FILE}"
  echo "\`\`\`" >>"${REPORT_FILE}"
  echo "./scripts/core/validate_dependencies.sh --fix" >>"${REPORT_FILE}"
  echo "\`\`\`" >>"${REPORT_FILE}"

  echo "Report generated: ${REPORT_FILE}"
}

# Main function
main() {
  echo "Validating dependency version pinning..."

  if [ "${REPORT_MODE}" = true ]; then
    generate_report
    exit 0
  fi

  # Initialize counters
  total_files=0
  passing_files=0
  failing_files=0

  # Process each requirements file
  # Without using readarray (for sh compatibility)
  while IFS= read -r file; do
    if [ -n "${file}" ]; then
      total_files=$((total_files + 1))

      if [[ "${file}" == *requirements.yaml ]]; then
        if check_ansible_requirements "${file}"; then
          passing_files=$((passing_files + 1))
        else
          failing_files=$((failing_files + 1))
        fi
      else
        if check_python_requirements "${file}"; then
          passing_files=$((passing_files + 1))
        else
          failing_files=$((failing_files + 1))
        fi
      fi
    fi
  done < <(find_requirements_files)

  # Print summary
  echo ""
  echo "Validation complete:"
  echo "  - Total files checked: ${total_files}"
  echo "  - Passing files: ${passing_files}"
  echo "  - Files with issues: ${failing_files}"

  if [ ${failing_files} -gt 0 ]; then
    echo ""
    echo "To see detailed information, run with --report option."
    echo "To attempt automatic fixes, run with --fix option."
    exit 1
  else
    echo ""
    echo "All dependency files follow the standardized version pinning format."
    exit 0
  fi
}

# Execute main function
main "$@"
