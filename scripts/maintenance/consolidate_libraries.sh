#!/bin/bash

# consolidate_libraries.sh - Script to help consolidate library files in the repository
# This script analyzes common library files and helps merge them

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

# Define the library files to analyze
LIBRARY_FILES=(
  "${PROJECT_ROOT}/scripts/lib/common.sh"
  "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh"
  "${PROJECT_ROOT}/scripts/utilities/common.sh"
  "${PROJECT_ROOT}/scripts/utilities/common_functions.sh"
)

# Output directory for analysis
OUTPUT_DIR="${PROJECT_ROOT}/scripts/maintenance/library_analysis"
mkdir -p "$OUTPUT_DIR"

# Function to print colored messages
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Extract function names from a shell script
extract_functions() {
  local file=$1
  local output_file=$2

  # Extract function declarations
  grep -E '^[[:space:]]*(function[[:space:]]+)?[a-zA-Z0-9_]+\(\)[[:space:]]*{' "$file" \
    | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)\(\).*$/\2/g' >"$output_file"

  # Count the functions
  local count=$(wc -l <"$output_file")
  echo "$count"
}

# Compare two function lists and find unique functions
compare_functions() {
  local file1=$1
  local file2=$2
  local output_file=$3

  # Find functions in file1 that are not in file2
  comm -23 <(sort "$file1") <(sort "$file2") >"$output_file"

  # Count the unique functions
  local count=$(wc -l <"$output_file")
  echo "$count"
}

# Analyze the library files
analyze_libraries() {
  print_status "$GREEN" "Starting library analysis..."

  # Extract function names from each library file
  local total_functions=0
  local file_counts=()
  local file_names=()

  for lib_file in "${LIBRARY_FILES[@]}"; do
    if [[ -f "$lib_file" ]]; then
      local file_name=$(basename "$lib_file")
      local output_file="${OUTPUT_DIR}/${file_name}_functions.txt"
      local count=$(extract_functions "$lib_file" "$output_file")

      file_counts+=("$count")
      file_names+=("$file_name")
      total_functions=$((total_functions + count))

      print_status "$BLUE" "Found $count functions in $file_name"
    fi
  done

  # Create comparison matrix for unique functions
  print_status "$GREEN" "Analyzing unique functions between libraries..."

  for i in "${!LIBRARY_FILES[@]}"; do
    if [[ ! -f "${LIBRARY_FILES[$i]}" ]]; then
      continue
    fi

    for j in "${!LIBRARY_FILES[@]}"; do
      if [[ "$i" -eq "$j" || ! -f "${LIBRARY_FILES[$j]}" ]]; then
        continue
      fi

      local file1_name=$(basename "${LIBRARY_FILES[$i]}")
      local file2_name=$(basename "${LIBRARY_FILES[$j]}")
      local output_file="${OUTPUT_DIR}/${file1_name}_unique_vs_${file2_name}.txt"

      local unique_count=$(compare_functions \
        "${OUTPUT_DIR}/${file1_name}_functions.txt" \
        "${OUTPUT_DIR}/${file2_name}_functions.txt" \
        "$output_file")

      print_status "$BLUE" "$file1_name has $unique_count unique functions not in $file2_name"
    done
  done

  # Find common functions across all libraries
  if [[ "${#file_names[@]}" -gt 0 ]]; then
    print_status "$GREEN" "Finding common functions across all libraries..."

    local first_file="${OUTPUT_DIR}/${file_names[0]}_functions.txt"
    local common_file="${OUTPUT_DIR}/common_across_all.txt"
    cp "$first_file" "$common_file.tmp"

    for ((i = 1; i < ${#file_names[@]}; i++)); do
      comm -12 <(sort "$common_file.tmp") <(sort "${OUTPUT_DIR}/${file_names[$i]}_functions.txt") >"$common_file.tmp2"
      mv "$common_file.tmp2" "$common_file.tmp"
    done

    mv "$common_file.tmp" "$common_file"
    local common_count=$(wc -l <"$common_file")
    print_status "$BLUE" "Found $common_count functions common to all libraries"
  fi

  # Generate consolidation plan
  print_status "$GREEN" "Generating consolidation plan..."

  if [[ -f "${LIBRARY_FILES[1]}" ]]; then # common_consolidated.sh
    print_status "$YELLOW" "Recommended base: scripts/lib/common_consolidated.sh"
    print_status "$YELLOW" "This file already appears to be a consolidation effort and has the most functions."

    for i in "${!LIBRARY_FILES[@]}"; do
      if [[ "$i" -ne 1 && -f "${LIBRARY_FILES[$i]}" ]]; then
        local file_name=$(basename "${LIBRARY_FILES[$i]}")
        local unique_file="${OUTPUT_DIR}/common_consolidated.sh_unique_vs_${file_name}.txt"
        local reverse_unique="${OUTPUT_DIR}/${file_name}_unique_vs_common_consolidated.sh.txt"

        if [[ -f "$reverse_unique" ]]; then
          local unique_count=$(wc -l <"$reverse_unique")
          if [[ "$unique_count" -gt 0 ]]; then
            print_status "$YELLOW" "Merge $unique_count unique functions from $file_name into common_consolidated.sh"
          fi
        fi
      fi
    done
  fi

  # Create the consolidation helper script
  create_consolidation_helper

  print_status "$GREEN" "Library analysis completed. See $OUTPUT_DIR for detailed output."
  print_status "$GREEN" "A consolidation helper script has been created at $OUTPUT_DIR/merge_libraries.sh"
}

# Create a script to help with the actual consolidation
create_consolidation_helper() {
  local helper_script="${OUTPUT_DIR}/merge_libraries.sh"

  cat >"$helper_script" <<'EOF'
#!/bin/bash

# merge_libraries.sh - Helper script to merge library files
# This script should be run manually with careful review of each step

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define the consolidated library location
CONSOLIDATED_LIB="${PROJECT_ROOT}/scripts/lib/common_unified.sh"

# Function to print colored messages
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Copy the base library first
print_status "$GREEN" "Creating unified library from common_consolidated.sh..."

if [[ ! -f "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" ]]; then
    print_status "$RED" "Base library file not found. Aborting."
    exit 1
fi

# Create a backup first
cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh.bak"
print_status "$GREEN" "Created backup of common_consolidated.sh"

# Copy as the starting point for the unified library
cp "${PROJECT_ROOT}/scripts/lib/common_consolidated.sh" "$CONSOLIDATED_LIB"

# Inform about next steps
print_status "$YELLOW" "Next steps:"
echo "1. Use the function analysis in this directory to identify unique functions to merge"
echo "2. Manually merge the unique functions from each library into $CONSOLIDATED_LIB"
echo "3. Test the unified library thoroughly"
echo "4. Update imports in scripts to use the new unified library"

print_status "$GREEN" "Consolidation helper script finished."
EOF

  chmod +x "$helper_script"
}

# Run the main function
analyze_libraries

exit 0
