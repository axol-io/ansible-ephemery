#!/bin/bash
# Version: 1.0.0
# yaml-extension-manager.sh - Consolidated script for YAML extension management
# Combines functionality from:
# - fix-yaml-extensions.sh
# - check-yaml-extensions.sh

set -e

function usage {
  echo "Usage: $0 [options]"
  echo "Manage YAML file extensions according to project conventions"
  echo
  echo "Options:"
  echo "  --check         Check for inconsistent YAML file extensions"
  echo "  --fix           Convert .yml to .yaml outside molecule/ directory"
  echo "  --reverse       Convert .yaml to .yml inside molecule/ directory"
  echo "  --dry-run       Show what would be changed without making changes"
  echo "  --help          Show this help message"
  echo
  echo "Project Convention:"
  echo "  - Use .yaml extension outside molecule/ directory"
  echo "  - Use .yml extension inside molecule/ directory"
}

MODE="check"
DRY_RUN=0

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --fix)
      MODE="fix"
      shift
      ;;
    --reverse)
      MODE="reverse"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Function to print action with color
print_action() {
  local action="$1"
  local file="$2"
  local details="$3"

  if [[ "${action}" == "RENAME" ]]; then
    echo -e "\033[33m${action}\033[0m: ${file} ${details}"
  elif [[ "${action}" == "ISSUE" ]]; then
    echo -e "\033[31m${action}\033[0m: ${file} ${details}"
  elif [[ "${action}" == "SKIP" ]]; then
    echo -e "\033[36m${action}\033[0m: ${file} ${details}"
  elif [[ "${action}" == "OK" ]]; then
    echo -e "\033[32m${action}\033[0m: ${file} ${details}"
  else
    echo "${action}: ${file} ${details}"
  fi
}

# Function to check YAML extensions
check_extensions() {
  local yml_outside_count=0
  local yaml_inside_count=0
  local total_files=0

  echo "Checking YAML file extensions..."

  # Check for .yml files outside molecule directory
  while IFS= read -r file; do
    if [[ ! "${file}" =~ ^./molecule/ && ! "${file}" =~ ^./collections/ && ! "${file}" =~ ^./.github/ ]]; then
      print_action "ISSUE" "${file}" "(should use .yaml extension)"
      yml_outside_count=$((yml_outside_count + 1))
    else
      print_action "OK" "${file}" "(correct extension for its location)"
    fi
    total_files=$((total_files + 1))
  done < <(find . -type f -name "*.yml" | sort)

  # Check for .yaml files inside molecule directory
  while IFS= read -r file; do
    if [[ "${file}" =~ ^./molecule/ ]]; then
      print_action "ISSUE" "${file}" "(should use .yml extension)"
      yaml_inside_count=$((yaml_inside_count + 1))
    else
      print_action "OK" "${file}" "(correct extension for its location)"
    fi
    total_files=$((total_files + 1))
  done < <(find . -type f -name "*.yaml" | sort)

  # Print summary
  echo ""
  echo "========================================="
  echo "YAML Extension Check Summary"
  echo "========================================="
  echo "Total YAML files: ${total_files}"
  echo "Issues found: $((yml_outside_count + yaml_inside_count))"
  echo "  - .yml files outside molecule/: ${yml_outside_count}"
  echo "  - .yaml files inside molecule/: ${yaml_inside_count}"
  echo ""

  if [[ ${yml_outside_count} -gt 0 || ${yaml_inside_count} -gt 0 ]]; then
    echo "To fix these issues, run:"
    if [[ ${yml_outside_count} -gt 0 ]]; then
      echo "  $0 --fix        # Convert .yml to .yaml outside molecule/"
    fi
    if [[ ${yaml_inside_count} -gt 0 ]]; then
      echo "  $0 --reverse    # Convert .yaml to .yml inside molecule/"
    fi
    return 1
  else
    echo "All YAML file extensions are consistent with the project convention."
    return 0
  fi
}

# Function to fix .yml to .yaml outside molecule
fix_extensions() {
  echo "Converting .yml to .yaml outside molecule/ and collections/ directories"
  local fixed_count=0
  local total_files=0

  # Find all .yml files outside molecule directory and collections directory
  while IFS= read -r file; do
    if [[ ! "${file}" =~ ^./molecule/ && ! "${file}" =~ ^./collections/ && ! "${file}" =~ ^./.github/ ]]; then
      new_file="${file%.yml}.yaml"
      total_files=$((total_files + 1))

      if [[ ${DRY_RUN} -eq 1 ]]; then
        print_action "RENAME" "${file}" "-> ${new_file}"
      else
        mv "${file}" "${new_file}"
        print_action "RENAME" "${file}" "-> ${new_file}"
      fi
      fixed_count=$((fixed_count + 1))
    else
      print_action "SKIP" "${file}" "(in excluded directory)"
    fi
  done < <(find . -type f -name "*.yml" | sort)

  # Print summary
  echo ""
  echo "========================================="
  echo "YAML Extension Fix Summary"
  echo "========================================="
  echo "Total .yml files processed: ${total_files}"
  echo "Files renamed: ${fixed_count}"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "No actual changes were made (dry run)"
  fi
  echo ""

  # Reminder about updating references
  if [[ ${fixed_count} -gt 0 ]]; then
    echo "Note: You may need to update references to these files in:"
    echo "- Playbooks"
    echo "- Include statements"
    echo "- Documentation"
    echo "- CI/CD configurations"
    echo ""
    echo "Run '$0 --check' to verify all extensions are now consistent."
  fi
}

# Function to fix .yaml to .yml inside molecule
fix_extensions_reverse() {
  echo "Converting .yaml to .yml in molecule/ directory"
  local fixed_count=0
  local total_files=0

  # Find all .yaml files in molecule directory
  while IFS= read -r file; do
    if [[ "${file}" =~ molecule/.*\.yaml$ ]]; then
      new_file="${file%.yaml}.yml"
      total_files=$((total_files + 1))

      if [[ ${DRY_RUN} -eq 1 ]]; then
        print_action "RENAME" "${file}" "-> ${new_file}"
      else
        mv "${file}" "${new_file}"
        print_action "RENAME" "${file}" "-> ${new_file}"
      fi
      fixed_count=$((fixed_count + 1))
    fi
  done < <(find molecule -type f -name "*.yaml" | sort)

  # Print summary
  echo ""
  echo "========================================="
  echo "YAML Extension Fix Summary (Reverse)"
  echo "========================================="
  echo "Total .yaml files processed in molecule/: ${total_files}"
  echo "Files renamed: ${fixed_count}"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "No actual changes were made (dry run)"
  fi
  echo ""

  # Reminder about updating references
  if [[ ${fixed_count} -gt 0 ]]; then
    echo "Note: You may need to update references to these files in:"
    echo "- Molecule configurations"
    echo "- Documentation"
    echo "- CI/CD configurations"
    echo ""
    echo "Run '$0 --check' to verify all extensions are now consistent."
  fi
}

# Execute selected mode
case "${MODE}" in
  check)
    check_extensions
    ;;
  fix)
    fix_extensions
    ;;
  reverse)
    fix_extensions_reverse
    ;;
esac
