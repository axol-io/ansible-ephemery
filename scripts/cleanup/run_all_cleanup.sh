#!/bin/bash
#
# Master script to run all repository cleanup scripts in the correct order
#

set -e

# Print header
echo "====================================================="
echo "       Running Repository Cleanup Scripts             "
echo "====================================================="

# Create cleanup directory if it doesn't exist
CLEANUP_DIR="scripts/cleanup"
if [ ! -d "$CLEANUP_DIR" ]; then
  mkdir -p "$CLEANUP_DIR"
  echo "Created cleanup directory: $CLEANUP_DIR"
fi

# Ensure all scripts are executable
chmod +x "$CLEANUP_DIR"/*.sh 2>/dev/null || true

# Define cleanup stages and their corresponding scripts
# Using separate arrays instead of associative array
STAGE_NAMES=(
  "1-backup-files"
  "2-script-backups"
  "3-utils-merge"
  "4-common-libs"
  "5-validator-wrappers"
  "6-standardization"
  "7-config-files"
  "8-documentation"
  "9-ansible-collections"
)

STAGE_SCRIPTS=(
  "$CLEANUP_DIR/remove_backup_files.sh"
  "$CLEANUP_DIR/remove_script_backups.sh"
  "$CLEANUP_DIR/merge_utils_directories.sh"
  "$CLEANUP_DIR/consolidate_common_libraries.sh"
  "$CLEANUP_DIR/consolidate_validator_wrappers.sh"
  "$CLEANUP_DIR/consolidate_standardization_scripts.sh"
  "$CLEANUP_DIR/standardize_configuration_files.sh"
  "$CLEANUP_DIR/standardize_documentation.sh"
  "$CLEANUP_DIR/analyze_ansible_collections.sh"
)

# Create logs directory
LOGS_DIR="cleanup_logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOGS_DIR"
echo "Created logs directory: $LOGS_DIR"

# Function to run a specific cleanup stage
run_cleanup_stage() {
  local stage_name="$1"
  local script_path="$2"

  if [ ! -f "$script_path" ]; then
    echo "ERROR: Script not found: $script_path"
    return 1
  fi

  echo
  echo "====================================================="
  echo "Running cleanup stage: $stage_name"
  echo "Script: $script_path"
  echo "====================================================="

  # Ask for confirmation before running each stage
  read -p "Run this stage? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Skipping stage: $stage_name"
    return 0
  fi

  # Run the script and log output
  LOG_FILE="$LOGS_DIR/${stage_name}.log"
  echo "Running... (log: $LOG_FILE)"

  if "$script_path" 2>&1 | tee "$LOG_FILE"; then
    echo "Stage completed successfully: $stage_name"
    return 0
  else
    echo "ERROR: Stage failed: $stage_name"
    echo "Check log file for details: $LOG_FILE"
    return 1
  fi
}

# Function to run all cleanup stages
run_all_cleanup_stages() {
  # Create a summary file
  SUMMARY_FILE="$LOGS_DIR/summary.md"

  cat >"$SUMMARY_FILE" <<EOF
# Repository Cleanup Summary
Generated on $(date)

This report summarizes the results of the repository cleanup process.

## Cleanup Stages

EOF

  # Track overall success
  OVERALL_SUCCESS=true

  # Run each stage in order
  for i in "${!STAGE_NAMES[@]}"; do
    stage="${STAGE_NAMES[$i]}"
    script="${STAGE_SCRIPTS[$i]}"
    stage_name="${stage#*-}" # Remove the number prefix

    # Run the stage
    if run_cleanup_stage "$stage" "$script"; then
      echo "- ✅ **$stage_name**: Completed successfully" >>"$SUMMARY_FILE"
    else
      echo "- ❌ **$stage_name**: Failed" >>"$SUMMARY_FILE"
      OVERALL_SUCCESS=false
    fi
  done

  # Add summary footer
  cat >>"$SUMMARY_FILE" <<EOF

## Results

$(if [ "$OVERALL_SUCCESS" = true ]; then
    echo "✅ All cleanup stages completed successfully."
  else
    echo "❌ Some cleanup stages failed. Check individual log files for details."
  fi)

## Log Files

$(for log_file in "$LOGS_DIR"/*.log; do
    echo "- [$(basename "$log_file")]($(basename "$log_file"))"
  done)

## Next Steps

1. Verify that all changes are correct
2. Run tests to ensure functionality is maintained
3. Commit the changes to the repository
EOF

  echo
  echo "====================================================="
  echo "       Repository Cleanup Process Complete           "
  echo "====================================================="
  echo
  echo "Summary report: $SUMMARY_FILE"
  echo "Log files: $LOGS_DIR"

  if [ "$OVERALL_SUCCESS" = true ]; then
    echo "All cleanup stages completed successfully."
  else
    echo "WARNING: Some cleanup stages failed. Check the summary report and log files for details."
  fi
}

# Function to create a backup of the entire repository
create_repository_backup() {
  echo "Creating a backup of the entire repository..."

  BACKUP_FILE="repository_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

  # Exclude .git directory and other large/unnecessary files
  tar --exclude='.git' --exclude='node_modules' --exclude='__pycache__' -czf "$BACKUP_FILE" .

  echo "Repository backup created: $BACKUP_FILE"
  echo
}

# Main execution
echo "This script will run all repository cleanup stages in sequence."
echo "A backup of the repository will be created before any changes are made."
echo
read -p "Do you want to proceed? (y/n): " PROCEED

if [[ "$PROCEED" != "y" && "$PROCEED" != "Y" ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Create repository backup
create_repository_backup

# Run all cleanup stages
run_all_cleanup_stages

echo
echo "Cleanup process complete. Please review the changes and test the repository."
