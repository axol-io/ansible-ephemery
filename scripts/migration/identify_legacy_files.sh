#!/bin/bash
# Identify Legacy Files Script for Ephemery Consolidation
# This script helps identify files that can be removed after the consolidation process.

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_FILE="${ROOT_DIR}/legacy_files_report.md"

echo -e "${BLUE}Starting legacy file identification process...${NC}"
echo -e "${BLUE}Results will be saved to ${REPORT_FILE}${NC}"

# Initialize report file
cat >"${REPORT_FILE}" <<EOF
# Legacy Files Report

This report identifies files that may be redundant after the consolidation process.

## Legacy Client Configurations

The following client configurations may be replaced by the new role-based structure:

EOF

# Identify legacy client configurations
echo -e "${YELLOW}Identifying legacy client configurations...${NC}"

find "${ROOT_DIR}" -path "${ROOT_DIR}/config/*" -type f -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" | grep -v "ansible/roles" | while read -r config_file; do
  relative_path="${config_file#$ROOT_DIR/}"
  echo "- \`${relative_path}\` - Potential legacy configuration" >>"${REPORT_FILE}"
done

# Add section for legacy playbooks
cat >>"${REPORT_FILE}" <<EOF

## Legacy Playbooks

The following playbooks may be redundant after consolidation:

EOF

# Identify legacy playbooks (outside of the playbooks directory)
echo -e "${YELLOW}Identifying legacy playbooks...${NC}"

find "${ROOT_DIR}" -name "*.yaml" -o -name "*.yml" | grep -v "ansible/roles" | grep -v "${ROOT_DIR}/playbooks/" | grep -i "play\|task" | while read -r playbook_file; do
  relative_path="${playbook_file#$ROOT_DIR/}"
  echo "- \`${relative_path}\` - Potential legacy playbook" >>"${REPORT_FILE}"
done

# Add section for obsolete scripts
cat >>"${REPORT_FILE}" <<EOF

## Obsolete Scripts

The following scripts may be redundant or need to be updated:

EOF

# Identify potentially obsolete scripts
echo -e "${YELLOW}Identifying potentially obsolete scripts...${NC}"

find "${ROOT_DIR}/scripts" -name "*.sh" -o -name "*.py" | grep -v "identify_legacy_files.sh" | while read -r script_file; do
  relative_path="${script_file#$ROOT_DIR/}"
  echo "- \`${relative_path}\` - Review whether still needed" >>"${REPORT_FILE}"
done

# Add section for other files
cat >>"${REPORT_FILE}" <<EOF

## Other Potential Files for Removal

The following files may be redundant:

EOF

# Identify other files that could be redundant
echo -e "${YELLOW}Identifying other potentially redundant files...${NC}"

find "${ROOT_DIR}" -name "*.bak" -o -name "*.old" -o -name "*_legacy*" | while read -r other_file; do
  relative_path="${other_file#$ROOT_DIR/}"
  echo "- \`${relative_path}\` - Potential for removal" >>"${REPORT_FILE}"
done

# Add recommendations section
cat >>"${REPORT_FILE}" <<EOF

## Recommendations

1. Review each file listed in this report carefully before removal
2. Ensure that the functionality is properly implemented in the new role-based structure
3. Create backups before removing files
4. Test the system thoroughly after removing files
5. Update documentation to reflect changes

## Generated on: $(date)

EOF

echo -e "${GREEN}Legacy file identification completed!${NC}"
echo -e "${GREEN}Report saved to: ${REPORT_FILE}${NC}"
echo -e "${YELLOW}Please review the report carefully before removing any files.${NC}"

# Mark as executable
chmod +x "${BASH_SOURCE[0]}"
