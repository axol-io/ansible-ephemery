#!/bin/bash
# Version: 1.0.0
# Script to identify and help fix long lines in YAML files
# This script will identify lines that are too long and suggest manual fixes

set -e

MAX_LENGTH=100
echo "Identifying YAML lines longer than ${MAX_LENGTH} characters..."

# Find all yaml/yml files excluding hidden directories
YAML_FILES=$(find . -name "*.yaml" -o -name "*.yml" | grep -v "^\./\." | grep -v "node_modules")

# Create report file
REPORT_FILE="line_length_issues.txt"
echo "# YAML Line Length Issues - $(date)" >"${REPORT_FILE}"
echo "# Lines longer than ${MAX_LENGTH} characters" >>"${REPORT_FILE}"
echo "# Format: FILE:LINE_NUMBER:LENGTH - CONTENT" >>"${REPORT_FILE}"
echo "" >>"${REPORT_FILE}"

TOTAL_ISSUES=0

for file in ${YAML_FILES}; do
  LINE_NUM=0
  ISSUES=0

  while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))
    LINE_LENGTH=${#line}

    if [ "${LINE_LENGTH}" -gt "${MAX_LENGTH}" ]; then
      ISSUES=$((ISSUES + 1))
      TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

      # Add to report file
      echo "${file}:${LINE_NUM}:${LINE_LENGTH} - ${line}" >>"${REPORT_FILE}"

      # Suggest fixes
      if [[ "${line}" == *command:* || "${line}" == *shell:* || "${line}" == *docker* ]]; then
        echo "  - Consider breaking command into multiple lines using YAML folded style (>)" >>"${REPORT_FILE}"
      elif [[ "${line}" == *"{% raw %}{{.Names}}{% endraw %}"* ]]; then
        echo "  - Consider assigning format template to a variable" >>"${REPORT_FILE}"
      elif [[ "${line}" == *with_items:* || "${line}" == *loop:* ]]; then
        echo "  - Consider breaking list into multiple lines" >>"${REPORT_FILE}"
      fi

      echo "" >>"${REPORT_FILE}"
    fi
  done <"${file}"

  if [ "${ISSUES}" -gt 0 ]; then
    echo "Found ${ISSUES} long lines in ${file}"
  fi
done

echo ""
echo "Found ${TOTAL_ISSUES} lines longer than ${MAX_LENGTH} characters."
echo "See ${REPORT_FILE} for details and suggestions."
echo ""
echo "Fix examples:"
echo ""
echo "1. Long command line:"
echo "  Before:"
echo "    command: docker ps --filter name=container --format '{% raw %}{{.Names}}{% endraw %}'"
echo ""
echo "  After:"
echo "    command: >"
echo "      docker ps"
echo "      --filter name=container"
echo "      --format '{% raw %}{{.Names}}{% endraw %}'"
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
