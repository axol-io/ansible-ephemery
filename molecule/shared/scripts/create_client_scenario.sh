#!/bin/bash
# Version: 1.0.0
#
# Script to create a new client scenario based on the template
#
# Usage: ./create_client_scenario.sh [el_client] [cl_client]
# Example: ./create_client_scenario.sh geth lighthouse

set -e

# Check if arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 [el_client] [cl_client]"
  echo "Example: $0 geth lighthouse"
  exit 1
fi

EL_CLIENT=$1
CL_CLIENT=$2
SCENARIO_NAME="${EL_CLIENT}-${CL_CLIENT}"
TEMPLATE_PATH="$(dirname "$0")/../templates/client_molecule.yaml.template"
TARGET_DIR="../../clients/${SCENARIO_NAME}"

# Create scenario directory if it doesn't exist
mkdir -p "${TARGET_DIR}"

# Create molecule.yaml from template
sed "s/EL_CLIENT/${EL_CLIENT}/g; s/CL_CLIENT/${CL_CLIENT}/g" "${TEMPLATE_PATH}" >"${TARGET_DIR}/molecule.yaml"

# Create minimal converge.yaml
cat >"${TARGET_DIR}/converge.yaml" <<EOF
---
- name: Converge
  hosts: all
  become: true
  tasks:
    - name: "Include ansible-ephemery role"
      include_role:
        name: '{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}'
EOF

echo "Created client scenario for ${EL_CLIENT}-${CL_CLIENT} in ${TARGET_DIR}"
echo "You can now run: molecule test -s clients/${SCENARIO_NAME}"
