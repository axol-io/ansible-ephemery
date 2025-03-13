#!/bin/bash
#
# Script to organize loose scripts according to the PRD directory structure
# This follows the roadmap item for scripts directory consolidation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define directories and their related scripts
declare -A script_categories
script_categories=(
    ["core"]="ephemery_retention.sh setup_ephemery_cron.sh reset_ephemery.sh"
    ["deployment"]="deploy-ephemery.sh deploy_ephemery_retention.sh setup_dashboard.sh validator.sh"
    ["monitoring"]="check_ephemery_status.sh check_sync_status.sh validator_performance_monitor.sh run_validator_monitoring.sh key_performance_metrics.sh deploy_key_performance_metrics.sh"
    ["maintenance"]="fix_checkpoint_sync.sh test_checkpoint_sync.sh troubleshoot-ephemery.sh run-fast-sync.sh benchmark_sync.sh"
    ["development"]="verify-collections.sh test-collection-loading.sh dev-env-manager.sh setup-dev-env.sh create_client_tasks.sh create_all_client_configs.sh"
    ["utilities"]="restore_validator_keys.sh restore_validator_keys_wrapper.sh checkpoint_sync_alert.sh quick_health_vibe_check.sh"
)

# Scripts to be processed
scripts_to_move=(
    "ephemery_retention.sh"
    "setup_ephemery_cron.sh"
    "deploy_ephemery_retention.sh"
    "check_ephemery_status.sh"
    "check_sync_status.sh"
    "validator_performance_monitor.sh"
    "run_validator_monitoring.sh"
    "fix_checkpoint_sync.sh"
    "test_checkpoint_sync.sh"
    "troubleshoot-ephemery.sh"
    "run-fast-sync.sh"
    "benchmark_sync.sh"
    "key_performance_metrics.sh"
    "deploy_key_performance_metrics.sh"
    "setup_dashboard.sh"
    "restore_validator_keys.sh"
    "restore_validator_keys_wrapper.sh"
    "checkpoint_sync_alert.sh"
    "reset_ephemery.sh"
    "quick_health_vibe_check.sh"
    "validator.sh"
    "verify-collections.sh"
    "test-collection-loading.sh"
    "dev-env-manager.sh"
    "setup-dev-env.sh"
    "create_client_tasks.sh"
    "create_all_client_configs.sh"
)

# Function to find the target directory for a script
find_target_directory() {
    local script="$1"
    for dir in "${!script_categories[@]}"; do
        if [[ " ${script_categories[$dir]} " == *" $script "* ]]; then
            echo "$dir"
            return 0
        fi
    done
    echo "utilities" # Default category
    return 0
}

echo -e "${GREEN}Starting script organization according to PRD...${NC}"
echo -e "${YELLOW}This script will organize loose scripts into the appropriate directories.${NC}"
echo -e "${YELLOW}A backup of each script will be created before moving.${NC}"

# Create a backup directory
backup_dir="${SCRIPT_DIR}/script_backups_$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
echo -e "${GREEN}Created backup directory: $backup_dir${NC}"

# Process each script
for script in "${scripts_to_move[@]}"; do
    if [ -f "$script" ]; then
        target_dir=$(find_target_directory "$script")

        # Create backup
        cp "$script" "$backup_dir/"

        # Ensure target directory exists
        mkdir -p "$target_dir"

        # Check if the script already exists in the target directory
        if [ -f "$target_dir/$script" ]; then
            # Compare the files
            if diff -q "$script" "$target_dir/$script" >/dev/null; then
                echo -e "${YELLOW}Script $script already exists in $target_dir and is identical. Removing the original.${NC}"
                rm "$script"
            else
                echo -e "${RED}Script $script already exists in $target_dir but has different content. Keeping both versions.${NC}"
                mv "$script" "$target_dir/$(basename "$script" .sh)_new.sh"
            fi
        else
            # Move the script
            echo -e "${GREEN}Moving $script to $target_dir/${NC}"
            mv "$script" "$target_dir/"
        fi
    else
        echo -e "${YELLOW}Script $script not found. Skipping.${NC}"
    fi
done

echo -e "${GREEN}Script organization complete!${NC}"
echo -e "${GREEN}Backup of all processed scripts can be found in: $backup_dir${NC}"
echo -e "${YELLOW}Please review the changes and update any references to the moved scripts.${NC}"

# Create a README file for each directory if it doesn't exist
for dir in "${!script_categories[@]}"; do
    readme_file="$dir/README.md"
    if [ ! -f "$readme_file" ]; then
        echo -e "${GREEN}Creating README for $dir directory...${NC}"
        cat > "$readme_file" << EOF
# ${dir^} Scripts

This directory contains scripts related to ${dir} operations for the Ephemery Node project.

## Scripts

$(for script in ${script_categories[$dir]}; do
    if [ -f "$dir/$script" ]; then
        echo "- \`$script\`: $(head -n 3 "$dir/$script" | grep -o "#.*" | head -n 1 | sed 's/# *//')"
    fi
done)

## Usage

Please refer to the individual script comments or the main documentation for usage information.
EOF
    fi
done

echo -e "${GREEN}Script organization complete. Please test the functionality to ensure everything works correctly.${NC}"
