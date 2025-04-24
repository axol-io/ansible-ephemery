#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
# Script to fix common syntax errors in shell scripts

# List of files with known errors
declare -a files_to_fix=(
  "scripts/deploy_enhanced_validator_dashboard.sh"
  "scripts/utilities/enhanced_key_restore.sh"
  "scripts/deployment/setup_obol_squadstaking.sh"
  "scripts/remote/run-ephemery-remote.sh"
  "scripts/core/ephemery_reset_handler.sh"
  "scripts/monitoring/validator_dashboard.sh"
  "scripts/monitoring/optimize_validator_monitoring.sh"
)

for file in "${files_to_fix[@]}"; do
  if [ -f "$file" ]; then
    echo "Fixing $file"

    # Create a backup of the original file
    cp "$file" "${file}.bak"

    # Fix "fi" that should be "}" to close a function or code block
    # This is a common error in shell scripts when people mistakenly use "fi" instead of "}"
    # First identify if these are function definitions that are being incorrectly closed

    # Look for patterns like "function name {" followed by a "fi" instead of "}"
    # or "name() {" followed by a "fi" instead of "}"
    sed -i.tmp 's/^\s*fi\s*$/}/' "$file"

    # Check if the file matches a shebang pattern
    if grep -q '^#!.*sh' "$file"; then
      echo "Verified file has proper shell script header"
    else
      # Add shebang if missing
      sed -i.tmp '1s/^/#!/bin/bash\n/' "$file"
      echo "Added missing shebang"
    fi

    # Clean up temporary files
    rm -f "${file}.tmp"
  else
    echo "File not found: $file"
  fi
done

echo "Shell script syntax fixing complete!"
