#!/bin/bash
# Version: 1.0.0
# simplify_molecule_configs.sh - Analyze and suggest simplifications for molecule.yaml files

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MOLECULE_DIR="$(cd "${SCRIPT_DIR}/../../" && pwd)"
REPORT_FILE="${MOLECULE_DIR}/simplification_report.txt"

echo "Analyzing molecule.yaml files for possible simplification..."
echo "Report will be saved to: ${REPORT_FILE}"

# Start with a fresh report
echo "Molecule Configuration Simplification Report" >"${REPORT_FILE}"
echo "=======================================" >>"${REPORT_FILE}"
echo "Generated on: $(date)" >>"${REPORT_FILE}"
echo "" >>"${REPORT_FILE}"

# Find all molecule.yaml files
find "${MOLECULE_DIR}" -type f -name "molecule.yaml" | sort | while read -r file; do
  # Skip the shared templates and base
  if [[ "${file}" == *"/shared/"* ]]; then
    continue
  fi

  scenario_dir=$(dirname "${file}")
  scenario_name=$(basename "${scenario_dir}")

  echo "Analyzing: ${file}" >>"${REPORT_FILE}"
  echo "---------------------------------------------------------" >>"${REPORT_FILE}"

  # Count lines
  line_count=$(wc -l <"${file}")
  echo "Line count: ${line_count}" >>"${REPORT_FILE}"

  # Check for common sections that could be simplified
  echo "" >>"${REPORT_FILE}"
  echo "Possible simplifications:" >>"${REPORT_FILE}"

  # Check for standard docker configuration
  if grep -q "driver:" "${file}" && grep -q "name: docker" "${file}"; then
    echo "- Driver configuration can be inherited from base_molecule.yaml" >>"${REPORT_FILE}"
  fi

  # Check for standard platform configuration
  if grep -q "platforms:" "${file}" && grep -q "name: ethereum-node" "${file}" && grep -q "image: ubuntu:22.04" "${file}"; then
    echo "- Platform configuration can be inherited from base_molecule.yaml" >>"${REPORT_FILE}"
  fi

  # Check for host vars that could be moved to host_vars files
  if grep -q "host_vars:" "${file}"; then
    echo "- Consider moving host_vars to shared/host_vars/ethereum-node/${scenario_name}.yaml" >>"${REPORT_FILE}"
  fi

  # Check if playbooks could reference shared ones
  if ! grep -q "prepare: ../../shared/prepare.yaml" "${file}" && [ -f "${scenario_dir}/prepare.yaml" ]; then
    echo "- Consider using shared prepare.yaml: prepare: ../../shared/prepare.yaml" >>"${REPORT_FILE}"
  fi

  if ! grep -q "cleanup: ../../shared/cleanup.yaml" "${file}" && [ -f "${scenario_dir}/cleanup.yaml" ]; then
    echo "- Consider using shared cleanup.yaml: cleanup: ../../shared/cleanup.yaml" >>"${REPORT_FILE}"
  fi

  echo "" >>"${REPORT_FILE}"
  echo "" >>"${REPORT_FILE}"
done

echo "" >>"${REPORT_FILE}"
echo "Summary" >>"${REPORT_FILE}"
echo "=======" >>"${REPORT_FILE}"
echo "The configurations can be simplified by:" >>"${REPORT_FILE}"
echo "1. Moving common configuration to shared/base_molecule.yaml" >>"${REPORT_FILE}"
echo "2. Moving host variables to files in shared/host_vars/ethereum-node/" >>"${REPORT_FILE}"
echo "3. Using shared playbooks for prepare.yaml and cleanup.yaml" >>"${REPORT_FILE}"
echo "4. Creating a single, comprehensive verify.yaml for each scenario type" >>"${REPORT_FILE}"

echo "Analysis complete. Report saved to: ${REPORT_FILE}"
echo "Review the report and manually simplify molecule.yaml files as recommended."
