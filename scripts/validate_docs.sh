#!/bin/bash
# validate_docs.sh - Script to validate documentation against standards

set -e

echo "Validating documentation against established standards..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Counter for issues
ERRORS=0
WARNINGS=0

# Function to check documentation files
check_file() {
  local file=$1
  local issues=0
  local warnings=0
  local long_lines
  local code_blocks
  local passive_voice

  echo -e "\nChecking ${YELLOW}$file${NC}..."

  # Check header format (should start with # and a space)
  if ! grep -q "^# " "$file"; then
    echo -e "  ${RED}ERROR:${NC} File should start with '# ' followed by a title"
    issues=$((issues+1))
  fi

  # Check for line length > 100 characters
  long_lines=$(grep -n '.\{101,\}' "$file" | grep -v '```' | wc -l)
  if [ "$long_lines" -gt 0 ]; then
    echo -e "  ${YELLOW}WARNING:${NC} File has $long_lines lines longer than 100 characters"
    warnings=$((warnings+1))
  fi

  # Check for proper Markdown code blocks (should use language specifier)
  code_blocks=$(grep -n '```$' "$file" | wc -l)
  if [ "$code_blocks" -gt 0 ]; then
    echo -e "  ${YELLOW}WARNING:${NC} File has $code_blocks code blocks without language specifier"
    warnings=$((warnings+1))
  fi

  # Check for active voice (common passive voice constructs)
  passive_voice=$(grep -n -E "is being|are being|was being|were being|been|is done|are done|was done|were done" "$file" | wc -l)
  if [ "$passive_voice" -gt 3 ]; then
    echo -e "  ${YELLOW}WARNING:${NC} File may contain excessive passive voice ($passive_voice instances found)"
    warnings=$((warnings+1))
  fi

  # Check for inconsistent header case
  if grep -q "##* [a-z]" "$file"; then
    echo -e "  ${YELLOW}WARNING:${NC} Headers should start with capital letters"
    warnings=$((warnings+1))
  fi

  # Update counters
  ERRORS=$((ERRORS+issues))
  WARNINGS=$((WARNINGS+warnings))

  # Return success if no errors
  if [ $issues -eq 0 ]; then
    if [ $warnings -eq 0 ]; then
      echo -e "  ${GREEN}OK:${NC} No issues found"
    else
      echo -e "  ${YELLOW}OK with warnings:${NC} $warnings warnings found"
    fi
    return 0
  else
    echo -e "  ${RED}FAILED:${NC} $issues issues found"
    return 1
  fi
}

# Check README.md
check_file "README.md"

# Check docs/ directory
echo -e "\nChecking docs/ directory..."
for file in docs/*.md; do
  check_file "$file"
done

# Check molecule/README.md if it exists
if [ -f "molecule/README.md" ]; then
  check_file "molecule/README.md"
fi

# Summary
echo -e "\n${YELLOW}=== Documentation Validation Summary ===${NC}"
echo -e "Found ${RED}$ERRORS errors${NC} and ${YELLOW}$WARNINGS warnings${NC}"

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}Documentation validation failed${NC}"
  exit 1
else
  if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Documentation validation passed with warnings${NC}"
  else
    echo -e "${GREEN}Documentation validation passed${NC}"
  fi
  exit 0
fi
