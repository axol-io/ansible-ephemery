#!/bin/bash

# standardize_naming.sh - Script to standardize file naming conventions across the repository
# This script helps identify and fix inconsistent naming patterns

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output files
HYPHEN_FILES="${PROJECT_ROOT}/scripts/maintenance/hyphen_files.txt"
UNDERSCORE_FILES="${PROJECT_ROOT}/scripts/maintenance/underscore_files.txt"
CAMELCASE_FILES="${PROJECT_ROOT}/scripts/maintenance/camelcase_files.txt"
RENAME_SCRIPT="${PROJECT_ROOT}/scripts/maintenance/rename_files.sh"

# Function to print colored messages
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to identify naming patterns
identify_naming_patterns() {
  print_status "$GREEN" "Identifying naming patterns in the repository..."

  # Clean up existing output files
  rm -f "$HYPHEN_FILES" "$UNDERSCORE_FILES" "$CAMELCASE_FILES"

  # Find all shell scripts
  local shell_scripts=$(find "$PROJECT_ROOT" -type f -name "*.sh" | sort)

  # Count total scripts
  local total_scripts=$(echo "$shell_scripts" | wc -l)
  print_status "$BLUE" "Found $total_scripts shell scripts in the repository"

  # Identify naming patterns
  local hyphen_count=0
  local underscore_count=0
  local camelcase_count=0

  for script in $shell_scripts; do
    local filename=$(basename "$script")

    # Check for hyphen-separated names
    if [[ "$filename" =~ -.*\.sh ]]; then
      echo "$script" >>"$HYPHEN_FILES"
      hyphen_count=$((hyphen_count + 1))
    # Check for underscore_separated names
    elif [[ "$filename" =~ _.*\.sh ]]; then
      echo "$script" >>"$UNDERSCORE_FILES"
      underscore_count=$((underscore_count + 1))
    # Check for camelCase or PascalCase names
    elif [[ "$filename" =~ [A-Z][a-z]+.*\.sh ]]; then
      echo "$script" >>"$CAMELCASE_FILES"
      camelcase_count=$((camelcase_count + 1))
    fi
  done

  # Print summary
  print_status "$GREEN" "Naming pattern summary:"
  print_status "$BLUE" "Hyphen-separated names: $hyphen_count scripts"
  print_status "$BLUE" "Underscore_separated names: $underscore_count scripts"
  print_status "$BLUE" "CamelCase names: $camelcase_count scripts"

  # Determine dominant pattern
  local dominant="underscore"
  if [[ "$hyphen_count" -gt "$underscore_count" ]]; then
    dominant="hyphen"
  fi

  print_status "$YELLOW" "Dominant naming pattern: $dominant-separated names"
  print_status "$YELLOW" "Recommend standardizing on $dominant-separated names for consistency"

  # Create rename script
  create_rename_script "$dominant"
}

# Function to create a script for renaming files
create_rename_script() {
  local dominant_pattern=$1

  print_status "$GREEN" "Creating rename script for standardizing on $dominant_pattern-separated names..."

  # Create script header
  cat >"$RENAME_SCRIPT" <<'EOF'
#!/bin/bash

# rename_files.sh - Script to standardize file naming conventions
# This script was automatically generated to help standardize file names

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to rename a file
rename_file() {
    local old_path=$1
    local new_path=$2

    if [[ -f "$old_path" ]]; then
        if [[ -f "$new_path" ]]; then
            print_status "$RED" "ERROR: Cannot rename $old_path to $new_path - target file already exists"
            return 1
        fi

        # Create parent directory if it doesn't exist
        mkdir -p "$(dirname "$new_path")"

        # Rename the file
        mv "$old_path" "$new_path"
        print_status "$GREEN" "Renamed: $old_path -> $new_path"

        return 0
    else
        print_status "$RED" "ERROR: Source file $old_path does not exist"
        return 1
    fi
}

# Function to update file references in a file
update_references() {
    local file=$1
    local old_name=$2
    local new_name=$3

    if [[ -f "$file" ]]; then
        # Only modify text files
        if file "$file" | grep -q text; then
            # Use grep to check if the file contains the old name, then sed to replace it
            if grep -q "$old_name" "$file"; then
                sed -i '' "s|$old_name|$new_name|g" "$file"
                print_status "$GREEN" "Updated references in: $file"
            fi
        fi
    fi
}

# Function to update references in all files
update_all_references() {
    local old_path=$1
    local new_path=$2

    local old_name=$(basename "$old_path")
    local new_name=$(basename "$new_path")

    print_status "$YELLOW" "Updating references from $old_name to $new_name..."

    # Find all text files in the repository
    local text_files=$(find "$PROJECT_ROOT" -type f -not -path "*/\.*" | xargs file | grep "text" | cut -d ":" -f1)

    for file in $text_files; do
        update_references "$file" "$old_name" "$new_name"
    done
}

print_status "$GREEN" "Starting file renaming process..."
print_status "$YELLOW" "WARNING: This script will rename files to standardize naming conventions."
print_status "$YELLOW" "It will also attempt to update references to the renamed files."
print_status "$YELLOW" "It is recommended to run this script ONLY in a clean git workspace so you can review changes."

read -p "Do you want to proceed with renaming? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_status "$YELLOW" "Renaming cancelled."
    exit 0
fi

# Files to rename:
EOF

  # Add rename commands based on dominant pattern
  if [[ "$dominant_pattern" == "underscore" ]]; then
    # Add commands to convert hyphen to underscore
    if [[ -f "$HYPHEN_FILES" ]]; then
      echo "# Convert hyphen-separated names to underscore_separated names" >>"$RENAME_SCRIPT"

      while IFS= read -r file; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        local new_filename="${filename//-/_}"
        local new_path="${dir}/${new_filename}"

        echo "rename_file \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "update_all_references \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "" >>"$RENAME_SCRIPT"
      done <"$HYPHEN_FILES"
    fi

    # Add commands to convert camelCase to underscore
    if [[ -f "$CAMELCASE_FILES" ]]; then
      echo "# Convert camelCase names to underscore_separated names" >>"$RENAME_SCRIPT"

      while IFS= read -r file; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        # Convert camelCase to underscore: insert underscore before uppercase letters and convert to lowercase
        local new_filename=$(echo "$filename" | sed -E 's/([A-Z])/_\1/g' | tr '[:upper:]' '[:lower:]')
        # Remove leading underscore if present
        new_filename=${new_filename/#_/}
        local new_path="${dir}/${new_filename}"

        echo "rename_file \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "update_all_references \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "" >>"$RENAME_SCRIPT"
      done <"$CAMELCASE_FILES"
    fi
  elif [[ "$dominant_pattern" == "hyphen" ]]; then
    # Add commands to convert underscore to hyphen
    if [[ -f "$UNDERSCORE_FILES" ]]; then
      echo "# Convert underscore_separated names to hyphen-separated names" >>"$RENAME_SCRIPT"

      while IFS= read -r file; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        local new_filename="${filename//_/-}"
        local new_path="${dir}/${new_filename}"

        echo "rename_file \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "update_all_references \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "" >>"$RENAME_SCRIPT"
      done <"$UNDERSCORE_FILES"
    fi

    # Add commands to convert camelCase to hyphen
    if [[ -f "$CAMELCASE_FILES" ]]; then
      echo "# Convert camelCase names to hyphen-separated names" >>"$RENAME_SCRIPT"

      while IFS= read -r file; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        # Convert camelCase to hyphen: insert hyphen before uppercase letters and convert to lowercase
        local new_filename=$(echo "$filename" | sed -E 's/([A-Z])/-\1/g' | tr '[:upper:]' '[:lower:]')
        # Remove leading hyphen if present
        new_filename=${new_filename/#-/}
        local new_path="${dir}/${new_filename}"

        echo "rename_file \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "update_all_references \"$file\" \"$new_path\"" >>"$RENAME_SCRIPT"
        echo "" >>"$RENAME_SCRIPT"
      done <"$CAMELCASE_FILES"
    fi
  fi

  # Add script footer
  cat >>"$RENAME_SCRIPT" <<'EOF'

print_status "$GREEN" "File renaming completed."
print_status "$YELLOW" "Please review the changes and commit them if satisfied."
print_status "$YELLOW" "Note: Some references may not have been updated correctly. Manual verification is recommended."

exit 0
EOF

  chmod +x "$RENAME_SCRIPT"

  print_status "$GREEN" "Rename script created at: $RENAME_SCRIPT"
  print_status "$YELLOW" "Review the script carefully before running it!"
}

# Run the main function
identify_naming_patterns

exit 0
