#!/bin/bash
# Version: 1.0.0
# simple_validate_dependencies.sh - Simple validation of dependency version pinning
#
# Usage:
#   ./scripts/core/simple_validate_dependencies.sh [--fix] [--report]
#
# Options:
#   --fix       Attempt to automatically fix dependency version pinning issues
#   --report    Generate a detailed report of dependency version pinning
#
# Description:
#   A simplified version of validate_dependencies.sh that doesn't rely on external dependencies.
#   This script validates that all dependency version pinning across the project follows
#   the standardized format defined in the dependency management plan.

# Set default options
FIX_MODE=false
REPORT_MODE=false

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
    --help)
      echo "Usage: ./scripts/core/simple_validate_dependencies.sh [--fix] [--report]"
      echo ""
      echo "Options:"
      echo "  --fix       Attempt to automatically fix dependency version pinning issues"
      echo "  --report    Generate a detailed report of dependency version pinning"
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

# Configuration
WORKSPACE_ROOT="$(get_workspace_root)"
REPORT_FILE="${WORKSPACE_ROOT}/dependency_validation_report.md"
TMP_DIR="/tmp/dependency_validation"

# Ensure tmp directory exists
mkdir -p "${TMP_DIR}" 2>/dev/null || echo "Warning: Could not create temp directory"

# Find Python requirements files
echo "Finding Python requirements files..."
python_files=$(find "${WORKSPACE_ROOT}" -name "requirements.txt" -type f 2>/dev/null || echo "")
python_count=$(echo "${python_files}" | grep -v '^$' | wc -l | tr -d ' ')
echo "Found ${python_count} Python requirements files"

# Find Ansible requirements files
echo "Finding Ansible requirements files..."
ansible_files=$(find "${WORKSPACE_ROOT}" -name "requirements.yaml" -type f 2>/dev/null || echo "")
ansible_count=$(echo "${ansible_files}" | grep -v '^$' | wc -l | tr -d ' ')
echo "Found ${ansible_count} Ansible requirements files"

# Initialize counters
total_files=$((python_count + ansible_count))
passing_files=0
failing_files=0
python_issues=0
ansible_issues=0

# Check Python requirements files
echo "Checking Python requirements files..."
for file in ${python_files}; do
  if [ -f "${file}" ]; then
    echo "Checking ${file}"
    file_issues=0
    
    while IFS= read -r line; do
      # Skip empty lines and comments
      if [[ -z "${line}" || "${line}" =~ ^# ]]; then
        continue
      fi
      
      # Check if package has exact version pin (==)
      if [[ "${line}" =~ ^[a-zA-Z0-9_-]+ ]] && ! [[ "${line}" =~ ==|~= ]]; then
        file_issues=$((file_issues + 1))
        python_issues=$((python_issues + 1))
        package_name=$(echo "${line}" | grep -oE "^[a-zA-Z0-9_-]+")
        echo "  - Package '${package_name}' does not have proper version pinning"
        
        if [ "${FIX_MODE}" = true ]; then
          # Try to fix by replacing >= with ==
          if [[ "${line}" =~ ">=" ]]; then
            new_line=$(echo "${line}" | sed 's/>=/==/g')
            sed -i.bak "s#${line}#${new_line}#g" "${file}" 2>/dev/null
            if [ $? -eq 0 ]; then
              echo "    Fixed: ${line} -> ${new_line}"
            else
              echo "    Warning: Could not fix ${line}"
            fi
          fi
        fi
      fi
    done < "${file}"
    
    if [ ${file_issues} -gt 0 ]; then
      failing_files=$((failing_files + 1))
      echo "  Found ${file_issues} issues in ${file}"
    else
      passing_files=$((passing_files + 1))
      echo "  No issues found in ${file}"
    fi
  fi
done

# Check Ansible requirements files
echo "Checking Ansible requirements files..."
for file in ${ansible_files}; do
  if [ -f "${file}" ]; then
    echo "Checking ${file}"
    file_issues=0
    
    while IFS= read -r line; do
      # Check if it's a collection line with version
      if [[ "${line}" =~ "version:" ]]; then
        # Extract version constraint
        version_constraint=$(echo "${line}" | grep -oE '".*"' | tr -d '"')
        
        # Check if version constraint is exact (==) or bounded (>=x.y.z,<a.b.c)
        if ! [[ "${version_constraint}" =~ ^== || "${version_constraint}" =~ ^">=".+",<".+ ]]; then
          file_issues=$((file_issues + 1))
          ansible_issues=$((ansible_issues + 1))
          collection_name=$(grep -B 1 "${line}" "${file}" | grep "name:" | grep -oE '[^[:space:]]+$')
          echo "  - Collection '${collection_name}' does not have proper version pinning"
          
          if [ "${FIX_MODE}" = true ]; then
            # Try to fix by replacing >= with == for core collections
            if [[ "${version_constraint}" =~ ^">=" ]]; then
              version_number=$(echo "${version_constraint}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
              if [ -n "${version_number}" ]; then
                new_version="\"==${version_number}\""
                sed -i.bak "s/version: ${version_constraint}/version: ${new_version}/g" "${file}" 2>/dev/null
                if [ $? -eq 0 ]; then
                  echo "    Fixed: ${version_constraint} -> ${new_version}"
                else
                  echo "    Warning: Could not fix ${version_constraint}"
                fi
              fi
            fi
          fi
        fi
      fi
    done < "${file}"
    
    if [ ${file_issues} -gt 0 ]; then
      failing_files=$((failing_files + 1))
      echo "  Found ${file_issues} issues in ${file}"
    else
      passing_files=$((passing_files + 1))
      echo "  No issues found in ${file}"
    fi
  fi
done

# Generate report if requested
if [ "${REPORT_MODE}" = true ]; then
  echo "Generating report..."
  
  # Create report directory if it doesn't exist
  mkdir -p "$(dirname "${REPORT_FILE}")" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Warning: Could not create directory for report file. Using /tmp/dependency_validation_report.md"
    REPORT_FILE="/tmp/dependency_validation_report.md"
  fi
  
  # Generate report header
  cat > "${REPORT_FILE}" 2>/dev/null << EOF
# Dependency Validation Report

Generated on: $(date)

## Summary

- Total Python requirements files: ${python_count}
- Total Ansible requirements files: ${ansible_count}
- Files with issues: ${failing_files}
- Total issues found: $((python_issues + ansible_issues))
  - Python dependency issues: ${python_issues}
  - Ansible collection issues: ${ansible_issues}

## Recommendations

### Python Dependencies
- Core dependencies should use exact version pinning: \`package==1.2.3\`
- Development dependencies can use compatible release operator: \`package~=1.2.3\`
- All dependencies should have a version constraint

### Ansible Collections
- Core collections should use exact version pinning: \`version: "==1.2.3"\`
- Less critical collections can use bounded range: \`version: ">=1.2.3,<2.0.0"\`

To automatically fix these issues, run:
\`\`\`
./scripts/core/simple_validate_dependencies.sh --fix
\`\`\`
EOF

  if [ $? -eq 0 ]; then
    echo "Report generated: ${REPORT_FILE}"
  else
    echo "Error: Could not create report file."
  fi
fi

# Print summary
echo ""
echo "Validation complete:"
echo "  - Total files checked: ${total_files}"
echo "  - Passing files: ${passing_files}"
echo "  - Files with issues: ${failing_files}"
echo "  - Total issues found: $((python_issues + ansible_issues))"
echo "    - Python dependency issues: ${python_issues}"
echo "    - Ansible collection issues: ${ansible_issues}"

if [ ${failing_files} -gt 0 ]; then
  echo ""
  echo "To generate a detailed report, run with --report option."
  echo "To attempt automatic fixes, run with --fix option."
  exit 1
else
  echo ""
  echo "All dependency files follow the standardized version pinning format."
  exit 0
fi 