#!/bin/bash
# Script to fix YAML file extensions based on the convention:
# - Use .yaml extension outside molecule/ directory
# - Use .yml extension inside molecule/ directory

set -e

function usage {
  echo "Usage: $0 [options]"
  echo "Fix YAML file extensions according to project conventions"
  echo
  echo "Options:"
  echo "  --dry-run    Show what would be changed without making changes"
  echo "  --reverse    Fix .yaml extensions in molecule/ directory (convert to .yml)"
  echo "  --help       Show this help message"
}

DRY_RUN=0
REVERSE=0

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --reverse)
      REVERSE=1
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

  if [[ "$action" == "RENAME" ]]; then
    echo -e "\033[33m$action\033[0m: $file"
  elif [[ "$action" == "SKIP" ]]; then
    echo -e "\033[36m$action\033[0m: $file"
  else
    echo "$action: $file"
  fi
}

# Fix .yaml to .yml in molecule directory
if [[ $REVERSE -eq 1 ]]; then
  echo "Converting .yaml to .yml in molecule/ directory"

  # Find all .yaml files in molecule directory
  while IFS= read -r file; do
    if [[ "$file" =~ molecule/.*\.yaml$ ]]; then
      new_file="${file%.yaml}.yml"

      if [[ $DRY_RUN -eq 1 ]]; then
        print_action "RENAME" "$file -> $new_file"
      else
        mv "$file" "$new_file"
        print_action "RENAME" "$file -> $new_file"
      fi
    fi
  done < <(find molecule -type f -name "*.yaml" | sort)

  echo "Conversion complete!"
else
  echo "This mode is for fixing other extensions, but we're only focusing on molecule/ directory for now."
  echo "Use --reverse to fix .yaml extensions in molecule/ directory."
fi

# Update references in files if needed
echo ""
echo "Note: You may need to update references to these files in:"
echo "- Playbooks"
echo "- Include statements"
echo "- Documentation"
echo "- CI/CD configurations"
echo ""
echo "Run './scripts/check-yaml-extensions.sh' to verify all extensions are now consistent."
