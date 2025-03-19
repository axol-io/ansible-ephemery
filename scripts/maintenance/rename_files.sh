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
# Convert hyphen-separated names to underscore_separated names
rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/aggregate_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/aggregate_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/process_results.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/process_results.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/publish-codecov.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/publish_codecov.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/publish-codecov.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/publish_codecov.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/report_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/report_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/run_tests.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/ansible/posix/.azure-pipelines/scripts/run_tests.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/aggregate_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/aggregate_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/process_results.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/process_results.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/report_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/report_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/run_tests.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/.azure-pipelines/scripts/run_tests.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/images/copy-images.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/images/copy_images.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/images/copy-images.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/images/copy_images.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/utils/shippable/linux-community.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/utils/shippable/linux_community.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/utils/shippable/linux-community.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/docker/tests/utils/shippable/linux_community.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/aggregate_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/aggregate-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/aggregate_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/process_results.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/process-results.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/process_results.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/report_coverage.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/report-coverage.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/report_coverage.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/run_tests.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/.azure-pipelines/scripts/run_tests.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/keycloak_authz_custom_policy/policy/build-policy.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/keycloak_authz_custom_policy/policy/build_policy.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/keycloak_authz_custom_policy/policy/build-policy.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/keycloak_authz_custom_policy/policy/build_policy.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/setup_flatpak_remote/create-repo.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/setup_flatpak_remote/create_repo.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/setup_flatpak_remote/create-repo.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/integration/targets/setup_flatpak_remote/create_repo.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/utils/shippable/linux-community.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/utils/shippable/linux_community.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/utils/shippable/linux-community.sh" "/Users/droo/Documents/CODE/ansible-ephemery/collections/ansible_collections/community/general/tests/utils/shippable/linux_community.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/molecule/convert-to-delegated.sh" "/Users/droo/Documents/CODE/ansible-ephemery/molecule/convert_to_delegated.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/molecule/convert-to-delegated.sh" "/Users/droo/Documents/CODE/ansible-ephemery/molecule/convert_to_delegated.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/molecule/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/molecule/run_tests.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/molecule/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/molecule/run_tests.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/install-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/install_collections.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/install-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/install_collections.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/manage-validator.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/manage_validator.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/manage-validator.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/manage_validator.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/run-ephemery-demo.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/run_ephemery_demo.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/run-ephemery-demo.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/core/run_ephemery_demo.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/deploy-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/deploy_ephemery.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/deploy-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/deploy_ephemery.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/install-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/install_collections.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/install-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/install_collections.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup-dev-env.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup_dev_env.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup-dev-env.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup_dev_env.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup_ephemery.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/deployment/setup_ephemery.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/dev-env-manager.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/dev_env_manager.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/dev-env-manager.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/dev_env_manager.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/repo-standards.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/repo_standards.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/repo-standards.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/repo_standards.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/test-collection-loading.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/test_collection_loading.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/test-collection-loading.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/development/test_collection_loading.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/local/run-ephemery-local.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/local/run_ephemery_local.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/local/run-ephemery-local.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/local/run_ephemery_local.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check-unencrypted-secrets.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check_unencrypted_secrets.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check-unencrypted-secrets.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check_unencrypted_secrets.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check_yaml_extensions.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/check_yaml_extensions.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-repository-linting.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_repository_linting.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-repository-linting.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_repository_linting.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_extensions.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_extensions.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-line-length.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_line_length.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-line-length.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_line_length.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-lint.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_lint.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-lint.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_lint.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-quotes.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_quotes.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix-yaml-quotes.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/fix_yaml_quotes.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot-ephemery-production.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot_ephemery_production.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot-ephemery-production.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot_ephemery_production.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot_ephemery.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot-ephemery.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/maintenance/troubleshoot_ephemery.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check-templating-issues.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check_templating_issues.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check-templating-issues.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check_templating_issues.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check_yaml_extensions.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check-yaml-extensions.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/check_yaml_extensions.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/start-validator-dashboard.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/start_validator_dashboard.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/start-validator-dashboard.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/monitoring/start_validator_dashboard.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/remote/run-ephemery-remote.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/remote/run_ephemery_remote.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/remote/run-ephemery-remote.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/remote/run_ephemery_remote.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/run_tests.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/run-tests.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/run_tests.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/manage-yaml-extension.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/manage_yaml_extension.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/manage-yaml-extension.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/manage_yaml_extension.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/run-fast-sync.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/run_fast_sync.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/run-fast-sync.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/run_fast_sync.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/verify-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/verify_collections.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/verify-collections.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/utilities/verify_collections.sh"

rename_file "/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/dashboard/validator-dashboard.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/dashboard/validator_dashboard.sh"
update_all_references "/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/dashboard/validator-dashboard.sh" "/Users/droo/Documents/CODE/ansible-ephemery/scripts/validator/dashboard/validator_dashboard.sh"


print_status "$GREEN" "File renaming completed."
print_status "$YELLOW" "Please review the changes and commit them if satisfied."
print_status "$YELLOW" "Note: Some references may not have been updated correctly. Manual verification is recommended."

exit 0
