#!/bin/bash
# Version: 1.0.0
# yaml-lint-fixer.sh - Consolidated script for YAML linting and fixing
# Combines functionality from:
# - fix-yaml-linting.sh
# - fix_yaml_lint.sh
# - fix-yaml-line-length.sh
# - fix-yaml-quotes.sh
# - fix_line_length.sh

set -e

# Constants
MAX_LINE_LENGTH=100
REPORT_FILE="yaml_lint_issues.txt"

# Print usage information
function usage {
  echo "Usage: $0 [options]"
  echo "Fix common YAML linting issues in the codebase."
  echo
  echo "Options:"
  echo "  --quoted-strings    Fix quoted strings issues"
  echo "  --document-start    Add missing document start markers (---)"
  echo "  --truthy-values     Normalize truthy values (yes/no -> true/false)"
  echo "  --whitespace        Fix trailing whitespace"
  echo "  --jinja-spacing     Fix Jinja2 spacing issues"
  echo "  --fqcn              Fix FQCN (fully qualified collection name) issues"
  echo "  --line-length       Identify and suggest fixes for long lines"
  echo "  --all               Fix all issues (default)"
  echo "  --dry-run           Show what would be changed without making changes"
  echo "  --help              Show this help message"
}

# Default options
DRY_RUN=0
FIX_QUOTED_STRINGS=0
FIX_DOCUMENT_START=0
FIX_TRUTHY_VALUES=0
FIX_WHITESPACE=0
FIX_JINJA_SPACING=0
FIX_FQCN=0
CHECK_LINE_LENGTH=0

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quoted-strings)
      FIX_QUOTED_STRINGS=1
      shift
      ;;
    --document-start)
      FIX_DOCUMENT_START=1
      shift
      ;;
    --truthy-values)
      FIX_TRUTHY_VALUES=1
      shift
      ;;
    --whitespace)
      FIX_WHITESPACE=1
      shift
      ;;
    --jinja-spacing)
      FIX_JINJA_SPACING=1
      shift
      ;;
    --fqcn)
      FIX_FQCN=1
      shift
      ;;
    --line-length)
      CHECK_LINE_LENGTH=1
      shift
      ;;
    --all)
      FIX_QUOTED_STRINGS=1
      FIX_DOCUMENT_START=1
      FIX_TRUTHY_VALUES=1
      FIX_WHITESPACE=1
      FIX_JINJA_SPACING=1
      FIX_FQCN=1
      CHECK_LINE_LENGTH=1
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

# If no specific fix is selected, fix all
if [[ ${FIX_QUOTED_STRINGS} -eq 0 && ${FIX_DOCUMENT_START} -eq 0 && ${FIX_TRUTHY_VALUES} -eq 0 &&
  ${FIX_WHITESPACE} -eq 0 && ${FIX_JINJA_SPACING} -eq 0 && ${FIX_FQCN} -eq 0 && ${CHECK_LINE_LENGTH} -eq 0 ]]; then
  FIX_QUOTED_STRINGS=1
  FIX_DOCUMENT_START=1
  FIX_TRUTHY_VALUES=1
  FIX_WHITESPACE=1
  FIX_JINJA_SPACING=1
  FIX_FQCN=1
  CHECK_LINE_LENGTH=1
fi

# Function to print action with color
print_action() {
  local action="$1"
  local file="$2"
  local details="$3"

  if [[ "${action}" == "FIX" ]]; then
    echo -e "\033[32m${action}\033[0m: ${file} ${details}"
  elif [[ "${action}" == "SKIP" ]]; then
    echo -e "\033[36m${action}\033[0m: ${file} ${details}"
  elif [[ "${action}" == "ERROR" ]]; then
    echo -e "\033[31m${action}\033[0m: ${file} ${details}"
  else
    echo "${action}: ${file} ${details}"
  fi
}

echo "Starting YAML linting fixes..."
if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "DRY RUN MODE: No actual changes will be made"
fi

# Find all YAML files
YAML_FILES=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/\.*" -not -path "*/venv/*" | sort)

# Initialize line length report if needed
if [[ ${CHECK_LINE_LENGTH} -eq 1 ]]; then
  echo "# YAML Line Length Issues - $(date)" >"${REPORT_FILE}"
  echo "# Lines longer than ${MAX_LINE_LENGTH} characters" >>"${REPORT_FILE}"
  echo "# Format: FILE:LINE_NUMBER:LENGTH - CONTENT" >>"${REPORT_FILE}"
  echo "" >>"${REPORT_FILE}"
fi

# Counters
FIXED_FILES=0
TOTAL_FILES=0
TOTAL_LINE_ISSUES=0

# Process each file
for file in ${YAML_FILES}; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  MODIFIED=0
  LINE_ISSUES=0

  # Create a temporary file
  temp_file=$(mktemp)

  # Fix document start marker
  if [[ ${FIX_DOCUMENT_START} -eq 1 ]]; then
    # Check if file starts with --- and add if missing
    if ! grep -q "^---" "${file}"; then
      if [[ ${DRY_RUN} -eq 0 ]]; then
        sed '1s/^/---\n/' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(added document start marker)"
      MODIFIED=1
    fi
  fi

  # Fix quoted strings issues
  if [[ ${FIX_QUOTED_STRINGS} -eq 1 ]]; then
    # Look for redundant quotes and fix them
    if grep -q "yaml\[quoted-strings\]: String value is redundantly quoted" <(ansible-lint --format=pep8 "${file}" 2>/dev/null); then
      # Replace redundantly quoted strings: 'string': to string:
      if [[ ${DRY_RUN} -eq 0 ]]; then
        sed -E "s/([[:space:]]+)'([a-zA-Z0-9_-]+)':/\1\2:/g" "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(removed redundant quotes)"
      MODIFIED=1
    fi

    # Add missing single quotes
    if grep -q "yaml\[quoted-strings\]: String value is not quoted with single quotes" <(ansible-lint --format=pep8 "${file}" 2>/dev/null); then
      # This is a complex operation requiring a more intelligent tool
      # For simplicity, we'll just report it needs manual fixing
      print_action "SKIP" "${file}" "(missing quotes need manual fixing)"
    fi
  fi

  # Fix truthy values
  if [[ ${FIX_TRUTHY_VALUES} -eq 1 ]]; then
    if grep -q ": [Yy][Ee][Ss]$\|: [Nn][Oo]$" "${file}"; then
      if [[ ${DRY_RUN} -eq 0 ]]; then
        # Replace yes/Yes/YES with true
        sed -E 's/: [Yy][Ee][Ss]$/: true/g' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"

        # Replace no/No/NO with false
        sed -E 's/: [Nn][Oo]$/: false/g' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(normalized truthy values)"
      MODIFIED=1
    fi
  fi

  # Fix trailing whitespace
  if [[ ${FIX_WHITESPACE} -eq 1 ]]; then
    if grep -q "[[:space:]]$" "${file}"; then
      if [[ ${DRY_RUN} -eq 0 ]]; then
        sed 's/[[:space:]]*$//' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(removed trailing whitespace)"
      MODIFIED=1
    fi
  fi

  # Fix FQCN issues
  if [[ ${FIX_FQCN} -eq 1 ]]; then
    if grep -q "fqcn\[action-core\]" <(ansible-lint --format=pep8 "${file}" 2>/dev/null); then
      # For modules like 'file', 'command', 'shell', etc.
      if [[ ${DRY_RUN} -eq 0 ]]; then
        # This is a simplified approach; a more robust solution would parse the exact issues
        sed -E 's/([[:space:]]+)(file|command|shell|copy|template|debug|apt|yum|service|systemd|git|uri|include_role|include_tasks|assert|set_fact|dnf): /\1ansible.builtin.\2: /g' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(added FQCN)"
      MODIFIED=1
    fi

    # Fix canonical FQCN issues
    if grep -q "fqcn\[canonical\]" <(ansible-lint --format=pep8 "${file}" 2>/dev/null); then
      if [[ ${DRY_RUN} -eq 0 ]]; then
        # Fix firewalld module
        sed -E 's/([[:space:]]+)ansible.builtin.firewalld:/\1ansible.posix.firewalld:/g' "${file}" >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(fixed canonical FQCN)"
      MODIFIED=1
    fi
  fi

  # Fix Jinja spacing
  if [[ ${FIX_JINJA_SPACING} -eq 1 ]]; then
    if grep -q "jinja\[spacing\]" <(ansible-lint --format=pep8 "${file}" 2>/dev/null); then
      if [[ ${DRY_RUN} -eq 0 ]]; then
        # Fix common Jinja spacing issues
        sed -E 's/\{\{([^ ])/\{\{ \1/g' "${file}" | sed -E 's/([^ ])\}\}/\1 \}\}/g' | sed -E 's/\|([a-zA-Z0-9_]+)/\| \1/g' >"${temp_file}"
        mv "${temp_file}" "${file}"
      fi
      print_action "FIX" "${file}" "(fixed Jinja spacing)"
      MODIFIED=1
    fi
  fi

  # Check line length
  if [[ ${CHECK_LINE_LENGTH} -eq 1 ]]; then
    LINE_NUM=0

    while IFS= read -r line; do
      LINE_NUM=$((LINE_NUM + 1))
      LINE_LENGTH=${#line}

      if [ "${LINE_LENGTH}" -gt "${MAX_LINE_LENGTH}" ]; then
        LINE_ISSUES=$((LINE_ISSUES + 1))
        TOTAL_LINE_ISSUES=$((TOTAL_LINE_ISSUES + 1))

        # Add to report file
        echo "${file}:${LINE_NUM}:${LINE_LENGTH} - ${line}" >>"${REPORT_FILE}"

        # Suggest fixes
        if [[ "${line}" == *command:* || "${line}" == *shell:* || "${line}" == *docker* ]]; then
          echo "  - Consider breaking command into multiple lines using YAML folded style (>)" >>"${REPORT_FILE}"
        elif [[ "${line}" == *'{{.Names}}'* ]]; then
          echo "  - Consider assigning format template to a variable" >>"${REPORT_FILE}"
        elif [[ "${line}" == *with_items:* || "${line}" == *loop:* ]]; then
          echo "  - Consider breaking list into multiple lines" >>"${REPORT_FILE}"
        fi

        echo "" >>"${REPORT_FILE}"
      fi
    done <"${file}"

    if [ "${LINE_ISSUES}" -gt 0 ]; then
      print_action "INFO" "${file}" "(found ${LINE_ISSUES} lines exceeding ${MAX_LINE_LENGTH} characters)"
    fi
  fi

  # Count fixed files
  if [[ ${MODIFIED} -eq 1 ]]; then
    FIXED_FILES=$((FIXED_FILES + 1))
  fi

  # Clean up any temp file
  rm -f "${temp_file}"
done

# Print summary
echo
echo "========================================="
echo "YAML Linting Fix Summary"
echo "========================================="
echo "Total files processed: ${TOTAL_FILES}"
echo "Fixed files: ${FIXED_FILES}"

if [[ ${CHECK_LINE_LENGTH} -eq 1 ]]; then
  echo "Files with line length issues: ${TOTAL_LINE_ISSUES}"

  if [ "${TOTAL_LINE_ISSUES}" -gt 0 ]; then
    echo "See ${REPORT_FILE} for line length issues and suggestions."

    # Show example fixes for line length issues
    echo ""
    echo "Line Length Fix Examples:"
    echo ""
    echo "1. Long command line:"
    echo "  Before:"
    echo "    command: docker ps --filter name=container --format '{{ .Names }}'"
    echo ""
    echo "  After:"
    echo "    command: >"
    echo "      docker ps"
    echo "      --filter name=container"
    echo "      --format '{{ .Names }}'"
    echo ""
    echo "2. Long list:"
    echo "  Before:"
    echo "    loop: ['item1', 'item2', 'item3', 'item4', 'item5', 'item6', 'item7']"
    echo ""
    echo "  After:"
    echo "    loop:"
    echo "      - 'item1'"
    echo "      - 'item2'"
    echo "      - 'item3'"
    echo "      - 'item4'"
    echo "      - 'item5'"
    echo "      - 'item6'"
    echo "      - 'item7'"
  fi
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "No actual changes were made (dry run)"
fi
echo

if [[ ${FIXED_FILES} -gt 0 && ${DRY_RUN} -eq 0 ]]; then
  echo "Run ansible-lint again to check if there are remaining issues."
fi

exit 0
