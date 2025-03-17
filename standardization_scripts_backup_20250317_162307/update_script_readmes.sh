#!/bin/bash
# Version: 1.0.0
#
# Update README files for script directories
# This script creates README files for each script directory with descriptions of the contained scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
cd "${SCRIPT_DIR}"

# Define color codes for output
NC='\033[0m' # No Color

# Define directories and their descriptions
CORE_DESC="Core ephemery functionality scripts"
DEPLOYMENT_DESC="Scripts for deploying ephemery nodes"
MONITORING_DESC="Monitoring and alerting scripts"
MAINTENANCE_DESC="Scripts for maintenance tasks"
UTILITIES_DESC="Helper utilities and shared functions"
DEVELOPMENT_DESC="Scripts for development environment setup and testing"

# Process each directory
for dir in core deployment monitoring maintenance utilities development; do
  if [ -d "${dir}" ]; then
    readme_file="${dir}/README.md"

    # Get a list of scripts in the directory
    scripts=$(find "${dir}" -maxdepth 1 -type f -name "*.sh" | sort)

    echo -e "${YELLOW}Updating README for ${dir} directory...${NC}"

    # Get directory description
    dir_desc=""
    case "${dir}" in
      "core") dir_desc="${CORE_DESC}" ;;
      "deployment") dir_desc="${DEPLOYMENT_DESC}" ;;
      "monitoring") dir_desc="${MONITORING_DESC}" ;;
      "maintenance") dir_desc="${MAINTENANCE_DESC}" ;;
      "utilities") dir_desc="${UTILITIES_DESC}" ;;
      "development") dir_desc="${DEVELOPMENT_DESC}" ;;
    esac

    # Create or update the README file
    echo "# $(echo ${dir} | tr '[:lower:]' '[:upper:]' | head -c 1)$(echo ${dir} | cut -c 2-) Scripts" >"${readme_file}"
    echo "" >>"${readme_file}"
    echo "${dir_desc}" >>"${readme_file}"
    echo "" >>"${readme_file}"
    echo "## Scripts" >>"${readme_file}"
    echo "" >>"${readme_file}"

    # Add script descriptions
    for script in ${scripts}; do
      script_name=$(basename "${script}")
      description=$(grep -m 1 "^#" "${script}" | sed 's/^#//' | sed 's/^ *//')
      if [ -z "${description}" ]; then
        description="No description found"
      fi
      echo "- \`${script_name}\`: ${description}" >>"${readme_file}"
    done

    # Add usage section
    echo "" >>"${readme_file}"
    echo "## Usage" >>"${readme_file}"
    echo "" >>"${readme_file}"
    echo "Please refer to the individual script comments or the main project documentation for usage information." >>"${readme_file}"

    echo -e "${GREEN}Updated ${readme_file}${NC}"
  fi
done

# Update main README
readme_file="README.md"

cat >"${readme_file}" <<'EOF'
# Ephemery Scripts

This directory contains scripts for deploying, managing, and maintaining Ephemery nodes.

## Directory Structure

The scripts are organized into the following categories:

- **core/**: Core ephemery functionality scripts
- **deployment/**: Scripts for deploying ephemery nodes
- **monitoring/**: Monitoring and alerting scripts
- **maintenance/**: Scripts for maintenance tasks
- **utilities/**: Helper utilities and shared functions
- **development/**: Scripts for development environment setup and testing

## Common Library

A shared library of common functions is provided in `utilities/lib/common.sh`. All scripts should use this library to ensure consistency in logging, error handling, and user interaction.

## Script Development

When creating new scripts, please use the templates provided in `development/templates/` and follow the project's coding standards. All scripts should:

1. Include a clear purpose in the header comment
2. Use the common library for consistency
3. Include proper error handling
4. Follow the standard directory structure
5. Be well-documented

## Example Usage

Most scripts include a help option that can be accessed with `-h` or `--help`:

```bash
./deployment/deploy-ephemery.sh --help
```

For more detailed information about specific scripts, please refer to the README files in each directory.

## Script Inventory

For a complete list of all available scripts and their purposes, see the README files in each subdirectory.
EOF

echo -e "${GREEN}Updated main README at ${readme_file}${NC}"
echo -e "${GREEN}Script README update complete!${NC}"
