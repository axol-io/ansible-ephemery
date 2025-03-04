#!/bin/bash
# validator.sh - Consolidated script for validation tasks
# Combines functionality from:
# - validate_docs.sh
# - validate_variables.sh
# - verify-ansible-conditionals.sh

set -e

# Print main usage information
function usage {
  echo "Usage: $0 <command> [options]"
  echo
  echo "Commands:"
  echo "  docs                 Validate documentation completeness and correctness"
  echo "  vars                 Validate variable definitions and usage"
  echo "  conditionals         Verify Ansible conditional statements"
  echo "  all                  Run all validation checks"
  echo "  help                 Show this help message"
  echo
  echo "Options vary by command. Use '$0 <command> --help' for command-specific help."
}

# Print docs validation usage
function usage_docs {
  echo "Usage: $0 docs [options]"
  echo
  echo "Validate documentation completeness and correctness."
  echo
  echo "Options:"
  echo "  --fix            Attempt to fix common documentation issues"
  echo "  --verbose        Show detailed validation results"
  echo "  --help           Show this help message"
}

# Print vars validation usage
function usage_vars {
  echo "Usage: $0 vars [options]"
  echo
  echo "Validate variable definitions and usage."
  echo
  echo "Options:"
  echo "  --only-undefined Check only for undefined variables"
  echo "  --only-unused    Check only for unused variables"
  echo "  --verbose        Show detailed validation results"
  echo "  --help           Show this help message"
}

# Print conditionals validation usage
function usage_conditionals {
  echo "Usage: $0 conditionals [options]"
  echo
  echo "Verify Ansible conditional statements."
  echo
  echo "Options:"
  echo "  --fix            Attempt to fix common conditional issues"
  echo "  --verbose        Show detailed validation results"
  echo "  --help           Show this help message"
}

# Function to validate documentation
function validate_docs {
  local fix=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)
        fix=1
        shift
        ;;
      --verbose)
        verbose=1
        shift
        ;;
      --help)
        usage_docs
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_docs
        exit 1
        ;;
    esac
  done

  echo "Validating documentation..."

  # Check if docs directory exists
  if [ ! -d "docs" ]; then
    echo "Error: docs directory not found."
    exit 1
  fi

  # Track stats
  local errors=0
  local warnings=0
  local fixed=0

  # Check for README.md
  if [ ! -f "README.md" ]; then
    echo "ERROR: Main README.md is missing."
    errors=$((errors + 1))
  else
    # Check README.md content
    if ! grep -q "# ansible-ephemery" README.md; then
      echo "WARNING: README.md does not have proper title."
      warnings=$((warnings + 1))

      if [ "$fix" -eq 1 ]; then
        sed -i '1s/^/# ansible-ephemery\n\n/' README.md
        echo "FIXED: Added title to README.md."
        fixed=$((fixed + 1))
      fi
    fi

    # Check for Quick Start section
    if ! grep -q "## Quick Start" README.md; then
      echo "WARNING: README.md does not have Quick Start section."
      warnings=$((warnings + 1))
    fi
  fi

  # Check for required docs files
  required_docs=(
    "CLIENT_COMBINATIONS.md"
    "REPOSITORY_STRUCTURE.md"
    "TESTING.md"
    "SECURITY.md"
    "VARIABLE_STRUCTURE.md"
  )

  for doc in "${required_docs[@]}"; do
    if [ ! -f "docs/$doc" ]; then
      echo "ERROR: docs/$doc is missing."
      errors=$((errors + 1))
    elif [ "$verbose" -eq 1 ]; then
      echo "OK: docs/$doc exists."
    fi
  done

  # Check for broken links in documentation
  echo "Checking for broken links in documentation..."

  # Find all markdown files
  markdown_files=$(find . -name "*.md")

  for file in $markdown_files; do
    # Extract links to other markdown files
    links=$(grep -o -E '\[.*\]\((.*\.md)\)' "$file" | sed -E 's/.*\((.*)\)/\1/')

    for link in $links; do
      # Handle relative links
      if [[ "$link" =~ ^[^/] ]]; then
        # Get directory of current file
        dir=$(dirname "$file")
        link_path="$dir/$link"
      else
        # Absolute path relative to repo root
        link_path=".$link"
      fi

      # Check if linked file exists
      if [ ! -f "$link_path" ]; then
        echo "ERROR: Broken link in $file: $link"
        errors=$((errors + 1))
      elif [ "$verbose" -eq 1 ]; then
        echo "OK: Link in $file to $link is valid."
      fi
    done
  done

  # Print summary
  echo ""
  echo "Documentation Validation Summary:"
  echo "------------------------------"
  echo "Errors: $errors"
  echo "Warnings: $warnings"

  if [ "$fix" -eq 1 ]; then
    echo "Issues fixed: $fixed"
  fi

  if [ $errors -eq 0 ]; then
    if [ $warnings -eq 0 ]; then
      echo "✓ Documentation is valid."
      return 0
    else
      echo "⚠ Documentation has warnings but no errors."
      return 0
    fi
  else
    echo "✗ Documentation has errors that need to be fixed."
    return 1
  fi
}

# Function to validate variables
function validate_vars {
  local only_undefined=0
  local only_unused=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only-undefined)
        only_undefined=1
        shift
        ;;
      --only-unused)
        only_unused=1
        shift
        ;;
      --verbose)
        verbose=1
        shift
        ;;
      --help)
        usage_vars
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_vars
        exit 1
        ;;
    esac
  done

  echo "Validating variables..."

  # Check if defaults and vars directories exist
  if [ ! -d "defaults" ] && [ ! -d "vars" ]; then
    echo "Error: Neither defaults nor vars directory found."
    exit 1
  fi

  # Track stats
  local undefined_vars=0
  local unused_vars=0

  # Check for undefined variables if not skipped
  if [ "$only_unused" -eq 0 ]; then
    echo "Checking for undefined variables..."

    # Find all YAML/YML files excluding defaults/ and vars/
    yaml_files=$(find . -name "*.yaml" -o -name "*.yml" | grep -v "^./defaults/" | grep -v "^./vars/" | grep -v "^./\.")

    # Extract variables used in templates ({{ var_name }})
    for file in $yaml_files; do
      # Extract variables from {{ var_name }} and when: var_name is defined
      vars=$(grep -o -E '\{\{[^}]*\}\}|\bwhen:.*is defined' "$file" |
             grep -o -E '[a-zA-Z0-9_]+' |
             sort -u)

      for var in $vars; do
        # Skip common Ansible variables and filters
        if [[ "$var" =~ ^(item|ansible_|lookup|hostvars|inventory_|groups|play_|playbook_|role_|omit|failed|changed|success|true|false|yes|no|and|or|not|defined|undefined|none|null|default|mandatory|filters|map|join|split|regex_replace|trim|upper|lower|capitalize)$ ]]; then
          continue
        fi

        # Check if variable is defined in defaults/ or vars/
        if ! grep -q -r "^[[:space:]]*$var:" defaults/ vars/ 2>/dev/null; then
          echo "UNDEFINED: $var in $file"
          undefined_vars=$((undefined_vars + 1))
        elif [ "$verbose" -eq 1 ]; then
          echo "OK: $var used in $file is defined."
        fi
      done
    done
  fi

  # Check for unused variables if not skipped
  if [ "$only_undefined" -eq 0 ]; then
    echo "Checking for unused variables..."

    # Extract all defined variables from defaults/ and vars/
    defined_vars=$(grep -r -E '^[[:space:]]*[a-zA-Z0-9_]+:' defaults/ vars/ 2>/dev/null |
                   sed -E 's/^.*:[[:space:]]*([a-zA-Z0-9_]+):.*/\1/' |
                   sort -u)

    for var in $defined_vars; do
      # Skip if variable name is empty
      if [ -z "$var" ]; then
        continue
      fi

      # Check if variable is used in any YAML/YML file or Jinja2 template
      if ! grep -q -r -E '\{\{[^}]*'"$var"'[^}]*\}\}|\bwhen:.*'"$var"'.*is (defined|not defined)' --include="*.yaml" --include="*.yml" --include="*.j2" . 2>/dev/null; then
        echo "UNUSED: $var defined but not used"
        unused_vars=$((unused_vars + 1))
      elif [ "$verbose" -eq 1 ]; then
        echo "OK: $var is defined and used."
      fi
    done
  fi

  # Print summary
  echo ""
  echo "Variable Validation Summary:"
  echo "-------------------------"
  if [ "$only_unused" -eq 0 ]; then
    echo "Undefined variables: $undefined_vars"
  fi
  if [ "$only_undefined" -eq 0 ]; then
    echo "Unused variables: $unused_vars"
  fi

  if [ $undefined_vars -eq 0 ] && [ $unused_vars -eq 0 ]; then
    echo "✓ All variables are properly defined and used."
    return 0
  else
    echo "⚠ There are variable issues that should be addressed."
    return 1
  fi
}

# Function to validate conditionals
function validate_conditionals {
  local fix=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)
        fix=1
        shift
        ;;
      --verbose)
        verbose=1
        shift
        ;;
      --help)
        usage_conditionals
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_conditionals
        exit 1
        ;;
    esac
  done

  echo "Validating Ansible conditionals..."

  # Track stats
  local errors=0
  local warnings=0
  local fixed=0

  # Find all YAML/YML files
  yaml_files=$(find . -name "*.yaml" -o -name "*.yml" | grep -v "^./\.")

  for file in $yaml_files; do
    # Extract lines with conditionals
    conditionals=$(grep -n -E 'when:' "$file" | sed 's/^\([0-9]\+\):.*/\1/')

    for line_num in $conditionals; do
      # Extract the conditional line
      conditional_line=$(sed "${line_num}q;d" "$file")

      # Common issues to check:

      # 1. Variable is used without "is defined" check
      if echo "$conditional_line" | grep -q -E 'when:[^|]*\{\{[^}]+\}\}' && ! echo "$conditional_line" | grep -q -E 'is defined'; then
        echo "WARNING: $file:$line_num - Variable in conditional used without 'is defined' check"
        warnings=$((warnings + 1))
      fi

      # 2. Missing quotes for complex expressions
      if echo "$conditional_line" | grep -q -E 'when:.*and|or|not' && ! echo "$conditional_line" | grep -q -E "when: ['\"](.*)['\"]"; then
        echo "ERROR: $file:$line_num - Complex conditional without quotes"
        errors=$((errors + 1))

        if [ "$fix" -eq 1 ]; then
          # Attempt to fix by adding quotes
          sed -i "${line_num}s/when: \(.*\)/when: '\1'/" "$file"
          echo "FIXED: Added quotes to conditional in $file:$line_num"
          fixed=$((fixed + 1))
        fi
      fi

      # 3. Using bare variables instead of explicit comparison
      if echo "$conditional_line" | grep -q -E 'when: [a-zA-Z0-9_]+$'; then
        echo "WARNING: $file:$line_num - Using bare variable in conditional, should use explicit comparison"
        warnings=$((warnings + 1))

        if [ "$fix" -eq 1 ]; then
          # Attempt to fix by adding explicit comparison
          var_name=$(echo "$conditional_line" | sed -E 's/.*when: ([a-zA-Z0-9_]+).*/\1/')
          sed -i "${line_num}s/when: $var_name/when: $var_name | bool/" "$file"
          echo "FIXED: Added explicit boolean conversion to conditional in $file:$line_num"
          fixed=$((fixed + 1))
        fi
      fi

      # 4. Using deprecated syntax
      if echo "$conditional_line" | grep -q -E 'when: .* \=\= '; then
        echo "ERROR: $file:$line_num - Using deprecated '==' syntax, should use 'is'"
        errors=$((errors + 1))

        if [ "$fix" -eq 1 ]; then
          # Attempt to fix by replacing == with is
          sed -i "${line_num}s/==/ is /g" "$file"
          echo "FIXED: Replaced '==' with 'is' in $file:$line_num"
          fixed=$((fixed + 1))
        fi
      fi

      # Verbose output for valid conditionals
      if [ "$verbose" -eq 1 ] && [ "$(echo "$conditional_line" | grep -c -E 'when: .*is defined|is not defined|in|not in|>\=|\<=|>|<|is|is not')" -gt 0 ]; then
        echo "OK: $file:$line_num - Valid conditional syntax"
      fi
    done
  done

  # Print summary
  echo ""
  echo "Conditional Validation Summary:"
  echo "----------------------------"
  echo "Errors: $errors"
  echo "Warnings: $warnings"

  if [ "$fix" -eq 1 ]; then
    echo "Issues fixed: $fixed"
  fi

  if [ $errors -eq 0 ]; then
    if [ $warnings -eq 0 ]; then
      echo "✓ All conditionals are valid."
      return 0
    else
      echo "⚠ Conditionals have warnings but no errors."
      return 0
    fi
  else
    echo "✗ Conditionals have errors that need to be fixed."
    return 1
  fi
}

# Function to run all validations
function validate_all {
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose)
        verbose=1
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

  echo "Running all validation checks..."
  echo ""

  # Track overall status
  local exit_status=0

  # Run documentation validation
  if [ "$verbose" -eq 1 ]; then
    validate_docs --verbose
  else
    validate_docs
  fi

  if [ $? -ne 0 ]; then
    exit_status=1
  fi

  # Add some spacing
  echo ""
  echo "========================================"
  echo ""

  # Run variable validation
  if [ "$verbose" -eq 1 ]; then
    validate_vars --verbose
  else
    validate_vars
  fi

  if [ $? -ne 0 ]; then
    exit_status=1
  fi

  # Add some spacing
  echo ""
  echo "========================================"
  echo ""

  # Run conditional validation
  if [ "$verbose" -eq 1 ]; then
    validate_conditionals --verbose
  else
    validate_conditionals
  fi

  if [ $? -ne 0 ]; then
    exit_status=1
  fi

  echo ""
  echo "All validation checks completed."

  return $exit_status
}

# Main command processing
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  docs)
    validate_docs "$@"
    ;;

  vars)
    validate_vars "$@"
    ;;

  conditionals)
    validate_conditionals "$@"
    ;;

  all)
    validate_all "$@"
    ;;

  help)
    usage
    exit 0
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
