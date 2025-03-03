#!/bin/bash
# Script to fix common YAML linting issues automatically

set -e

function usage {
  echo "Usage: $0 [options]"
  echo "Fix common YAML linting issues in the codebase."
  echo
  echo "Options:"
  echo "  --dry-run                 Show what would be changed without making changes"
  echo "  --quoted-strings          Fix quoted strings issues"
  echo "  --fqcn                    Fix FQCN (fully qualified collection name) issues"
  echo "  --jinja-spacing           Fix Jinja2 spacing issues"
  echo "  --line-length             Fix line length issues (breaks long lines)"
  echo "  --all                     Fix all issues (default)"
  echo "  --help                    Show this help message"
}

DRY_RUN=0
FIX_QUOTED_STRINGS=0
FIX_FQCN=0
FIX_JINJA_SPACING=0
FIX_LINE_LENGTH=0

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --quoted-strings)
      FIX_QUOTED_STRINGS=1
      shift
      ;;
    --fqcn)
      FIX_FQCN=1
      shift
      ;;
    --jinja-spacing)
      FIX_JINJA_SPACING=1
      shift
      ;;
    --line-length)
      FIX_LINE_LENGTH=1
      shift
      ;;
    --all)
      FIX_QUOTED_STRINGS=1
      FIX_FQCN=1
      FIX_JINJA_SPACING=1
      FIX_LINE_LENGTH=1
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
if [[ $FIX_QUOTED_STRINGS -eq 0 && $FIX_FQCN -eq 0 && $FIX_JINJA_SPACING -eq 0 && $FIX_LINE_LENGTH -eq 0 ]]; then
  FIX_QUOTED_STRINGS=1
  FIX_FQCN=1
  FIX_JINJA_SPACING=1
  FIX_LINE_LENGTH=1
fi

echo "Starting YAML linting fixes..."
if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN MODE: No actual changes will be made"
fi

# Function to print action with color
print_action() {
  local action="$1"
  local file="$2"
  local details="$3"

  if [[ "$action" == "FIX" ]]; then
    echo -e "\033[32m$action\033[0m: $file $details"
  elif [[ "$action" == "SKIP" ]]; then
    echo -e "\033[36m$action\033[0m: $file $details"
  elif [[ "$action" == "ERROR" ]]; then
    echo -e "\033[31m$action\033[0m: $file $details"
  else
    echo "$action: $file $details"
  fi
}

# Find all YAML files
YAML_FILES=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/\.*" -not -path "*/venv/*" | sort)

# Counters
FIXED_FILES=0
TOTAL_FILES=0

# Process each file
for file in $YAML_FILES; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  MODIFIED=0

  # Create a temporary file
  temp_file=$(mktemp)

  # Fix quoted strings issues
  if [[ $FIX_QUOTED_STRINGS -eq 1 ]]; then
    # Look for redundant quotes and fix them
    if grep -q "yaml\[quoted-strings\]: String value is redundantly quoted" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      # Replace redundantly quoted strings: 'string': to string:
      if [[ $DRY_RUN -eq 0 ]]; then
        sed -E "s/([[:space:]]+)'([a-zA-Z0-9_-]+)':/\1\2:/g" "$file" > "$temp_file"
        mv "$temp_file" "$file"
      fi
      print_action "FIX" "$file" "(removed redundant quotes)"
      MODIFIED=1
    fi

    # Add missing single quotes
    if grep -q "yaml\[quoted-strings\]: String value is not quoted with single quotes" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      # This is a complex operation requiring a more intelligent tool
      # For simplicity, we'll just report it needs manual fixing
      print_action "SKIP" "$file" "(missing quotes need manual fixing)"
    fi
  fi

  # Fix FQCN issues
  if [[ $FIX_FQCN -eq 1 && $MODIFIED -eq 0 ]]; then
    if grep -q "fqcn\[action-core\]" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      # For modules like 'file', 'command', 'shell', etc.
      if [[ $DRY_RUN -eq 0 ]]; then
        # This is a simplified approach; a more robust solution would parse the exact issues
        sed -E 's/([[:space:]]+)(file|command|shell|copy|template|debug|apt|yum|service|systemd|git|uri|include_role|include_tasks|assert|set_fact|dnf): /\1ansible.builtin.\2: /g' "$file" > "$temp_file"
        mv "$temp_file" "$file"
      fi
      print_action "FIX" "$file" "(added FQCN)"
      MODIFIED=1
    fi

    # Fix canonical FQCN issues
    if grep -q "fqcn\[canonical\]" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      if [[ $DRY_RUN -eq 0 ]]; then
        # Fix firewalld module
        sed -E 's/([[:space:]]+)ansible.builtin.firewalld:/\1ansible.posix.firewalld:/g' "$file" > "$temp_file"
        mv "$temp_file" "$file"
      fi
      print_action "FIX" "$file" "(fixed canonical FQCN)"
      MODIFIED=1
    fi
  fi

  # Fix Jinja spacing
  if [[ $FIX_JINJA_SPACING -eq 1 && $MODIFIED -eq 0 ]]; then
    if grep -q "jinja\[spacing\]" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      if [[ $DRY_RUN -eq 0 ]]; then
        # Fix common Jinja spacing issues
        sed -E 's/\{\{([^ ])/\{\{ \1/g' "$file" | sed -E 's/([^ ])\}\}/\1 \}\}/g' | sed -E 's/\|([a-zA-Z0-9_]+)/\| \1/g' > "$temp_file"
        mv "$temp_file" "$file"
      fi
      print_action "FIX" "$file" "(fixed Jinja spacing)"
      MODIFIED=1
    fi
  fi

  # Fix line length issues
  if [[ $FIX_LINE_LENGTH -eq 1 && $MODIFIED -eq 0 ]]; then
    if grep -q "yaml\[line-length\]" <(ansible-lint --format=pep8 "$file" 2>/dev/null); then
      print_action "SKIP" "$file" "(line length issues need manual fixing)"
      # Line length issues are complex and often require manual intervention
      # We'll just report them for now
    fi
  fi

  # Count fixed files
  if [[ $MODIFIED -eq 1 ]]; then
    FIXED_FILES=$((FIXED_FILES + 1))
  fi

  # Clean up any temp file
  rm -f "$temp_file"
done

echo
echo "========================================="
echo "YAML Linting Fix Summary"
echo "========================================="
echo "Total files processed: $TOTAL_FILES"
echo "Fixed files: $FIXED_FILES"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "No actual changes were made (dry run)"
fi
echo

if [[ $FIXED_FILES -gt 0 && $DRY_RUN -eq 0 ]]; then
  echo "Run ansible-lint again to check if there are remaining issues."
fi

# Final note on manual fixes
if [[ $FIX_QUOTED_STRINGS -eq 1 ]]; then
  echo "Note: Some quoted string issues require manual fixing. Check with ansible-lint."
fi

if [[ $FIX_LINE_LENGTH -eq 1 ]]; then
  echo "Note: Line length issues require manual fixing. Check with ansible-lint."
fi

exit 0
