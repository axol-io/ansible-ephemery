#!/bin/bash
# Version: 1.0.0
# Helper script to convert Docker-based molecule scenarios to use the delegated driver

set -e

# Check if jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: This script requires 'jq' to be installed."
  echo "Please install it with your package manager, e.g.:"
  echo "  brew install jq  # on macOS"
  echo "  apt install jq   # on Debian/Ubuntu"
  exit 1
fi

# Convert a single scenario
convert_scenario() {
  local scenario_dir="$1"
  local molecule_file="${scenario_dir}/molecule.yml"

  if [ ! -f "${molecule_file}" ]; then
    echo "Skipping ${scenario_dir}: molecule.yml not found"
    return 0
  fi

  echo "Converting scenario: ${scenario_dir}"

  # Create a backup
  cp "${molecule_file}" "${molecule_file}.docker.bak"

  # Create the delegated version
  cat >"${molecule_file}" <<'EOF'
---
dependency:
  name: galaxy
driver:
  name: delegated
  options:
    managed: false
    ansible_connection_options:
      ansible_connection: local
platforms:
  - name: instance
provisioner:
  name: ansible
  inventory:
    host_vars:
      instance:
        ansible_connection: local
        ansible_python_interpreter: "{{ ansible_playbook_python }}"
verifier:
  name: ansible
EOF

  echo "✅ Converted ${molecule_file} to use delegated driver (backup saved as ${molecule_file}.docker.bak)"
}

# Main function to convert all scenarios
convert_all() {
  echo "Converting Molecule scenarios to use the delegated driver..."

  # Get all scenario directories
  find "$(dirname "$0")" -type d -name "*" -not -path "*/__pycache__*" | while read -r scenario_dir; do
    if [ -f "${scenario_dir}/molecule.yml" ]; then
      convert_scenario "${scenario_dir}"
    fi
  done

  echo "Conversion complete. You can now run: MOLECULE_DRIVER=delegated ./run-tests.sh"
}

# Start conversion
convert_all
